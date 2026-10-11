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
    wlr = {
      enable = true;
      # default chooser picks slurp, which can only select outputs, not windows
      settings.screencast = {
        chooser_type = "dmenu";
        # Chrome re-asks for windows right after the first pick (no restore data
        # for toplevels), so reuse a pick made in the last 5s instead of prompting twice
        chooser_cmd = "${pkgs.writeShellScript "xdpw-chooser" ''
          cache="''${XDG_RUNTIME_DIR:-/tmp}/xdpw-last-choice"
          choices=$(cat)
          if [ -f "$cache" ] && [ $(( $(date +%s) - $(stat -c %Y "$cache") )) -lt 5 ]; then
            last=$(cat "$cache")
            if printf '%s\n' "$choices" | grep -qxF -- "$last"; then
              rm -f "$cache"
              printf '%s\n' "$last"
              exit 0
            fi
          fi
          pick=$(printf '%s\n' "$choices" | ${pkgs.fuzzel}/bin/fuzzel --dmenu --prompt='Share: ')
          [ -n "$pick" ] && printf '%s\n' "$pick" > "$cache"
          printf '%s\n' "$pick"
        ''}";
      };
    };
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
