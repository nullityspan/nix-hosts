{ config, lib, ... }:
let
  inherit (config.host.private) host loaded;
in
{
  # ===============================================================
  #       CORPORATE NETWORK (static; addresses in private.sops.yaml)
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

  networking.interfaces = lib.mkIf loaded {
    ${host.iface}.ipv4.addresses = [
      {
        inherit (host) address;
        prefixLength = host.prefix;
      }
    ];
  };

  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNSSEC = "allow-downgrade";
      DNS = lib.mkIf loaded host.dns;
      Domains = lib.mkIf loaded (map (d: "~${d}") host.domains);
    };
  };

  networking.proxy = lib.mkIf loaded {
    default = host.proxy;
    noProxy = host.no_proxy;
  };

  # No SSH keys enrolled yet — keep password logins (overrides the
  # hardened defaults in core/sops.nix).
  services.openssh.settings = {
    PasswordAuthentication = lib.mkForce true;
    PermitRootLogin = lib.mkForce "no";
    AllowTcpForwarding = lib.mkForce "local";
    AllowAgentForwarding = lib.mkForce true;
  };
}
