# Remote install of a NixOS host

Install a flake host onto a machine booted from the installer ISO. Everything
is built on an installer machine and pushed over SSH; the target needs no
internet. No admin key (Nitrokey) is needed: SSH uses a one-off root password,
sops uses the installer's host key.

Layout:

- `nixos/hosts/<host>/` — host config, listed in `flake.nix`
- `nixos/hosts/<host>/private.sops.yaml` — identifying values (`hostname`,
  `host_id`, `disk`, addresses), fed in as `host.json` of the `private` flake
  input (stubbed by `nixos/private/stub/`)
- `nixos/hosts/<host>/hardware.json.sops` — nixos-facter report, fed in as
  `hardware.json` of the `private` input
- `nixos/hosts/<host>/secrets.sops.yaml` — sops-nix runtime secrets
- `keys.nix` — age keys by name; `sops.nix` — recipients, rendered to
  `.sops.yaml` by `scripts/sops-config`
- sops-nix on the target decrypts with `/persist/etc/ssh/ssh_host_ed25519_key`

Placeholders: `<repo>` flake checkout, `<host>` config name, `<target>` target
IP, `<jump>` jump host (omit if directly reachable).

## Prerequisites

- Installer machine: `<repo>`, Nix cache access, and listed for `<host>` in
  `installers` in `sops.nix`. Its host key then decrypts and re-keys all of
  `<host>`'s files (`scripts/lib/private.sh` does this via `sudo`).
- Target booted from the installer ISO.
- The disk named by `disk` in `private.sops.yaml` is **wiped**. Check it on
  the target first (step 4).

## 1. Boot the installer

```
nix build .#installer-iso
```

ISO with sshd on, ZFS, no substituters, and no password baked in. On the
target console (auto-login as `nixos`):

```
sudo passwd root
```

Use a fresh password per install; anyone on the network can try it while the
installer runs.

## 2. SSH alias

`~/.ssh/config`, password only, one shared connection (nixos-anywhere opens
many; the password is typed once):

```
Host <host>-install
	ProxyJump <jump>
	HostName <target>
	User root
	PubkeyAuthentication no
	PreferredAuthentications password
	StrictHostKeyChecking no        # installer host key changes every boot
	UserKnownHostsFile /dev/null
	ControlMaster auto
	ControlPath ${XDG_RUNTIME_DIR}/ssh-%r@%h:%p
	ControlPersist 60m
```

Open the connection and check the target:

```
ssh <host>-install 'hostname; lsblk -d -o NAME,SIZE,MODEL'   # hostname must be nixos
```

## 3. Working dirs (tmpfs)

```
cd <repo>
W=$(mktemp -d "$XDG_RUNTIME_DIR/<host>.XXXX")
EXTRA=$W/extra    # files placed on the target
P=$W/private      # plaintext hardware report
mkdir $EXTRA $P
```

Stay in this shell; `$XDG_RUNTIME_DIR` is wiped on logout. Don't use plain
`mktemp -d` (lands in `/tmp` on disk).

## 4. Hardware report and disk

Build facter here, copy it over, run it there:

```
F=$(nix build --no-link --print-out-paths nixpkgs#nixos-facter)
nix copy --to ssh://<host>-install $F            # add --no-check-sigs if refused
ssh <host>-install "$F/bin/nixos-facter -o /tmp/hardware.json"
scp <host>-install:/tmp/hardware.json $P/
ssh <host>-install ls -l /dev/disk/by-id | grep -v part
```

Pick the install disk by its model/serial name
(`/dev/disk/by-id/nvme-<model>_<serial>`), never `/dev/nvme0n1`: enumeration
order changes, and a missing by-id path makes disko fail instead of wiping
another disk. On a reinstall, confirm the old root disk with
`ls -l /dev/disk/by-partlabel` first.

## 5. Host key and recipients

sops-nix needs the host key at first boot, and it must already be a
recipient. Generate it into `$EXTRA`, which nixos-anywhere copies to the
target:

```
install -d $EXTRA/persist/etc/ssh
ssh-keygen -q -t ed25519 -N "" -C root@<host> -f $EXTRA/persist/etc/ssh/ssh_host_ed25519_key
nix shell nixpkgs#ssh-to-age -c ssh-to-age < $EXTRA/persist/etc/ssh/ssh_host_ed25519_key.pub
```

