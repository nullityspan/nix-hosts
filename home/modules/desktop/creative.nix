{
  pkgs,
  lib,
  inputs,
  osConfig,
  ...
}:
let
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
  hasWayland = osConfig.programs.sway.enable or false;
  hasNvidia = osConfig.host.hardware.hasNvidia or false;
in
{
  home.packages =
    lib.optionals hasWayland [
      unstable.obs-studio
      unstable.audacity
      unstable.gimp
      unstable.freecad
    ]
    ++ lib.optionals (hasWayland && hasNvidia) [
      inputs.blender-bin.packages.${pkgs.stdenv.hostPlatform.system}.default
    ]
    ++ lib.optionals (hasWayland && !hasNvidia) [
      unstable.blender
    ];
}
