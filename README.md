# nix-config

Personal NixOS configuration. Hosts registered in the `hosts` list in
`flake.nix`, one directory per host under `nixos/hosts/` (`workstation`,
`research`).

## Architecture

- **ZFS impermanence**: root is rolled back to a blank snapshot each boot; state
  survives only via opt-in persistence (`nixos/modules/hardware/storage.nix`).
- **`host.*` option namespace** (`nixos/modules/core/options.nix`): hosts
  declare settings, modules consume them (incl. auto-detected Nvidia/Bluetooth
  from the nixos-facter report).
- **Dual channel**: system runs stable; fresher packages are pulled from
  unstable where needed.
