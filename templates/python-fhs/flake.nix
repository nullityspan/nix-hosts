{
  description = "Python FHS (for pip/uv binary wheels)";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      fhs = pkgs.buildFHSEnv {
        name = "python-fhs";
        targetPkgs =
          p: with p; [
            uv
            ruff
            ty
            python3
            python3Packages.ipython

            # Runtime libs commonly needed by binary wheels
            stdenv.cc.cc.lib
            zlib
            libGL
            glib
            musl
          ];
        runScript = "bash";
      };
    in
    {
      devShells.${system}.default = fhs.env;
    };
}
