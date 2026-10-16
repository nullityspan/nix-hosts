# nix-hosts

NixOS configuration for all my hosts in one flake. Hosts are registered in the
`hosts` list in `flake.nix`, one directory per host under `nixos/hosts/`.

| Host          | Role                                | Deployed from              |
| ------------- | ----------------------------------- | -------------------------- |
| `workstation` | primary machine, manages all others | itself (`scripts/rebuild`) |
| `research`    | compute host, often runs unattended | workstation                |
| `satellite`   | shared server                       | research or workstation    |

Remote hosts are deployed with `scripts/remote-update <host>`.

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