Put the printed `age1…` key in `keys.nix` (`machines.<host>.age`). A new host
also needs `<host>` in the `age` set and in `installers` in `sops.nix`:

```
installers = {
  <host> = [ "workstation" ];   # machines that install and deploy <host>
};
```

Each host gets one rule: admins, the host, and its installers. Regenerate
(never edit `.sops.yaml` by hand):

```
scripts/sops-config
```

## 6. Encrypt and re-key

Encrypt the report (public keys only):

```
sops encrypt --input-type binary --output-type binary \
  --filename-override nixos/hosts/<host>/hardware.json.sops $P/hardware.json \
  > nixos/hosts/<host>/hardware.json.sops
```

Existing files of a reinstalled host are still encrypted to the old host key.
Re-key them with the installer's host key (the private key lives only in that
command's environment):

```
for f in nixos/hosts/<host>/{secrets,private}.sops.yaml; do
  SOPS_AGE_KEY="$(sudo nix run nixpkgs#ssh-to-age -- -private-key -i /etc/ssh/ssh_host_ed25519_key)" \
    sops updatekeys -y $f
done
```

New host: create the files instead (`sops nixos/hosts/<host>/…` with the
same `SOPS_AGE_KEY` prefix, or an admin key).

`private.sops.yaml` needs `hostname`, `host_id` (first 8 hex chars of
`echo -n <hostname> | md5sum`), `disk`, plus whatever the host's networking
reads. Change one value:

```
sops set nixos/hosts/<host>/private.sops.yaml '["disk"]' '"/dev/disk/by-id/…"'
```

Every key referenced from `secrets.sops.yaml` must exist, or the build fails
with `the key '…' cannot be found`. Key names are plaintext, so compare
without decrypting:

```
grep -rn -A3 'sops.secrets' nixos/hosts/<host> nixos/modules
grep -oE '^[a-zA-Z0-9_-]+:' nixos/hosts/<host>/secrets.sops.yaml
```

Generators: `mkpasswd -m yescrypt` (login passwords),
`nix shell nixpkgs#apacheHttpd -c htpasswd -nB <name>` (nginx basic auth),
`openssl rand -hex 32` (random keys). Back up any key whose loss breaks data
continuity (e.g. pseudonymisation keys) offline.

Track everything (untracked files are invisible to the flake):

```
git add keys.nix sops.nix .sops.yaml nixos/hosts/<host>/
```

## 7. Build

`private_prepare` decrypts `private.sops.yaml` and `hardware.json.sops` with
this machine's host key into a tmpfs dir and sets `PRIVATE_ARGS`:

```
source scripts/lib/private.sh
private_prepare <host>
for a in toplevel diskoScript; do
  nix build .#nixosConfigurations.<host>.config.system.build.$a \
    "${PRIVATE_ARGS[@]}" -o $W/result-$a
done
```

The toplevel name shows the real hostname from `private.sops.yaml`.

## 8. Install (wipes the disk)

Check you are on the installer, then install:

```
ssh <host>-install "hostname; ls -l /dev/disk/by-id | grep <serial>"
nix run github:nix-community/nixos-anywhere -- \
  --store-paths $W/result-diskoScript $W/result-toplevel \
  --extra-files $EXTRA <host>-install
```

If it aborts after disko, check `ssh <host>-install findmnt -R /mnt`. Still
mounted → resume without re-partitioning:

```
nix run github:nix-community/nixos-anywhere -- --phases install,reboot \
  --store-paths $W/result-diskoScript $W/result-toplevel \
  --extra-files $EXTRA <host>-install
```

## 9. After first boot

The target must serve the generated host key (proves `/persist` landed):

```
ssh-keyscan -t ed25519 <target> 2>/dev/null | cut -d' ' -f3
cut -d' ' -f2 $EXTRA/persist/etc/ssh/ssh_host_ed25519_key.pub
```

Log in as the primary user and check secrets (a working `sudo` password means
sops-nix decrypted):

```
ssh <user>@<target> 'sudo ls /run/secrets'
```

Clean up:

```
ssh -O exit <host>-install
rm -rf "$W"
```

- Delete stray host-key copies (e.g. on the jump host).
- Replace the `<host>-install` SSH entry with a normal one.
- Later updates: `scripts/rebuild <host>` on the host, or
  `scripts/remote-update <host>` from an installer.

## Deploy from another installer

Any machine in `installers.<host>` can pull, build and deploy without the
workstation. Deploy key, so no FIDO agent is needed there:

