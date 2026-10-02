# nix-config

Personal NixOS configuration. Hosts registered in the `hosts` list in `flake.nix`,
one directory per host under `nixos/hosts/` (`workstation`, `research`).

## Commands

| Command                 | Purpose                                             |
| ----------------------- | --------------------------------------------------- |
| `scripts/check`         | Lint: statix + deadnix + `nix flake check`          |
| `scripts/fmt`           | Format all `.nix` files (nixfmt) + statix autofix   |
| `scripts/test`          | Build system closure + `nixos-rebuild dry-run`      |
| `scripts/vmtest`        | Boot the config in a QEMU VM (vmVariantWithDisko)   |
| `scripts/home-rebuild`  | Quick home-manager-only activation (not persisted)  |
| `scripts/remote-update` | `nixos-rebuild switch` locally or on a remote host  |

## Architecture

- **ZFS impermanence**: root is rolled back to a blank snapshot each boot; state survives
  only via opt-in persistence (`nixos/modules/hardware/storage.nix`).
- **`host.*` option namespace** (`nixos/modules/core/options.nix`): hosts declare settings,
  modules consume them (incl. auto-detected Nvidia/Bluetooth from the nixos-facter report).
- **Dual channel**: system runs stable `nixos-26.05`; fresher packages are pulled from
  `nixpkgs-unstable` where needed.

See `AGENTS.md` for conventions, a directory map, and the add-host checklist.
