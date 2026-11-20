{
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
    ../../modules/hardware/nvidia.nix
    ../../modules/hardware/storage.nix
    ../../modules/services/fail2ban.nix
    ../../modules/services/networking.nix
    ../../modules/services/medical-imaging
    ../../modules/virtualisation/docker.nix
  ];

  host = {
    settings = {
      name = "satellite";
      stateVersion = "26.05";
      timeZone = "Europe/Berlin";
      defaultLocale = "en_US.UTF-8";
      extraLocale = "de_DE.UTF-8";
      keyboardLayout = "us";
    };
    partition = {
      device = config.host.private.host.disk; # /dev/disk/by-id path
      persist.path = "/persist";
      esp.size = "2G";
      swap.size = "64G";
    };
    hardware.hasNvidia = true;
    services.medicalImaging.enable = true;
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
  };

  environment.systemPackages = with pkgs; [
    curl
    wget
    vim
    tree
    htop
    git
  ];
}
