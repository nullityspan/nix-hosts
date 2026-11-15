{
  lib,
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
      name = "research"; # flake codename only
      stateVersion = "24.11";
      timeZone = "Europe/Berlin";
      defaultLocale = "en_US.UTF-8";
      extraLocale = "de_DE.UTF-8";
      keyboardLayout = "us";
    };
    users.personas = [ ]; # "work" -- must be added
    partition = {
      device = config.host.private.host.disk; # /dev/disk/by-id path; 2nd NVMe disk stays unused
      persist.path = "/persist";
      # Match the partition table already on disk.
      esp.size = "2G";
      swap.size = "64G";
    };
  };

  sops.secrets = {
    moloch-password = {
      sopsFile = ./secrets.sops.yaml;
      neededForUsers = true;
    };
    root-password = {
      sopsFile = ./secrets.sops.yaml;
      neededForUsers = true;
    };
    worker-password = {
      sopsFile = ./secrets.sops.yaml;
      neededForUsers = true;
    };
    # Work persona's signing/push key: research works without the Nitrokey.
    "git-persona/work.key" = {
      sopsFile = ./secrets.sops.yaml;
      owner = "moloch";
    };
  };

  users.users = {
    moloch.uid = 1000;
    # Rootful docker until the rootless GPU test passes (PLAN.md step 4).
    worker.extraGroups = lib.optional config.virtualisation.docker.enable "docker";
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
