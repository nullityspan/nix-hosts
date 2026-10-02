{
  config,
  lib,
  ...
}:
{
  virtualisation.vmVariantWithDisko = {
    host.hardware.hasNvidia = false;
    host.hardware.hasBluetooth = false;
    services.desktopManager.cosmic.enable = config.programs.sway.enable or false;

    virtualisation = {
      fileSystems."${config.host.partition.persist.path}".neededForBoot = true;
      memorySize = 8192;
      cores = 4;
      forwardPorts = [
        {
          from = "host";
          host.port = 8888;
          guest.port = 80;
        }
        {
          from = "host";
          host.port = 2222;
          guest.port = 22;
        }
      ];
    };

    facter.reportPath = lib.mkForce null;
  };
}
