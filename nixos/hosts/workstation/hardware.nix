{
  inputs,
  pkgs,
  ...
}:
{
  # ===============================================================
  #       Add long living media storage
  # ===============================================================
  # boot.zfs.extraPools = [ "tank" ];

  fileSystems = {
    "/tank/documents" = {
      device = "tank/documents";
      fsType = "zfs";
    };
    "/tank/inbox" = {
      device = "tank/inbox";
      fsType = "zfs";
    };
    "/tank/photos" = {
      device = "tank/photos";
      fsType = "zfs";
    };
    "/tank/videos" = {
      device = "tank/videos";
      fsType = "zfs";
    };
  };

  # ===============================================================
  #       NIXOS-FACTER INTEGRATION
  # ===============================================================
  imports = [
    inputs.nixos-facter-modules.nixosModules.facter
  ];

  # Generated per host by nixos-facter; not tracked (see scripts/rebuild).
  facter.reportPath =
    let
      report = "${inputs.private}/hardware.json";
    in
    if builtins.pathExists report then report else null;

  # ===============================================================
  #       HARDWARE SUPPORT
  # ===============================================================
  hardware = {
    enableRedistributableFirmware = true;
    graphics.enable = true;
    nitrokey.enable = true;
  };

  services = {
    fwupd.enable = true;
    pcscd.enable = true;
  };

  environment.systemPackages =
    let
      pynitrokey-with-pcsc = pkgs.python3Packages.pynitrokey.overridePythonAttrs (old: {
        dependencies = old.dependencies ++ old.optional-dependencies.pcsc;
      });
    in
    with pkgs;
    [
      ccid
      swaylock-effects
      libfido2
      pynitrokey-with-pcsc
    ];
}
