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
