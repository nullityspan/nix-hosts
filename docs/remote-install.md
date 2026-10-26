# Remote install of a NixOS host

Build a flake host on an installer machine and push it over SSH. The target
needs no internet and no admin key (Nitrokey): sops uses the installer's host
key, and SSH uses a one-off password or key.

Files per host:

- `nixos/hosts/<host>/private.sops.yaml`: identifying values (`hostname`,
  `host_id`, `disk`, addresses), fed in as `host.json` of the `private` input
- `nixos/hosts/<host>/hardware.json.sops`: nixos-facter report
- `nixos/hosts/<host>/secrets.sops.yaml`: sops-nix runtime secrets
- `keys.nix`: age keys; `sops.nix`: recipients, rendered to `.sops.yaml` by
  `scripts/sops-config`

The installer must be listed for `<host>` in `installers` in `sops.nix`.
Placeholders: `<host>` config name, `<target>` IP, `<jump>` jump host.

Run every command on the installer, in the repo, in a real terminal. Several
commands use `sudo` inside `$(…)`, and that fails without a TTY.

## 1. Working dir (tmpfs)

```
W=$(mktemp -d "$XDG_RUNTIME_DIR/<host>.XXXX"); mkdir $W/extra $W/private
```

`$XDG_RUNTIME_DIR` is wiped on logout, plaintext included. Each new shell
needs `W` set again.

## 2. Reach the target as root

Pick one:

- **Installer ISO** (`nix build .#installer-iso`). On the console, run
  `sudo passwd root` with a fresh password.
- **Running Linux** (nixos-anywhere kexecs into an installer). Put a one-off
  key on root:
  ```
  ssh-keygen -q -t ed25519 -N "" -f $W/install_key
  ```
  Then append `install_key.pub` to `/root/.ssh/authorized_keys` on the target.
  Kexec must be allowed: `sysctl kernel.kexec_load_disabled` must be `0`.
  See [Kexec blocked](#kexec-blocked) if it is `1`.

SSH alias in `~/.ssh/config`:

```
Host <host>-install
	ProxyJump <jump>
	HostName <target>
	User root
	IdentityFile <W>/install_key        # kexec route; ISO route: PreferredAuthentications password
	StrictHostKeyChecking no            # host key changes on kexec/install
	UserKnownHostsFile /dev/null
	ControlMaster auto
	ControlPath ${XDG_RUNTIME_DIR}/ssh-%r@%h:%p
	ControlPersist 60m
```

Use an IP for `HostName`. The jump host may not resolve the name.

## 3. Hardware report and disk

```
F=$(nix build --no-link --print-out-paths nixpkgs#nixos-facter)
nix copy --to ssh://<host>-install $F        # add --no-check-sigs if refused
ssh <host>-install "$F/bin/nixos-facter -o /tmp/hardware.json"
scp <host>-install:/tmp/hardware.json $W/private/ && ssh <host>-install rm /tmp/hardware.json
ssh <host>-install 'lsblk -d -o NAME,SIZE,MODEL; ls -l /dev/disk/by-id | grep -v part; ls -l /dev/disk/by-partlabel'
```

Use the by-id path (`/dev/disk/by-id/nvme-<model>_<serial>`), never
`/dev/nvme0n1`. If the path is missing, disko fails instead of wiping
another disk. On a reinstall, the partlabels show which disk holds the old
root.

## 4. Host key, recipients, re-key

```
install -d -m 755 $W/extra/persist/etc/ssh
ssh-keygen -q -t ed25519 -N "" -C root@<host> -f $W/extra/persist/etc/ssh/ssh_host_ed25519_key
nix shell nixpkgs#ssh-to-age -c ssh-to-age < $W/extra/persist/etc/ssh/ssh_host_ed25519_key.pub
```

Put the `age1…` key in `keys.nix` (`machines.<host>.age`). A new host also
needs entries in `sops.nix` (`age`, `installers`). Then:

```
scripts/sops-config
sops encrypt --input-type binary --output-type binary \
  --filename-override nixos/hosts/<host>/hardware.json.sops $W/private/hardware.json \
  > nixos/hosts/<host>/hardware.json.sops
export SOPS_AGE_KEY="$(sudo nix run nixpkgs#ssh-to-age -- -private-key -i /etc/ssh/ssh_host_ed25519_key)"
for f in nixos/hosts/<host>/{secrets,private}.sops.yaml; do sops updatekeys -y $f; done
sops set nixos/hosts/<host>/private.sops.yaml '["disk"]' '"/dev/disk/by-id/…"'
unset SOPS_AGE_KEY
git add keys.nix sops.nix .sops.yaml nixos/hosts/<host>/
```

The re-key re-encrypts each file for the new host key. Check it: each file
should contain the new `age1…` recipient and none of the old one.

New host: create the files with `sops nixos/hosts/<host>/…` (same
`SOPS_AGE_KEY`). `private.sops.yaml` needs `hostname`, `host_id` (first 8 hex
of `echo -n <hostname> | md5sum`), `disk`, plus whatever the host's
networking reads. Every key referenced from `secrets.sops.yaml` must exist:

```
grep -rn -A3 'sops.secrets' nixos/hosts/<host> nixos/modules
grep -oE '^[a-zA-Z0-9_-]+:' nixos/hosts/<host>/secrets.sops.yaml
```

Back up keys whose loss breaks data continuity offline, for example
pseudonymisation keys.

## 5. Build

```
source scripts/lib/private.sh
private_prepare <host>
for a in toplevel diskoScript; do
  nix build .#nixosConfigurations.<host>.config.system.build.$a "${PRIVATE_ARGS[@]}" -o $W/result-$a
done
ls -l $W/result-toplevel                          # real hostname in the name
grep -ho 'by-id/[^" ;]*' $W/result-diskoScript/* | sort -u   # only the install disk
```

## 6. Install (wipes the disk)

```
ssh <host>-install "hostname; ls -l /dev/disk/by-id | grep <serial>"
nix run github:nix-community/nixos-anywhere -- \
  --store-paths $W/result-diskoScript $W/result-toplevel \
  --extra-files $W/extra <host>-install
```

Kexec route: the target downloads the kexec image itself. If it has no
internet, download the image on the installer and add `--kexec <tarball>`.

If it aborts after disko, run `ssh <host>-install findmnt -R /mnt`. If `/mnt`
is still mounted, resume with `--phases install,reboot` and the same
arguments.

## 7. After first boot

The old control socket now points at a dead system. Close it first:

```
ssh -O exit <host>-install
```

Then check:

```
ssh <jump> ssh-keyscan -t ed25519 <target> | cut -d' ' -f3   # must match …
cut -d' ' -f2 $W/extra/persist/etc/ssh/ssh_host_ed25519_key.pub
ssh -t <user>@<target> 'hostname; sudo ls /run/secrets'      # sudo works = sops decrypted
rm -rf "$W"
```

Then turn the install alias into a normal entry, with the verified key in
`known_hosts`. Later updates: run `scripts/rebuild <host>` on the host, or
`scripts/remote-update <host>` from an installer.

## Kexec blocked

`nixos/modules/core/hardening.nix` sets `kernel.kexec_load_disabled = 1`. A
running system can't clear it. On impermanence hosts, a `sysctl.d` override
is wiped on reboot. Instead, boot once without `systemd-sysctl` (as root on
the target):

```
e=$(grep -l "$(readlink -f /run/booted-system)" /boot/loader/entries/*.conf | head -1)
sed -e 's/^title .*/title kexec-once/' -e 's/^options .*/& systemd.mask=systemd-sysctl.service/' \
  "$e" > /boot/loader/entries/kexec-once.conf
bootctl set-oneshot kexec-once.conf && systemctl reboot
```

The root dataset rolls back on that boot. Re-add `install_key.pub` to root
afterwards. If the one-shot boot fails, the next reboot falls back to the
normal entry.

## Deploy from another installer

Any machine in `installers.<host>` can deploy. Give it a deploy key and add
the `.pub` to the user's authorized keys in the `<host>` config:

```
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_<host> -C <user>@<installer>-deploy
git pull
NIX_SSHOPTS="-i ~/.ssh/id_ed25519_<host>" scripts/remote-update <host> <user>@<target>
```

`<user>` must be in `trusted-users` (`@wheel`). The first deploy still needs
`ssh -A <installer>`, or a reinstall.

## Re-key / reinstall without wiping

Use this when the host can't activate (for example, a wrong sops recipient
means no sudo password), or when its host key leaked. Boot the ISO (step 2)
and keep `/persist`:

