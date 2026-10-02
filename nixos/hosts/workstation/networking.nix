{
  lib,
  pkgs,
  inputs,
  ...
}:
{
  # ===============================================================
  #       NETWORK MANAGER
  # ===============================================================
  host.partition.persist.extraDirectories = [
    "/etc/NetworkManager/system-connections"
  ];
  networking = {
    networkmanager = {
      enable = true;
      dns = "none";
    };
    nameservers = [ "127.0.0.1" ]; # dnscrypt-proyx handles DNS
    firewall = {
      enable = true;
      allowedTCPPorts = [ ];
      allowedUDPPorts = [ ];
      # SSH allow-list: extraInputRules in private.nix.sops
    };
    dhcpcd.extraConfig = "nohook resolv.conf";
  };
  services.resolved.enable = false;
  services.openssh = {
    openFirewall = false;
    # research opens `ssh -R` into here to reach back
    settings.AllowTcpForwarding = lib.mkForce "remote";
  };

  services.dnscrypt-proxy = {
    enable = true;
    settings = {
      # ===============================================================
      #       LISTEN CONFIGURATION
      # ===============================================================
      listen_addresses = [ "127.0.0.1:53" ];
      max_clients = 250;

      # ===============================================================
      #       SERVER SELECTION
      # ===============================================================
      ipv4_servers = true;
      ipv6_servers = false;
      dnscrypt_servers = true;
      doh_servers = true;
      odoh_servers = false;

      # ===============================================================
      #       SERVER REQUIREMENTS
      # ===============================================================
      require_dnssec = false;
      require_nolog = true;
      require_nofilter = true;

      # ===============================================================
      #       SERVER SOURCES
      # ===============================================================
      sources.public-resolvers = {
        urls = [
          "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md"
          "https://download.dnscrypt.info/resolvers-list/v3/public-resolvers.md"
        ];
        cache_file = "/var/lib/dnscrypt-proxy/public-resolvers.md";
        minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";
        refresh_delay = 72;
        prefix = "";
      };

      # ===============================================================
      #       PROTOCOL SETTINGS
      # ===============================================================
      force_tcp = false;
      http3 = true;
      http3_probe = false;

      # ===============================================================
      #       PERFORMANCE TUNING
      # ===============================================================
      timeout = 5000; # [5000, 10000] in ms
      keepalive = 30; # in seconds
      lb_strategy = "wp2"; # weighted ping + latency
      lb_estimator = true;
      # timeout_load_reduction = 0.75;

      # ===============================================================
      #       CACHING
      # ===============================================================
      cache = true;
      cache_size = 4096;
      cache_min_ttl = 2400;
      cache_max_ttl = 86400;
      cache_neg_min_ttl = 60;
      cache_neg_max_ttl = 600;

      # ===============================================================
      #       BLOCKLISTS
      # ===============================================================
      blocked_names.blocked_names_file =
        let
          blocklist_base = builtins.readFile inputs.oisd;
          extraBlocklist = "";
          blocklist = pkgs.writeText "blocklist.txt" ''
            ${extraBlocklist}
            ${blocklist_base}
          '';
        in
        blocklist;
      # blocked_ips.blocked_ips_file = "/etc/dnscrypt-proxy/blocked-ips.txt";
    };

  };
}
