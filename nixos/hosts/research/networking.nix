{ lib, ... }:
{
  # ===============================================================
  #       CORPORATE NETWORK (static; addresses in private.nix.sops)
  # ===============================================================
  host.partition.persist.extraDirectories = [
    "/etc/NetworkManager/system-connections"
  ];

  networking = {
    networkmanager = {
      enable = true;
      dns = "systemd-resolved";
    };
    firewall = {
      allowedTCPPorts = [ 11112 ];
      allowedUDPPorts = [ ];
    };
  };

  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNSSEC = "allow-downgrade";
    };
  };

  # No SSH keys enrolled yet — keep password logins (overrides the
  # hardened defaults in core/sops.nix).
  services.openssh.settings = {
    PasswordAuthentication = lib.mkForce true;
    PermitRootLogin = lib.mkForce "no";
  };
}
