# Remote install of a NixOS host

Install a flake host onto a machine booted from an installer ISO. Everything is
built on the workstation and pushed over SSH; the target needs no internet.

Works for any flake that follows this layout:

- `nixos/hosts/<host>/` — host config, listed in `flake.nix`
- `nixos/hosts/<host>/private.nix.sops` — sops-encrypted module, fed in as the
  `private` flake input (stubbed by `private-stub/`)
- `nixos/hosts/<host>/secrets.sops.yaml` — sops-nix secrets
- sops-nix decrypts with `/persist/etc/ssh/ssh_host_ed25519_key`
- disko + nixos-facter (`${inputs.private}/hardware.json`)

Placeholders: `<repo>` flake checkout, `<host>` config name, `<target>` target
IP, `<jump>` jump host (omit if directly reachable), `<user>` primary user.

## Prerequisites

- Workstation: `<repo>`, sops decryption key (e.g. Nitrokey), Nix cache access.
- Target booted from an installer ISO with sshd running.
- `host.partition.device` (or disko's disk) is **wiped**. Check with `lsblk`
  and `sudo blkid` on the target first.

## 1. Boot the installer

Preferred: the offline ISO from nix-zen (sshd on, root login with your keys,
fallback password `nixos`, no substituters, ZFS):

```
nix build ~/Dev/nix-zen#installer-iso
```

Stock NixOS ISO also works: log in on the console and set a password for
`nixos` with `passwd` (it has none, so SSH refuses it).

## 2. SSH alias

`~/.ssh/config`:

```
Host <host>-install
	ProxyJump <jump>
	HostName <target>
	User root            # `nixos` on the stock ISO
```

With a FIDO key, multiplex so the key signs once instead of per hop
(nixos-anywhere opens many connections; a missed touch aborts mid-install):

```
Host <jump> <host>-install
	ControlMaster auto
	ControlPath ~/.ssh/cm-%r@%h:%p
	ControlPersist 30m
```

Test (and open the master): `ssh <host>-install lsblk`.

## 3. Working dirs (tmpfs)

```
cd <repo>
EXTRA=$(mktemp -d "$XDG_RUNTIME_DIR/<host>.XXXX")   # files placed on the target
P=$(mktemp -d "$XDG_RUNTIME_DIR/private.XXXX")      # decrypted `private` input
```

Stay in this shell; `$XDG_RUNTIME_DIR` is wiped on logout. Don't use plain
`mktemp -d` (lands in `/tmp` on disk).

## 4. Hardware report

Build facter here, copy it over, run it there:

```
F=$(nix build --no-link --print-out-paths nixpkgs#nixos-facter)
nix copy --to ssh://<host>-install $F            # add --no-check-sigs if refused
ssh <host>-install "sudo $F/bin/nixos-facter -o /tmp/hardware.json"
scp <host>-install:/tmp/hardware.json $P/
```

Keep a copy for later rebuilds on the host:
`/persist/etc/nix-local/<host>/hardware.json`.

## 5. Host SSH key (pre-generated)

sops-nix needs the host key at first boot, and it must already be a recipient.

```
install -d $EXTRA/persist/etc/ssh
ssh-keygen -t ed25519 -N "" -C root@<host> -f $EXTRA/persist/etc/ssh/ssh_host_ed25519_key
nix shell nixpkgs#ssh-to-age -c ssh-to-age < $EXTRA/persist/etc/ssh/ssh_host_ed25519_key.pub
```

Add the printed `age1…` key to `.sops.yaml`:

```
keys:
  - &<host> "age1…"
creation_rules:
  - path_regex: nixos/hosts/<host>/(secrets\.sops\.yaml|private\.nix\.sops)$
    key_groups:
      - age:
          - *recovery
          - *<host>
```

## 6. Secrets

Every key referenced from `secrets.sops.yaml` must exist, or the build fails
with `the key '…' cannot be found`. List them:

```
grep -rn -A3 'sops.secrets' nixos/hosts/<host> nixos/modules
```

Common generators:

```
mkpasswd -m yescrypt                                  # login passwords (hashed)
nix shell nixpkgs#apacheHttpd -c htpasswd -nB <name>  # nginx basic auth
openssl rand -hex 32                                  # random keys
```

Edit, re-key, track:

```
sops nixos/hosts/<host>/secrets.sops.yaml
sops updatekeys -y nixos/hosts/<host>/private.nix.sops
git add .sops.yaml nixos/hosts/<host>/
```

Multi-line values:

```
some-secret: |
    line1
    line2
```

Back up any key whose loss breaks data continuity (e.g. pseudonymisation
keys) offline.

## 7. Build

```
SOPS_DECRYPTION_ORDER=age sops -d --input-type binary --output-type binary \
  nixos/hosts/<host>/private.nix.sops > $P/private.nix
for a in toplevel diskoScript; do
  nix build .#nixosConfigurations.<host>.config.system.build.$a \
    --override-input private path:$P --no-write-lock-file -o result-$a
done
```

## 8. Install (wipes the disk)

```
nix run github:nix-community/nixos-anywhere -- \
  --store-paths ./result-diskoScript ./result-toplevel \
  --extra-files $EXTRA <host>-install
```

If it aborts after disko, check `ssh <host>-install findmnt -R /mnt`. Still
mounted → resume without re-partitioning:

```
nix run github:nix-community/nixos-anywhere -- --phases install,reboot \
  --store-paths ./result-diskoScript ./result-toplevel \
  --extra-files $EXTRA <host>-install
```

## 9. After first boot

```
rm -rf "$EXTRA" "$P" result-toplevel result-diskoScript
```

- Copy `hardware.json` to `/persist/etc/nix-local/<host>/` on the host.
- Delete stray host-key copies (e.g. on the jump host).
- Replace the `<host>-install` SSH entry with a normal one.
- Later updates: `scripts/rebuild <host>` on the host, or `scripts/remote-update`.

## Gotchas

- Untracked files are invisible to the flake: `git add` new host files.
- Decrypt and build where the sops key is; don't carry plaintext to the jump host.
- Target behind a proxy/no internet: never `nix run` there; `nix copy` instead.
- Stock ISO `nixos` user has no password; set one before SSH.
