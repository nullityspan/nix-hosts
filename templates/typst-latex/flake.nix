{
  description = "Typst + LaTeX typesetting (tinymist, texlab, pandoc)";

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
          # Typst
          typst
          tinymist
          typstyle

          # LaTeX
          texlive.combined.scheme-medium
          texlab

          # Conversion
          pandoc
        ];
      };
    };
}
