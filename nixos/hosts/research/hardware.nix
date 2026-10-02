{ inputs, ... }:
{
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
  };

  services = {
    fwupd.enable = true;
    pcscd.enable = true;
  };
}