```
M=$(nix build --no-link --print-out-paths .#nixosConfigurations.<host>.config.system.build.mountScript)
nix copy --to ssh://<host>-install $M
ssh <host>-install "[ \"\$(hostname)\" = nixos ] || exit 1; $M"
ssh <host>-install '[ "$(hostname)" = nixos ] && findmnt /mnt/persist || exit 1
  rm -f /mnt/persist/etc/ssh/ssh_host_ed25519_key*
  ssh-keygen -t ed25519 -N "" -C root@<host> -f /mnt/persist/etc/ssh/ssh_host_ed25519_key
  cat /mnt/persist/etc/ssh/ssh_host_ed25519_key.pub' \
  | nix shell nixpkgs#ssh-to-age -c ssh-to-age
```

Update `keys.nix` and run `scripts/sops-config`. Then re-key **and rotate**
the data key; `updatekeys` alone keeps the old data key, which the leaked
key can still read:

```
export SOPS_AGE_KEY="$(sudo nix run nixpkgs#ssh-to-age -- -private-key -i /etc/ssh/ssh_host_ed25519_key)"
for f in nixos/hosts/<host>/{secrets.sops.yaml,private.sops.yaml,hardware.json.sops}; do
  sops updatekeys -y $f && sops rotate -i $f
done
unset SOPS_AGE_KEY
```

Build `toplevel` (step 5), then:

```
T=$(readlink -f $W/result-toplevel)
nix copy --to "ssh://<host>-install?remote-store=local?root=/mnt" $T
ssh <host>-install "[ \"\$(hostname)\" = nixos ] || exit 1
  nixos-install --root /mnt --system $T --no-root-passwd --no-channel-copy && reboot"
```

## Test in a VM

Set `disk` to `/dev/disk/by-id/nvme-QEMU_NVMe_Ctrl_<serial>` and point the
alias at `127.0.0.1` port 2230:

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

Afterwards, redo steps 3–4 for the real target.

## Gotchas

- Untracked files are invisible to the flake: `git add` new host files.
- Decrypt and build on an installer; never carry plaintext to the jump host.
- fail2ban (aggressive mode) bans after 5 failed key attempts, and the target
  then refuses connections. Put installer and jump IPs in `fail2ban_ignore`
  in `private.sops.yaml`; satellite reads it. Have the Nitrokey ready before
  the first login, because the new system accepts only `sk-` keys.
- qemu fails with `GLIBC_2.43' not found`: run it with
  `env -u LD_LIBRARY_PATH`.
