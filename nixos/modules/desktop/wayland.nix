{
  pkgs,
  lib,
  config,
  ...
}:
{
  security.pam.services.swaylock = {
    enable = true;
    text = ''
      auth include login
    '';
  };

  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    extraOptions = lib.optionals config.host.hardware.hasNvidia [
      "--unsupported-gpu"
    ];
  };

  services = {
    displayManager.ly = {
      enable = true;
      settings = {
        animation = "gameoflife";
        blank_password = true;
      };
    };
    gvfs.enable = true;
    udisks2.enable = true;
    power-profiles-daemon.enable = true;
  };

  # Nvidia-specific Wayland environment
  environment.sessionVariables = lib.mkIf config.host.hardware.hasNvidia {
    WLR_NO_HARDWARE_CURSORS = "1";
    WLR_RENDERER = "vulkan";
    NIXOS_OZONE_WL = "1";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
  };

  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-wlr
      xdg-desktop-portal-gtk
    ];
    config = {
      common = {
        default = [ "gtk" ];
      };
      sway = lib.mkForce {
        default = [
          "wlr"
          "gtk"
        ];
        "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
      };
    };
  };

  environment.systemPackages = with pkgs; [
    xinit
    xauth
    xterm
    swaylock
  ];
}
