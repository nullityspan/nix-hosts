{
  inputs,
  pkgs,
  lib,
  osConfig,
  ...
}:
let
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
  hasWayland = osConfig.programs.sway.enable or false;
in
{
  programs.java = {
    enable = true;
    package = pkgs.jdk21;
  };

  home.packages = lib.optionals hasWayland [
    unstable.prismlauncher
  ];
}
