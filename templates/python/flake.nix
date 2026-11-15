{
  description = "Python (uv, ruff, ty)";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          uv
          ruff
          ty
          python3
          python3Packages.ipython
        ];
        # uv-managed Pythons are generic-Linux binaries that NixOS cannot run; use the Nix one.
        UV_PYTHON_DOWNLOADS = "never";
        UV_PYTHON_PREFERENCE = "only-system";
      };
    };
}
