_: {
  virtualisation = {
    containers.enable = true;
    oci-containers.backend = "docker";
    docker = {
      enable = true;
      enableOnBoot = false; # socket-activated on first use
      daemon.settings.features.cdi = true;
      rootless = {
        enable = true;
        setSocketVariable = true; # users are not in the docker group
        daemon.settings.features.cdi = true;
      };
      autoPrune = {
        enable = true;
        dates = "weekly";
      };
    };
  };
}
