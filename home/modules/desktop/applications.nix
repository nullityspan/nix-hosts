{
  inputs,
  pkgs,
  lib,
  osConfig,
  ...
}:
let
  hasWayland = osConfig.programs.sway.enable or false;
  hasDocker = osConfig.virtualisation.docker.enable or false;

  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
in
{
  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;
      setSessionVariables = true;
    };
    mimeApps = lib.mkIf hasWayland {
      enable = true;
      defaultApplications = {
        "text/html" = "google-chrome.desktop";
        "x-scheme-handler/http" = "google-chrome.desktop";
        "x-scheme-handler/https" = "google-chrome.desktop";
        "x-scheme-handler/about" = "google-chrome.desktop";
        "x-scheme-handler/unknown" = "google-chrome.desktop";

        "inode/directory" = "thunar.desktop";
        "application/x-directory" = "thunar.desktop";
        "application/pdf" = "org.pwmt.zathura.desktop";

        "image/png" = "org.gnome.Loupe.desktop";
        "image/jpeg" = "org.gnome.Loupe.desktop";
        "image/gif" = "org.gnome.Loupe.desktop";
        "image/webp" = "org.gnome.Loupe.desktop";
        "image/svg+xml" = "org.gnome.Loupe.desktop";

        # Documents — LibreOffice
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document" = "writer.desktop"; # .docx
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" = "calc.desktop"; # .xlsx
        "application/vnd.openxmlformats-officedocument.presentationml.presentation" = "impress.desktop"; # .pptx
        "application/vnd.oasis.opendocument.text" = "writer.desktop"; # .odt
        "application/vnd.oasis.opendocument.spreadsheet" = "calc.desktop"; # .ods
        "application/vnd.oasis.opendocument.presentation" = "impress.desktop"; # .odp
        "application/msword" = "writer.desktop"; # .doc
        "application/vnd.ms-excel" = "calc.desktop"; # .xls
        "application/vnd.ms-powerpoint" = "impress.desktop"; # .ppt
        "text/csv" = "calc.desktop"; # .csv

        # Archives — File Roller
        "application/zip" = "org.gnome.FileRoller.desktop";
        "application/x-tar" = "org.gnome.FileRoller.desktop";
        "application/gzip" = "org.gnome.FileRoller.desktop";
        "application/x-7z-compressed" = "org.gnome.FileRoller.desktop";
        "application/x-rar-compressed" = "org.gnome.FileRoller.desktop";
      };
    };
    configFile."Thunar/uca.xml" = {
      force = true;
      text = lib.mkIf hasWayland ''
        <?xml version="1.0" encoding="UTF-8"?>
        <actions>
          <action>
            <icon>utilities-terminal</icon>
            <name>Open Terminal Here</name>
            <command>ghostty --working-directory %f</command>
            <description>Open terminal in current directory</description>
            <patterns>*</patterns>
            <startup-notify/>
            <directories/>
          </action>
          <action>
            <icon>text-editor</icon>
            <name>Edit as Root</name>
            <command>sudo helix %f</command>
            <description>Edit file with root privileges</description>
            <patterns>*</patterns>
            <text-files/>
          </action>
          <action>
            <icon>emblem-symbolic-link</icon>
            <name>Create Link</name>
            <command>ln -s %f %f.link</command>
            <description>Create symbolic link</description>
            <patterns>*</patterns>
            <other-files/>
          </action>
        </actions>
      '';
    };
  };

  home.packages =
    (
      with pkgs;
      [
        # CLI tools (no GUI needed)
        ffmpeg
        imagemagick
        exiftool
        nmap
        netcat
        iperf3
        dig

        # Archive formats
        zip
        unzip
        p7zip
        unrar

        # Spell checking
        aspell
        aspellDicts.en
        aspellDicts.de
      ]
      ++ lib.optionals hasWayland [
        # GUI applications
        networkmanagerapplet
        polkit_gnome
        pavucontrol
        pulsemixer
        easyeffects
        crosspipe
        bluez
        bluez-tools
        blueman

        thunar
        thunar-volman
        thunar-archive-plugin
        thunar-media-tags-plugin
        tumbler

        file-roller
        ffmpegthumbnailer
        poppler-utils

        vlc
        libreoffice
        zotero
        system-config-printer
        sane-frontends
        simple-scan
        loupe

      ]
      ++ lib.optionals hasDocker [
        dive
        lazydocker
      ]
    )
    ++ (
      with unstable;
      lib.optionals hasWayland [
        keepassxc
        google-chrome
        spotify
        discord
        lmstudio-bionic
        wtype
      ]
    )

  ;

  programs = {
    zathura = {
      enable = hasWayland;
      options = {
        default-bg = "#1a1a1a";
        default-fg = "#c0c0c0";
        statusbar-bg = "#1a1a1a";
        statusbar-fg = "#c0c0c0";
        inputbar-bg = "#1a1a1a";
        inputbar-fg = "#ffffff";
        highlight-color = "#81a1c1";
        highlight-active-color = "#88c0d0";
        recolor = true;
        recolor-lightcolor = "#1a1a1a";
        recolor-darkcolor = "#c0c0c0";
        recolor-keephue = true;
        font = "JetBrains Mono 11";
        selection-clipboard = "clipboard";
      };
    };
  };

  systemd.user.services.set-default-volume = lib.mkIf hasWayland {
    Unit = {
      Description = "Set default audio volume";
      After = [ "pipewire.service" ];
      Wants = [ "pipewire.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 30%";
      RemainAfterExit = true;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
