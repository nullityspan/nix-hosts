{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  moloch = import ../../../users/moloch.nix;
  # Work identity lives in private.nix.sops; no signing.
  user = removeAttrs moloch [ "signingKey" ] // {
    identity = "";
    email = "";
    authorizedKeys = [ ];
  };
in
{
  imports = [
    ./hardware.nix
    ./boot.nix
    ./networking.nix
    "${inputs.private}/private.nix"
    ./rdp.nix

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
    users.primary = "moloch";
    users.extra = [ "worker" ];
    partition = {
      device = "/dev/nvme0n1"; # 2nd NVMe disk stays unused
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
  };

  home-manager = {
    users.moloch = import ../../../home/work.nix;
    extraSpecialArgs = { inherit inputs user; };
  };

  users.users = {
    moloch = {
      uid = 1000;
      # Nitrokeys only; drops the research host's own key.
      openssh.authorizedKeys.keys = lib.mkForce (
        builtins.filter (lib.hasPrefix "sk-") moloch.authorizedKeys
      );
    };
    root.openssh.authorizedKeys.keys = lib.mkForce [ ];
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
