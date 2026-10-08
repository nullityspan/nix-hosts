{
  config,
  pkgs,
  lib,
  ...
}:
let
  # Real hostname: host.settings.hostName overrides the flake codename.
  hostName =
    if config.host.settings.hostName != null then
      config.host.settings.hostName
    else
      config.host.settings.name;
  inherit (config.host.settings) stateVersion;
  inherit (config.host.settings) timeZone;
  inherit (config.host.settings) defaultLocale;
  inherit (config.host.settings) extraLocale;
  inherit (config.host.settings) keyboardLayout;
in
{
  # nix eval --impure --expr "builtins.substring 0 8 (builtins.hashString \"md5\" \"<hostname>\")"
  system.stateVersion = stateVersion;

  assertions = [
    {
      assertion = config.host.private.loaded;
      message = "private input is the stub; build via scripts/rebuild <host>";
    }
  ];
  networking.hostName = hostName;
  # Default ZFS hostId; hosts with their own hostname set a hardcoded
  # hostId (md5 of that hostname, first 8 chars) in their host config.
  networking.hostId = lib.mkDefault "b2c79ad7";

  # ===============================================================
  #       FUSE and SUDO
  # ===============================================================
  security.sudo = {
    extraConfig = "Defaults timestamp_timeout=15";
    wheelNeedsPassword = true;
    execWheelOnly = true;
  };

  # ===============================================================
  #       NIX CONFIGURATION
  # ===============================================================
  nix = {
    settings = {
      experimental-features = "nix-command flakes";
      auto-optimise-store = true;
      keep-outputs = true;
      trusted-users = [ "@wheel" ];
      connect-timeout = 5;
      log-lines = 25;
      min-free = 128000000;
      max-free = 1000000000;
    };
  };

  nixpkgs.config.allowUnfree = true;

  # Switch to lix
  nixpkgs.overlays = [
    (_: prev: {
      inherit (prev.lixPackageSets.stable)
        nixpkgs-review
        nix-eval-jobs
        nix-fast-build
        colmena
        ;
    })
  ];

  nix.package = pkgs.lixPackageSets.stable.lix;

  # ===============================================================
  #       PACKAGES
  # ===============================================================
  environment.systemPackages = with pkgs; [
    age
    age-plugin-fido2-hmac # sops/age unlock via Nitrokey (FIDO2 hmac-secret)
    sops
    sshfs
    man-pages
    man-pages-posix
  ];

  # ===============================================================
  #       LOCALE AND TIME
  # ===============================================================
  time = {
    inherit timeZone;
    hardwareClockInLocalTime = true;
  };

  services.timesyncd.enable = lib.mkDefault true;

  i18n = {
    inherit defaultLocale;
    extraLocaleSettings = lib.mkIf (extraLocale != null) {
      LC_ADDRESS = extraLocale;
      LC_IDENTIFICATION = extraLocale;
      LC_MEASUREMENT = extraLocale;
      LC_MONETARY = extraLocale;
      LC_NAME = extraLocale;
      LC_NUMERIC = extraLocale;
      LC_PAPER = extraLocale;
      LC_TELEPHONE = extraLocale;
      LC_TIME = extraLocale;
    };
  };

  console.keyMap = keyboardLayout;

  # ===============================================================
  #       DOCUMENTATION
  # ===============================================================
  documentation = {
    enable = true;
    dev.enable = true;
    doc.enable = false;
    info.enable = false;
    man.enable = true;
    nixos.enable = true;
  };

  users.defaultUserShell = pkgs.bash;
  programs = {
    #       SHELL CONFIGURATION
    bash = {
      completion.enable = true;
      shellAliases = {
        ls = "ls --color=auto";
        dir = "dir --color=auto";
        vdir = "vdir --color=auto";
        grep = "grep --color=auto";
        fgrep = "fgrep --color=auto";
        egrep = "egrep --color=auto";
        df = "df -h";
        du = "du -h";
        free = "free -h";
        less = "less -i";
        mkdir = "mkdir -pv";
        ping = "ping -c 3";
        ".." = "cd ..";
        osc52 = ''
          local data
          data=$(base64 -w0) # read stdin
          printf '\e]52;c;%s\a' "$data"
        '';
      };
    };

    #       GIT SYSTEM CONFIG
    git = {
      enable = true;
      lfs.enable = true;
      prompt.enable = true;
      config = {
        color.ui = true;
        grep.lineNumber = true;
        init.defaultBranch = "main";
        core = {
          autocrlf = "input";
          editor = "${pkgs.vim}/bin/vim";
        };
        diff = {
          mnemonicprefix = true;
          rename = "copy";
        };
        url = {
          "https://github.com/" = {
            insteadOf = [
              "gh:"
              "github:"
            ];
          };
        };
      };
    };
    #       FUSE (security risk)
    fuse.userAllowOther = false;
  };

  # FONTS
  fonts = {
    fontconfig.enable = true;
    enableDefaultPackages = true;
    fontDir.enable = true;

    packages = with pkgs; [
      jetbrains-mono
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      liberation_ttf
      dejavu_fonts
      font-awesome
    ];

    fontconfig = {
      defaultFonts = {
        monospace = [
          "JetBrains Mono"
          "Noto Sans Mono"
        ];
        sansSerif = [
          "Noto Sans"
          "DejaVu Sans"
        ];
        serif = [
          "Noto Serif"
          "DejaVu Serif"
        ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
  };
}
