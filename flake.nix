{
  description = "NixOS hosts";

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-26.05/nixexprs.tar.zst";
    nixpkgs-small.url = "https://channels.nixos.org/nixos-26.05-small/nixexprs.tar.zst";
    nixpkgs-unstable.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.zst";
    disko = {
      url = "github:nix-community/disko/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    impermanence = {
      url = "github:nix-community/impermanence";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    blender-bin.url = "github:edolstra/nix-warez?dir=blender";

    # Stub; scripts/rebuild overrides it with the host's decrypted private data.
    private = {
      url = "path:./nixos/private/stub";
      flake = false;
    };

    # Agentic AI
    ponytail = {
      url = "github:DietrichGebert/ponytail";
      flake = false;
    };

    # DNS filter
    oisd = {
      url = "https://big.oisd.nl/domainswild";
      flake = false;
    };
  };

  outputs =
    inputs:
    let
      system = "x86_64-linux";
      pkgs = import inputs.nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
      # Lint gate: run a tool over the flake source, succeed by touching $out.
      lintCheck =
        name: tool: cmd:
        pkgs.runCommand "check-${name}" { nativeBuildInputs = [ tool ]; } ''
          cd ${./.}
          ${cmd}
          touch $out
        '';
    in
    {
      # Auto-discovered from ./templates: each subdirectory is a template, its
      # description read from that template's own flake.nix (single source of
      # truth). Drop in a new dir with a flake.nix and it appears here.
      templates =
        let
          dir = ./templates;
          isDir = _: type: type == "directory";
          names = builtins.attrNames (inputs.nixpkgs.lib.filterAttrs isDir (builtins.readDir dir));
          mk = name: {
            path = dir + "/${name}";
            inherit (import (dir + "/${name}/flake.nix")) description;
          };
          discovered = inputs.nixpkgs.lib.genAttrs names mk;
        in
        discovered // { default = discovered.generic; };

      # Hosts come from hosts.nix; config lives in nixos/hosts/<name>/
      # (delta-only — logic stays in nixos/modules/ gated on host.* options).
      # Adding a host = hosts.nix entry + host dir.
      nixosConfigurations =
        let
          lib = inputs.nixpkgs.lib;
          hosts = builtins.attrNames (import ./hosts.nix);
          # home-manager.users are wired from hosts.nix in
          # nixos/modules/core/users.nix; only host-agnostic HM settings here.
          mkHost =
            name:
            lib.nixosSystem {
              inherit system;
              specialArgs = { inherit inputs; };
              modules = [
                ./nixos/hosts/${name}

                inputs.home-manager.nixosModules.home-manager
                {
                  home-manager = {
                    useGlobalPkgs = false;
                    useUserPackages = true;
                    extraSpecialArgs = {
                      inherit inputs;
                      unstable = pkgs;
                    };
                  };
                }
              ];
            };
        in
        lib.genAttrs hosts mkHost
        // {
          installer = lib.nixosSystem {
            inherit system;
            modules = [ ./nixos/installer ];
          };
        };

      packages.${system}.installer-iso =
        inputs.self.nixosConfigurations.installer.config.system.build.isoImage;

      formatter.${system} = pkgs.nixfmt;

      # `nix flake check` gates these. Build/VM tests stay manual via
      # `scripts/rebuild <host> build` and scripts/vmtest since a full system
      # closure is heavy for CI.
      checks.${system} = {
        format = lintCheck "format" pkgs.nixfmt "find . -name '*.nix' -type f -exec nixfmt --check {} +";
        statix = lintCheck "statix" pkgs.statix "statix check .";
        deadnix = lintCheck "deadnix" pkgs.deadnix "deadnix --fail .";
        # Runs from the repo root, so `# shellcheck source=scripts/...` resolves.
        shellcheck =
          lintCheck "shellcheck" pkgs.shellcheck
            "shellcheck -x $(find scripts -type f) templates/python-fhs/setup home/modules/system/git-identity.sh";
      };

      devShells.${system}.default = pkgs.mkShellNoCC {
        name = "nix-config";
        packages = with pkgs; [
          # scripts/check, scripts/fmt
          deadnix
          nixfmt
          statix
          # shell scripts
          shellcheck
          shfmt
          # scripts/lib/private.sh, scripts/facter
          sops
          ssh-to-age
          # closure inspection
          nix-diff
          nix-tree
        ];
      };
    };
}
