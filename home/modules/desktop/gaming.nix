{
  unstable,
  pkgs,
  lib,
  osConfig,
  ...
}:
let
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
