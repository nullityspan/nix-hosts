{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  moloch = import ../../../users/moloch.nix;
in
{
  imports = [
    ./hardware.nix
    ./boot.nix
    ./networking.nix
    "${inputs.private}/private.nix"

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
      name = "satalite";
      stateVersion = "26.05";
      timeZone = "Europe/Berlin";
      defaultLocale = "en_US.UTF-8";
      extraLocale = "de_DE.UTF-8";
      keyboardLayout = "us";
    };
    users.primary = "moloch";
    partition = {
      device = "/dev/nvme0n1";
      persist.path = "/persist";
      esp.size = "2G";
      swap.size = "64G";
    };
    hardware.hasNvidia = true;
    services.medicalImaging.enable = true;
  };

  # md5 of "satalite", first 8 chars.
  networking.hostId = "d6b8caad";

  sops.secrets = {
    moloch-password = {
      sopsFile = ./secrets.sops.yaml;
      neededForUsers = true;
    };
    root-password = {
      sopsFile = ./secrets.sops.yaml;
      neededForUsers = true;
    };
  };

  users.users = {
    moloch.openssh.authorizedKeys.keys = lib.mkForce (
      builtins.filter (lib.hasPrefix "sk-") moloch.authorizedKeys
    );
    root.openssh.authorizedKeys.keys = lib.mkForce [ ];
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
