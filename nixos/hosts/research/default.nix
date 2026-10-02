{
  inputs,
  lib,
  pkgs,
  ...
}:
let
  # Work identity lives in private.nix.sops; no signing, no shared login keys.
  user = removeAttrs (import ../../../users/zen.nix) [ "signingKey" ] // {
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
      hostName = "REDACTED"; # real hostname — do not change
      stateVersion = "24.11";
      timeZone = "Europe/Berlin";
      defaultLocale = "en_US.UTF-8";
      extraLocale = "de_DE.UTF-8";
      keyboardLayout = "us";
    };
    users.primary = "zen";
    users.extra = [ "worker" ];
    partition = {
      device = "/dev/nvme0n1"; # 2nd NVMe disk stays unused
      persist.path = "/persist";
      # Match the partition table already on disk.
      esp.size = "2G";
      swap.size = "64G";
    };
  };

  # Hardcoded ZFS hostId for hostname REDACTED
  # (md5 of the hostname, first 8 chars).
  networking.hostId = "REDACTED";

  sops.secrets = {
    zen-password = {
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
    users.zen = import ../../../home/work.nix;
    extraSpecialArgs = { inherit inputs user; };
  };

  users.users = {
    zen = {
      uid = 1000; # previous primary uid; keeps /home ownership
      openssh.authorizedKeys.keys = lib.mkForce [ ];
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
