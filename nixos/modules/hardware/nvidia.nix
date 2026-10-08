{ config, lib, ... }:
{
  services.xserver.videoDrivers = lib.optional config.host.hardware.hasNvidia "nvidia";

  hardware = {
    nvidia = lib.mkIf config.host.hardware.hasNvidia {
      open = true;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
      modesetting.enable = true;
    };
    nvidia-container-toolkit.enable =
      config.host.hardware.hasNvidia && config.virtualisation.docker.enable;
    nvidia-container-toolkit.mount-nvidia-executables = true;
  };
}
