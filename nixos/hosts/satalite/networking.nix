_: {
  # ===============================================================
  #       CORPORATE NETWORK (static; addresses in private.nix.sops)
  # ===============================================================
  # Same setup as research so its private.nix carries over (IP + iface).
  host.partition.persist.extraDirectories = [
    "/etc/NetworkManager/system-connections"
  ];

  networking.networkmanager = {
    enable = true;
    dns = "systemd-resolved";
  };

  services.resolved = {
    enable = true;
    settings.Resolve.DNSSEC = "allow-downgrade";
  };
}
