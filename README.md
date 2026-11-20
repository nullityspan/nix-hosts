# nix-hosts

NixOS configuration for all my hosts in one flake. Hosts are registered in
`hosts.nix` (age key, users, login keys, `managedBy`), one directory per host
under `nixos/hosts/`. Admin keys live in `keys.nix`.

| Host          | Role                                | Deployed from              |
| ------------- | ----------------------------------- | -------------------------- |
| `workstation` | primary machine, manages all others | itself (`scripts/rebuild`) |
| `research`    | compute host, often runs unattended | workstation                |
| `satellite`   | shared server                       | research or workstation    |

Remote hosts are deployed with `scripts/rebuild <host> switch --target <user>@<target>`.

## Architecture

- **ZFS impermanence**: root is rolled back to a blank snapshot each boot; state
  survives only via opt-in persistence (`nixos/modules/hardware/storage.nix`).
- **`host.*` option namespace** (`nixos/modules/core/options.nix`): hosts
  declare settings, modules consume them (incl. auto-detected Nvidia/Bluetooth
  from the nixos-facter report).
- **Private data**: identifying values (hostnames, addresses) live in
  `nixos/hosts/<host>/private.sops.yaml`, decrypted to JSON by
  `scripts/rebuild` into the `private` flake input and read as
  `config.host.private.host`. Nothing identifying is committed
  in plain text.
- **Secrets**: sops-nix, one scope per host. A host can decrypt its own scope
  and the scopes of hosts it manages; recovery keys can decrypt all.
- **Dual channel**: system runs stable; fresher packages are pulled from
  unstable where needed.

## Secrets

Recipients are derived, never written by hand: `sops.nix` reads `keys.nix`
(Nitrokeys, recovery key) and `hosts.nix` (host keys, `managedBy`), and
`scripts/sops-config` renders `.sops.yaml`. Every file of a host is readable
by that host, the hosts that manage it and the admin keys.

Day-to-day work uses this machine's host key, not a Nitrokey:

```sh
export SOPS_AGE_KEY="$(sudo ssh-to-age -private-key -i /etc/ssh/ssh_host_ed25519_key)"
export SOPS_DECRYPTION_ORDER=age
```

- **Edit**: `sops nixos/hosts/<host>/secrets.sops.yaml`. One value:
  `sops set <file> '["key"]' '"value"'`; remove with `sops unset`.
- **New secret**: add the value, then declare it under `sops.secrets` (host
  module) so the host decrypts it to `/run/secrets/<key>`.
- **Re-key** after a change to `keys.nix`, `hosts.nix` keys or `managedBy`:

  ```sh
  scripts/sops-config
  for f in nixos/hosts/*/*.sops.yaml; do sops updatekeys -y "$f"; done
  ```

  `hardware.json.sops` is binary: re-encrypt it as in `docs/remote-install.md`.

  Removing a recipient does not un-leak old values: rotate the secrets too.
- **Git persona**: `scripts/persona <host> <persona> "<name>" "<email>"`
  writes the key, signers file and gitconfig fragment and prints the public
  key for the forge. Then list the persona under `users.<name>.personas` in
  `hosts.nix`, rebuild, and run `git-identity <persona>` in a repo.
- **User password**: `mkpasswd -m yescrypt`, stored as `<user>-password`.

Finish with `unset SOPS_AGE_KEY`. A new host is covered in
`docs/remote-install.md`.

## Templates

`templates/` holds flake templates for project dev shells. Start a project with
`nix flake init -t templates#<name>`, then `direnv allow`. Before a host is
rebuilt with the `templates` registry entry, use
`nix flake init -t <path-to-this-repo>#<name>`. Templates ship no `flake.lock`,
so each project locks fresh on first use.

| Name          | Description                                          |
| ------------- | ---------------------------------------------------- |
| `c`           | C (clang, cmake, ninja, gdb)                         |
| `generic`     | Bare nixpkgs devShell (also the default)             |
| `python`      | Python (uv, ruff, ty)                                |
| `python-fhs`  | Python FHS (for pip/uv binary wheels)                |
| `rust`        | Rust (cargo, clippy, rust-analyzer, sccache)         |
| `typst-latex` | Typst + LaTeX typesetting (tinymist, texlab, pandoc) |
| `web`         | Web (node, ts, biome)                                |
| `zig`         | Zig (zig, zls)                                       |

`python-fhs` has no `.envrc`: direnv cannot enter its bubblewrap sandbox. Enter
it with `nix develop`, then `. ./setup`. A new template is a new directory
under `templates/` with a `flake.nix`; its `description` becomes the template
description.
