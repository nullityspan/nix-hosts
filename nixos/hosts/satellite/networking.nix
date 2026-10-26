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

  networking.networkmanager = {
    enable = true;
    dns = "systemd-resolved";
  };

  # Any wired en* NIC: DHCP (gateway, as on research) plus the static IP.
  networking.networkmanager.ensureProfiles.profiles.lan = lib.mkIf loaded {
    connection = {
      id = "lan";
      type = "ethernet";
      autoconnect = true;
    };
    match.interface-name = "en*";
    ipv4 = {
      method = "auto";
      address1 = "${host.address}/${toString host.prefix}";
    };
  };

  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNSSEC = "allow-downgrade";
      DNS = lib.mkIf loaded host.dns;
      Domains = lib.mkIf loaded (map (d: "~${d}") host.domains);
    };
  };

  # Installers/jump hosts; aggressive sshd jail bans them after failed key tries.
  services.fail2ban.ignoreIP = lib.mkIf loaded (host.fail2ban_ignore or [ ]);

  networking.proxy = lib.mkIf loaded {
    default = host.proxy;
    noProxy = host.no_proxy;
  };
}
