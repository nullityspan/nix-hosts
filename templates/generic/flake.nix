{
  description = "Bare nixpkgs devShell";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        # Add project tools here, e.g. packages = with pkgs; [ jq ripgrep ];
        packages = [ ];
      };
    };
}
