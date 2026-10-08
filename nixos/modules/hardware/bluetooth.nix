{ config, lib, ... }:
{
  host.partition.persist.extraDirectories = lib.optionals config.host.hardware.hasBluetooth [
    "/var/lib/bluetooth"
  ];
  services.blueman.enable = config.host.hardware.hasBluetooth;
  hardware.bluetooth = {
    enable = config.host.hardware.hasBluetooth;
    powerOnBoot = true;
    settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = "true";
        KernelExperimental = "true";
      };
    };
  };
}
