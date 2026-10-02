{
  inputs,
  pkgs,
  lib,
  osConfig,
  ...
}:
let
  hasWayland = osConfig.programs.sway.enable or false;
  hasBluetooth = osConfig.hardware.bluetooth.enable or false;

  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
in
{
  wayland.windowManager.sway = lib.mkIf hasWayland {
    enable = true;
    systemd = {
      enable = true;
      xdgAutostart = true;
    };
    checkConfig = false;
    extraOptions = [ "--unsupported-gpu" ];
    extraSessionCommands = ''
      export WLR_NO_HARDWARE_CURSORS=1
      export WLR_RENDERER=vulkan
      export XCURSOR_THEME=Bibata-Modern-Classic
      export XCURSOR_SIZE=24
    '';

    config = {
      modifier = "Mod4";
      terminal = "${pkgs.ghostty}/bin/ghostty";
      menu = "${pkgs.fuzzel}/bin/fuzzel";

      gaps = {
        inner = 0;
        outer = 0;
      };

      bars = [ ];

      assigns = {
        "1" = [
          { class = "^Google-chrome$"; }
          { app_id = "^com.mitchellh.ghostty$"; }
        ];
      };

      startup = [
        { command = "${pkgs.networkmanagerapplet}/bin/nm-applet"; }
        { command = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"; }
        { command = "${pkgs.blueman}/bin/blueman-applet"; }
        # Launch apps ON workspace 1 explicitly
        { command = "swaymsg 'workspace 1; exec google-chrome-stable'"; }
        { command = "swaymsg 'workspace 1; exec ghostty'"; }
      ];

      keybindings =
        let
          mod = "Mod4";
        in
        lib.mkOptionDefault {
          "${mod}+Return" = "exec ${pkgs.ghostty}/bin/ghostty";
          "${mod}+d" = "exec ${pkgs.fuzzel}/bin/fuzzel";
          "${mod}+Shift+q" = "kill";
          "${mod}+Shift+Escape" = "exec ${pkgs.swaylock-effects}/bin/swaylock";
          "${mod}+Shift+e" = "exec ${pkgs.thunar}/bin/thunar";
          "${mod}+Shift+x" = "exec swaymsg exit";

          # Vim-like focus
          "${mod}+h" = "focus left";
          "${mod}+j" = "focus down";
          "${mod}+k" = "focus up";
          "${mod}+l" = "focus right";

          # Move windows
          "${mod}+Shift+h" = "move left";
          "${mod}+Shift+j" = "move down";
          "${mod}+Shift+k" = "move up";
          "${mod}+Shift+l" = "move right";

          # Workspaces
          "${mod}+1" = "workspace number 1";
          "${mod}+2" = "workspace number 2";
          "${mod}+3" = "workspace number 3";
          "${mod}+4" = "workspace number 4";
          "${mod}+5" = "workspace number 5";
          "${mod}+6" = "workspace number 6";
          "${mod}+7" = "workspace number 7";
          "${mod}+8" = "workspace number 8";
          "${mod}+9" = "workspace number 9";

          "${mod}+Shift+1" = "move container to workspace number 1";
          "${mod}+Shift+2" = "move container to workspace number 2";
          "${mod}+Shift+3" = "move container to workspace number 3";
          "${mod}+Shift+4" = "move container to workspace number 4";
          "${mod}+Shift+5" = "move container to workspace number 5";
          "${mod}+Shift+6" = "move container to workspace number 6";
          "${mod}+Shift+7" = "move container to workspace number 7";
          "${mod}+Shift+8" = "move container to workspace number 8";
          "${mod}+Shift+9" = "move container to workspace number 9";

          # Layout
          "${mod}+f" = "fullscreen toggle";
          "${mod}+v" = "split vertical";
          "${mod}+b" = "split horizontal";
          "${mod}+s" = "layout stacking";
          "${mod}+w" = "layout tabbed";
          "${mod}+e" = "layout toggle split";
          "${mod}+Shift+space" = "floating toggle";
          "${mod}+space" = "focus mode_toggle";

          # Speech-to-text (handy) - Tauri global-shortcut plugin can't
          # register under sway/wlroots (no GlobalShortcuts portal impl),
          # so trigger via handy's own CLI IPC flag instead.
          "--no-repeat ${mod}+g" = "exec ${unstable.handy}/bin/handy --toggle-transcription";

          # Escape hatch for apps holding a shortcuts inhibitor (RDP clients):
          # --inhibited fires even while the app grabs the keyboard.
          "--inhibited ${mod}+Escape" = "seat - shortcuts_inhibitor toggle";
          "--inhibited ${mod}+Shift+BackSpace" = "kill";

          # Screenshot
          "${mod}+p" =
            "exec ${pkgs.grim}/bin/grim -g \"$(${pkgs.slurp}/bin/slurp)\" - | ${pkgs.wl-clipboard}/bin/wl-copy";
          "${mod}+Shift+p" =
            "exec ${pkgs.grim}/bin/grim -g \"$(${pkgs.slurp}/bin/slurp)\" ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png";
          "${mod}+Ctrl+p" = "exec ${pkgs.grim}/bin/grim - | ${pkgs.wl-clipboard}/bin/wl-copy";
          "${mod}+Ctrl+Shift+p" =
            "exec ${pkgs.grim}/bin/grim ~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png";
        };

      window.commands = [
        {
          criteria.app_id = "firefox";
          command = "inhibit_idle fullscreen";
        }
        {
          criteria.app_id = "floating-cheatsheet";
          command = "floating enable, resize set 900 700, move position center";
        }
      ];
    };
  };

  programs = {
    waybar = {
      enable = true;
      systemd = {
        enable = true;
        targets = [ "sway-session.target" ];
      };
      settings = [
        {
          layer = "top";
          position = "top";
          height = 28;
          spacing = 0;

          modules-left = [ "sway/workspaces" ];
          modules-center = [ "clock" ];
          modules-right = [
            "cpu"
            "memory"
            "network"
          ]
          ++ lib.optionals hasBluetooth [ "bluetooth" ]
          ++ [ "pulseaudio" ];

          "sway/workspaces" = {
            disable-scroll = true;
            format = "{index}";
          };

          clock = {
            format = "{:%a %d %b  %H:%M}";
            tooltip-format = "<tt>{calendar}</tt>";
            calendar = {
              mode = "month";
              mode-mon-col = 1;
              weeks-pos = "left";
              on-scroll = 1;
              format = {
                months = "<span color='#ffffff'><b>{}</b></span>";
                days = "<span color='#c0c0c0'>{}</span>";
                weeks = "<span color='#606060'>W{}</span>";
                weekdays = "<span color='#ffffff'><b>{}</b></span>";
                today = "<span color='#81a1c1'><b><u>{}</u></b></span>";
              };
            };
            actions = {
              on-click-right = "mode";
              on-scroll-up = "shift_up";
              on-scroll-down = "shift_down";
            };
          };

          cpu = {
            format = "cpu {usage}%";
            interval = 5;
            on-click = "${pkgs.resources}/bin/resources";
          };

          memory = {
            format = "mem {percentage}%";
            interval = 5;
            on-click = "${pkgs.resources}/bin/resources";
          };

          network = {
            format-wifi = "{essid}";
            format-ethernet = "eth";
            format-disconnected = "offline";
            tooltip-format = "{ifname}: {ipaddr}";
            on-click = "${pkgs.networkmanagerapplet}/bin/nm-connection-editor";
          };

          bluetooth = {
            format = "bt {status}";
            format-connected = "bt {device_alias}";
            on-click = "${pkgs.blueman}/bin/blueman-manager";
            tooltip-format-connected = "{device_enumerate}";
            tooltip-format-enumerate-connected = "{device_alias}";
          };

          pulseaudio = {
            format = "vol {volume}%";
            format-muted = "muted";
            on-click = "${pkgs.pavucontrol}/bin/pavucontrol";
          };
        }
      ];

      style = ''
        * {
          font-family: "JetBrains Mono", monospace;
          font-size: 0.85rem;
          border: none;
          border-radius: 0;
          min-height: 0;
        }

        window#waybar {
          background: #1a1a1a;
          color: #c0c0c0;
        }

        #workspaces button {
          padding: 0 0.5rem;
          color: #606060;
          background: transparent;
        }

        #workspaces button.focused {
          color: #ffffff;
        }

        #workspaces button:hover {
          background: #333333;
        }

        #clock, #cpu, #memory, #network, #bluetooth, #pulseaudio {
          padding: 0 0.75rem;
        }

        #cpu, #pulseaudio, #memory, #network, #bluetooth {
          color: #ededed;
        }

      '';
    };
    swaylock = {
      enable = true;
      package = pkgs.swaylock-effects;
      settings = {
        screenshots = true;
        clock = true;
        indicator = true;
        indicator-radius = 100;
        indicator-thickness = 7;

        effect-blur = "15x5";
        effect-vignette = "0.5:0.5";
        fade-in = 0;

        font = "monospace";
        font-size = 24;

        timestr = "%H:%M";
        datestr = "%a, %d %b";

        # Colors matching your dark theme
        inside-color = "1a1a1a00";
        inside-clear-color = "1a1a1a00";
        inside-ver-color = "1a1a1a00";
        inside-wrong-color = "1a1a1a00";

        ring-color = "606060ff";
        ring-clear-color = "c0c0c0ff";
        ring-ver-color = "81a1c1ff";
        ring-wrong-color = "ee6060ff";

        key-hl-color = "81a1c1ff";
        bs-hl-color = "ee6060ff";

        separator-color = "00000000";
        text-color = "ffffffff";
        text-clear-color = "ffffffff";
        text-ver-color = "ffffffff";
        text-wrong-color = "ffffffff";

        line-color = "00000000";
        line-clear-color = "00000000";
        line-ver-color = "00000000";
        line-wrong-color = "00000000";

        grace = 0;
        ignore-empty-password = true;
      };
    };
    fuzzel = {
      enable = true;
      settings = {
        main = {
          font = "JetBrains Mono:size=12";
          dpi-aware = "yes";
          width = 35;
          horizontal-pad = 12;
          vertical-pad = 8;
          inner-pad = 4;
        };
        colors = {
          background = "1a1a1aff";
          text = "c0c0c0ff";
          match = "ffffffff";
          selection = "333333ff";
          selection-text = "ffffffff";
          border = "333333ff";
        };
        border = {
          width = 1;
          radius = 0;
        };
      };
    };
    ghostty = {
      enable = true;
      enableBashIntegration = true;
      settings = {
        font-size = 12;
        font-family = "JetBrains Mono";
        font-feature = [
          "-liga"
          "-calt"
        ];

        background = "1a1a1a";
        foreground = "c0c0c0";
        cursor-color = "c0c0c0";
        selection-background = "2a2a2a";
        selection-foreground = "ffffff";

        # Normal colors (0-7)
        palette = [
          "0=#1a1a1a" # black
          "1=#ee6060" # red
          "2=#7ec87e" # green
          "3=#d4a057" # yellow
          "4=#81a1c1" # blue
          "5=#b48ead" # magenta
          "6=#88c0d0" # cyan
          "7=#c0c0c0" # white

          # Bright colors (8-15)
          "8=#606060" # bright black
          "9=#ff7070" # bright red
          "10=#8fd88f" # bright green
          "11=#e0b060" # bright yellow
          "12=#93b3d3" # bright blue
          "13=#c6a0bf" # bright magenta
          "14=#9ad0e0" # bright cyan
          "15=#ffffff" # bright white
        ];

        window-padding-x = 8;
        window-padding-y = 8;
        window-decoration = false;
        confirm-close-surface = false;
        copy-on-select = "clipboard";
      };
    };
  };

  services = {
    mako = {
      enable = true;
      settings = {
        "" = {
          font = "JetBrains Mono 11";
          background-color = "#1a1a1a";
          text-color = "#c0c0c0";
          border-color = "#3383d3";
          border-size = 1;
          border-radius = 0;
          padding = "12";
          margin = "10";
          width = 300;
          default-timeout = 5000;
        };
        "urgency=low" = {
          background-color = "#1a1a1a";
          text-color = "#808080";
        };
        "urgency=high" = {
          background-color = "#1a1a1a";
          text-color = "#ffffff";
          border-color = "#ee6060";
        };
      };
    };
    swayidle = lib.mkIf hasWayland {
      enable = true;
      events = {
        lock = "${pkgs.swaylock-effects}/bin/swaylock -f";
      };
      timeouts = [
        {
          timeout = 300;
          command = "${pkgs.swaylock-effects}/bin/swaylock -f";
        }
      ];
    };
  };

  systemd.user.services.handy = lib.mkIf hasWayland {
    Unit = {
      Description = "Handy speech-to-text";
      PartOf = [ "sway-session.target" ];
      After = [ "sway-session.target" ];
    };
    Install.WantedBy = [ "sway-session.target" ];
    Service = {
      ExecStart = "${unstable.handy}/bin/handy --start-hidden";
      Restart = "on-failure";
    };
  };

  home.packages = with pkgs; [
    wl-clipboard
    grim
    slurp
    swayidle
    wdisplays
    libnotify
  ];
}
