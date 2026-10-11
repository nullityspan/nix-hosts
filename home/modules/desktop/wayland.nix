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

  c = import ./palette.nix;
  notify = "${pkgs.libnotify}/bin/notify-send";
  osd = "${pkgs.swayosd}/bin/swayosd-client";
  swaylock = "${pkgs.swaylock-effects}/bin/swaylock";

  # Dot grid with a faint accent glow in the centre; nothing from the screen shows through.
  lockBg = pkgs.runCommand "lock-bg.png" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
    magick -size 24x24 xc:'#${c.bg}' -fill '#${c.overlay}' -draw 'circle 12,12 13.2,12' dot.png
    magick -size 2560x1440 tile:dot.png dots.png
    magick -size 2560x1440 radial-gradient:'#${c.accent}'-'#${c.bg}' glow.png
    magick dots.png -colorspace sRGB glow.png -compose blend -define compose:args=14 -composite $out
  '';

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
        inner = 4;
        outer = 0;
        smartGaps = true;
      };

      window = {
        border = 2;
        titlebar = false;
      };
      floating = {
        border = 2;
        titlebar = false;
      };

      colors =
        let
          set = border: text: {
            inherit border text;
            background = "#${c.bg}";
            indicator = border;
            childBorder = border;
          };
        in
        {
          focused = set "#${c.accent}" "#${c.bright}";
          focusedInactive = set "#${c.overlay}" "#${c.fg}";
          unfocused = set "#${c.bg}" "#${c.muted}";
          urgent = set "#${c.red}" "#${c.bright}";
        };

      workspaceAutoBackAndForth = true;

      bars = [ ];

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
          "${mod}+Shift+Escape" = "exec ${swaylock}";
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

          # Speech-to-text (handy) - Tauri global-shortcut plugin can't
          # register under sway/wlroots (no GlobalShortcuts portal impl),
          # so trigger via handy's own CLI IPC flag instead.
          "--no-repeat ${mod}+g" = "exec ${unstable.handy}/bin/handy --toggle-transcription";

          # Escape hatch for apps holding a shortcuts inhibitor (RDP clients):
          # --inhibited fires even while the app grabs the keyboard.
          "--inhibited ${mod}+Escape" = "seat - shortcuts_inhibitor toggle";
          "--inhibited ${mod}+Shift+BackSpace" = "kill";

          # Volume (OSD)
          "XF86AudioRaiseVolume" = "exec ${osd} --output-volume raise";
          "XF86AudioLowerVolume" = "exec ${osd} --output-volume lower";
          "XF86AudioMute" = "exec ${osd} --output-volume mute-toggle";
          "XF86AudioMicMute" = "exec ${osd} --input-volume mute-toggle";

          # Screenshot
          "${mod}+p" =
            "exec ${pkgs.grim}/bin/grim -g \"$(${pkgs.slurp}/bin/slurp)\" - | ${pkgs.wl-clipboard}/bin/wl-copy && ${notify} -t 2000 Screenshot 'Region copied'";
          "${mod}+Shift+p" =
            "exec f=~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png && ${pkgs.grim}/bin/grim -g \"$(${pkgs.slurp}/bin/slurp)\" $f && ${notify} -t 2000 -i $f Screenshot \"Saved $f\"";
          "${mod}+Ctrl+p" =
            "exec ${pkgs.grim}/bin/grim - | ${pkgs.wl-clipboard}/bin/wl-copy && ${notify} -t 2000 Screenshot 'Screen copied'";
          "${mod}+Ctrl+Shift+p" =
            "exec f=~/Pictures/screenshot-$(date +%Y%m%d-%H%M%S).png && ${pkgs.grim}/bin/grim $f && ${notify} -t 2000 -i $f Screenshot \"Saved $f\"";
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
            "tray"
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

          tray = {
            icon-size = 16;
            spacing = 8;
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
                months = "<span color='#${c.bright}'><b>{}</b></span>";
                days = "<span color='#${c.fg}'>{}</span>";
                weeks = "<span color='#${c.muted}'>W{}</span>";
                weekdays = "<span color='#${c.bright}'><b>{}</b></span>";
                today = "<span color='#${c.accent}'><b><u>{}</u></b></span>";
              };
            };
            actions = {
              on-click-right = "mode";
              on-scroll-up = "shift_up";
              on-scroll-down = "shift_down";
            };
          };

          cpu = {
            format = "  {usage}%";
            tooltip-format = "CPU {usage}%";
            states.warning = 80;
            interval = 5;
            on-click = "${pkgs.resources}/bin/resources";
          };

          memory = {
            format = "󰍛  {percentage}%";
            tooltip-format = "{used:0.1f} / {total:0.1f} GiB";
            states.warning = 80;
            interval = 5;
            on-click = "${pkgs.resources}/bin/resources";
          };

          network = {
            format-wifi = "󰖩  {essid}";
            format-ethernet = "󰈀";
            format-disconnected = "󰖪  offline";
            tooltip-format = "{ifname}: {ipaddr}";
            tooltip-format-wifi = "{essid} ({signalStrength}%)\n{ifname}: {ipaddr}";
            on-click = "${pkgs.networkmanagerapplet}/bin/nm-connection-editor";
          };

          bluetooth = {
            format = "󰂯";
            format-off = "󰂲";
            format-disabled = "󰂲";
            format-connected = "󰂱  {device_alias}";
            on-click = "${pkgs.blueman}/bin/blueman-manager";
            tooltip-format-connected = "{device_enumerate}";
            tooltip-format-enumerate-connected = "{device_alias}";
          };

          pulseaudio = {
            format = "{icon}  {volume}%";
            format-muted = "󰖁  muted";
            format-icons.default = [
              "󰕿"
              "󰖀"
              "󰕾"
            ];
            tooltip-format = "{desc}";
            on-click = "${pkgs.pavucontrol}/bin/pavucontrol";
          };
        }
      ];

      style = ''
        * {
          font-family: "JetBrains Mono", "Symbols Nerd Font", monospace;
          font-size: 0.85rem;
          border: none;
          border-radius: 0;
          min-height: 0;
        }

        window#waybar {
          background: #${c.bg};
          color: #${c.fg};
        }

        tooltip {
          background: #${c.bg};
          border: 1px solid #${c.overlay};
        }

        #workspaces button {
          padding: 0 0.6rem;
          color: #${c.muted};
          background: transparent;
          box-shadow: inset 0 -2px transparent;
        }

        #workspaces button.focused {
          color: #${c.bright};
          background: #${c.surface};
          box-shadow: inset 0 -2px #${c.accent};
        }

        #workspaces button.urgent {
          color: #${c.bg};
          background: #${c.red};
        }

        #workspaces button:hover {
          background: #${c.overlay};
        }

        #tray, #clock, #cpu, #memory, #network, #bluetooth, #pulseaudio {
          padding: 0 0.75rem;
        }

        #cpu, #pulseaudio, #memory, #network, #bluetooth {
          color: #${c.fg};
        }

        #cpu.warning, #memory.warning {
          color: #${c.yellow};
        }

        #network.disconnected, #pulseaudio.muted, #bluetooth.off, #bluetooth.disabled {
          color: #${c.red};
        }

        #tray > .needs-attention {
          background: #${c.red};
        }
      '';
    };
    swaylock = {
      enable = true;
      package = pkgs.swaylock-effects;
      settings = {
        image = "${lockBg}";
        scaling = "fill";
        clock = true;
        indicator = true;
        indicator-radius = 100;
        indicator-thickness = 7;

        fade-in = 0;

        font = "monospace";
        font-size = 24;

        timestr = "%H:%M";
        datestr = "%a, %d %b";

        inside-color = "${c.bg}00";
        inside-clear-color = "${c.bg}00";
        inside-ver-color = "${c.bg}00";
        inside-wrong-color = "${c.bg}00";

        ring-color = "${c.muted}ff";
        ring-clear-color = "${c.fg}ff";
        ring-ver-color = "${c.accent}ff";
        ring-wrong-color = "${c.red}ff";

        key-hl-color = "${c.accent}ff";
        bs-hl-color = "${c.red}ff";

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
          icon-theme = "Papirus-Dark";
        };
        colors = {
          background = "${c.bg}ff";
          text = "${c.fg}ff";
          match = "${c.accent}ff";
          selection = "${c.overlay}ff";
          selection-text = "${c.bright}ff";
          selection-match = "${c.accent}ff";
          border = "${c.accent}ff";
        };
        border = {
          width = 2;
          radius = 4;
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

        background = c.bg;
        foreground = c.fg;
        cursor-color = c.fg;
        selection-background = c.surface;
        selection-foreground = c.bright;

        palette = lib.imap0 (i: hex: "${toString i}=#${hex}") c.ansi;

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
          background-color = "#${c.bg}";
          text-color = "#${c.fg}";
          border-color = "#${c.accent}";
          border-size = 2;
          border-radius = 4;
          max-icon-size = 48;
          padding = "12";
          margin = "10";
          width = 300;
          default-timeout = 5000;
        };
        "urgency=low" = {
          text-color = "#${c.muted}";
          border-color = "#${c.overlay}";
        };
        "urgency=high" = {
          text-color = "#${c.bright}";
          border-color = "#${c.red}";
        };
      };
    };
    swayidle = lib.mkIf hasWayland {
      enable = true;
      events = {
        lock = "${swaylock} -f";
      };
      timeouts = [
        {
          # fade out over 10s first; any input aborts the lock
          timeout = 290;
          command = "${pkgs.chayang}/bin/chayang -d 10 && ${swaylock} -f";
        }
        {
          timeout = 600;
          command = "${pkgs.sway}/bin/swaymsg 'output * power off'";
          resumeCommand = "${pkgs.sway}/bin/swaymsg 'output * power on'";
        }
      ];
    };
    swayosd = lib.mkIf hasWayland {
      enable = true;
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
