{ config, lib, ... }:
{
  # ===============================================================
  #       FAIL2BAN
  # ===============================================================
  config = lib.mkIf config.services.openssh.enable {
    host.partition.persist.extraDirectories = [ "/var/lib/fail2ban" ];

    services.fail2ban = {
      enable = true;
      maxretry = 5;
      bantime = "1h";
      bantime-increment = {
        enable = true;
        multipliers = "1 2 4 8 16 32 64";
        maxtime = "168h";
        overalljails = true;
      };
      jails.sshd.settings = {
        mode = "aggressive";
        findtime = "10m";
      };
    };
  };
}
