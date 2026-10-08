_: {
  # ===============================================================
  #       REMOTE DESKTOP (xrdp + XFCE)
  # ===============================================================
  services.xserver = {
    enable = true;
    desktopManager.xfce.enable = true;
  };

  services.xrdp = {
    enable = true;
    openFirewall = true; # tcp/3389
    defaultWindowManager = "xfce4-session";
    extraConfDirCommands = ''
      substituteInPlace $out/sesman.ini \
        --replace-fail "FuseMountName=thinclient_drives" \
                       "FuseMountName=/run/user/%u/thinclient_drives"
    '';
  };

  services.fail2ban.jails.xrdp = {
    filter.Definition = {
      failregex = "pam_unix\\(xrdp-sesman:auth\\): authentication failure;.* rhost=<HOST>";
      journalmatch = "_SYSTEMD_UNIT=xrdp-sesman.service";
    };
    settings = {
      enabled = true;
      port = "3389";
      backend = "systemd";
    };
  };

  security.pam.services.xrdp-sesman.text = ''
    auth     include login
    account  include login
    password include login
    session  include login
  '';
}
