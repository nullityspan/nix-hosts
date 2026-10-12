_: {
  virtualisation = {
    containers.enable = true;
    oci-containers.backend = "docker";
    docker = {
      enable = true;
      enableOnBoot = false; # socket-activated on first use
      daemon.settings.features.cdi = true;
      rootless.enable = true;
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };
  };
}