```
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_<host> -C <user>@<installer>-deploy
```

Add the `.pub` to the user's authorized keys in the `<host>` config. The
first deploy still needs the forwarded agent (`ssh -A <installer>`) or the
reinstall below.

```
git pull
NIX_SSHOPTS="-i ~/.ssh/id_ed25519_<host>" scripts/remote-update <host> <user>@<target>
```

`remote-update` builds locally and activates with `--sudo --ask-sudo-password`.
`<user>` must be in `trusted-users` (`@wheel`) or the copy is refused.

## Re-key / reinstall without wiping

Use this when the host can't activate (e.g. wrong sops recipient, so there's
no sudo password) or its host key leaked. Boot the installer on the target
and set up steps 1–2. The disks and `/persist` survive.

Mount the installed system (the stub `private` input is enough here):

```
M=$(nix build --no-link --print-out-paths .#nixosConfigurations.<host>.config.system.build.mountScript)
nix copy --to ssh://<host>-install $M
ssh <host>-install "[ \"\$(hostname)\" = nixos ] || exit 1; $M"
```

New host key, generated in place so the private half never leaves the target:

```
ssh <host>-install '[ "$(hostname)" = nixos ] && findmnt /mnt/persist || exit 1
  rm -f /mnt/persist/etc/ssh/ssh_host_ed25519_key*
  ssh-keygen -t ed25519 -N "" -C root@<host> -f /mnt/persist/etc/ssh/ssh_host_ed25519_key
  cat /mnt/persist/etc/ssh/ssh_host_ed25519_key.pub' \
  | nix shell nixpkgs#ssh-to-age -c ssh-to-age
```

Replace `machines.<host>.age` in `keys.nix`, run `scripts/sops-config`, then
re-key **and rotate** the data key (`updatekeys` alone keeps the old data key,
which the leaked key can still decrypt from any old ciphertext):

```
export SOPS_AGE_KEY="$(sudo nix run nixpkgs#ssh-to-age -- -private-key -i /etc/ssh/ssh_host_ed25519_key)"
for f in nixos/hosts/<host>/{secrets.sops.yaml,private.sops.yaml,hardware.json.sops}; do
  sops updatekeys -y $f && sops rotate -i $f
done
unset SOPS_AGE_KEY
```

Build (step 7, `toplevel` only), then install into `/mnt`:

```
T=$(readlink -f $W/result-toplevel)
nix copy --to "ssh://<host>-install?remote-store=local?root=/mnt" $T
ssh <host>-install "[ \"\$(hostname)\" = nixos ] || exit 1
  nixos-install --root /mnt --system $T --no-root-passwd --no-channel-copy && reboot"
```

Then check `sudo ls /run/secrets` on the host.

## Test in a VM

Run the whole flow against a QEMU VM first. Set the host's `disk` to the VM
disk (`/dev/disk/by-id/nvme-QEMU_NVMe_Ctrl_<serial>`) and point
`<host>-install` at `127.0.0.1`, port 2230:

```
qemu-img create -f qcow2 disk.qcow2 128G
OVMF=$(nix build --no-link --print-out-paths nixpkgs#OVMF.fd)/FV
cp $OVMF/OVMF_VARS.fd . && chmod 644 OVMF_VARS.fd
qemu-system-x86_64 -enable-kvm -machine q35 -cpu host -smp 4 -m 8G \
  -drive if=pflash,format=raw,readonly=on,file=$OVMF/OVMF_CODE.fd \
  -drive if=pflash,format=raw,file=OVMF_VARS.fd \
  -drive file=disk.qcow2,if=none,id=nvm,format=qcow2 \
  -device nvme,serial=<serial>,drive=nvm \
  -nic user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:2230-:22 \
  -cdrom result/iso/*.iso -boot once=d
```

`-device nvme` gives the same `/dev/nvme*` and by-id layout as real NVMe
hosts. Afterwards, re-run steps 4–6 against the real target: new `disk`, new
host key, re-key.

## Gotchas

- Untracked files are invisible to the flake: `git add` new host files.
- Decrypt and build on an installer; don't carry plaintext to the jump host.
- Target behind a proxy/no internet: never `nix run` there; `nix copy` instead.
- qemu fails with `GLIBC_2.43' not found`: a session `LD_LIBRARY_PATH` leaks
  newer libraries; run it with `env -u LD_LIBRARY_PATH`.
