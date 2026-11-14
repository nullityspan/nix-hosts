{
  inputs,
  config,
  pkgs,
  ...
}:
{
  imports = [
    ./hardware.nix
    ./boot.nix
    ./networking.nix

    ../../modules/core
    ../../modules/hardware
    ../../modules/desktop
    ../../modules/services
    ../../modules/virtualisation
  ];

  host = {
    settings = {
      name = "workstation";
      stateVersion = "24.11";
      timeZone = "Europe/Berlin";
      defaultLocale = "en_US.UTF-8";
      extraLocale = "de_DE.UTF-8";
      keyboardLayout = "us";
    };
    users.primary = "zen";
    users.personas = [
      # "nullity"
      # "real"
      # "work"
    ];
    partition = {
      device = config.host.private.host.disk; # /dev/disk/by-id path
      persist.path = "/persist";
      # Match the partition table already on disk.
      esp.size = "2G";
      swap.size = "128M";
      swap.label = "disk-main-encryptedSwap";
    };
  };

  sops.secrets = {
    zen-password = {
      sopsFile = ./secrets.sops.yaml;
      neededForUsers = true;
    };
    root-password = {
      sopsFile = ./secrets.sops.yaml;
      neededForUsers = true;
    };
    # GitHub token for flake fetches: per-account rate limit instead of the
    # anonymous per-IP one. Workstation only: flake updates happen here.
    github-access-token.sopsFile = ./secrets.sops.yaml;
  };
  sops.templates.nix-access-tokens = {
    content = "access-tokens = github.com=${config.sops.placeholder.github-access-token}";
    group = "wheel";
    mode = "0440";
  };
  nix.extraOptions = "!include ${config.sops.templates.nix-access-tokens.path}";

  home-manager = {
    users.zen = import ../../../home/zen.nix;
    extraSpecialArgs = {
      inherit inputs;
      user = import ../../../users/zen.nix;
    };
  };

  # ===============================================================
  #       ESSENTIAL SYSTEM PACKAGES
  # ===============================================================
  environment.systemPackages = with pkgs; [
    # Core utilities
    curl
    wget
    vim
    tree
    unzip
    zip
    jq
    pciutils
    helix

    # Network diagnostics
    dnsutils
    inetutils
    mtr
    tcpdump
  ];
}
