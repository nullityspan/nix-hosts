{
  description = "Desktop NixOS Configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
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
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    blender-bin.url = "github:edolstra/nix-warez?dir=blender";
    # Stub; scripts/rebuild overrides it with the host's decrypted private data.
    private = {
      url = "path:./private-stub";
      flake = false;
    };
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

      # Host registry: one entry per machine, config lives in
      # nixos/hosts/<name>/ (delta-only — logic stays in nixos/modules/
      # gated on host.* options). Adding a host = list entry + host dir.
      nixosConfigurations =
        let
          lib = inputs.nixpkgs.lib;
          hosts = [
            "workstation"
            "research"
          ];
          # home-manager.users.<primary> and extraSpecialArgs.user are declared
          # per host in nixos/hosts/<name>/default.nix (hosts have different
          # primary users); only host-agnostic HM settings live here.
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
                  };
                }
              ];
            };
        in
        lib.genAttrs hosts mkHost;

      formatter.${system} = pkgs.nixfmt;

      # `nix flake check` gates these. Build/VM tests stay manual via
      # scripts/{test,vmtest} since a full system closure is heavy for CI.
      checks.${system} = {
        format = lintCheck "format" pkgs.nixfmt "find . -name '*.nix' -type f -exec nixfmt --check {} +";
        statix = lintCheck "statix" pkgs.statix "statix check .";
        deadnix = lintCheck "deadnix" pkgs.deadnix "deadnix --fail .";
      };

      devShells.${system}.default = pkgs.mkShellNoCC {
        name = "nix-config";
        packages = with pkgs; [
          bash-language-server
          deadnix
          home-manager
          manix
          nixd
          nix-diff
          nixfmt
          nix-melt
          nix-tree
          prettier
          statix
          taplo
          vscode-langservers-extracted
          openssl
          claude-code
          graphify
        ];

        shellHook = ''
          echo "NixOS Configuration Development Environment"
          echo ""
        '';
      };
    };
}
