# nix-moloch

NixOS configuration for company-owned hosts (`research`). Same structure as the
personal nix-config: hosts listed in `flake.nix`, one directory per host under
`nixos/hosts/`, logic in `nixos/modules/` gated on `host.*` options.

Build and deploy via `scripts/rebuild <host>`; it decrypts the host's
`private.nix.sops` into the `private` flake input.
