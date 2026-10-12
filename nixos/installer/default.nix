# Offline bootstrap ISO: boots straight into sshd so nixos-anywhere can push a
# host closure from this machine. Target needs no internet or proxy.
{
  lib,
  modulesPath,
  ...
}:
let
  primary = import ../../users/zen.nix;
in
{
  imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix" ];

  # Installer profile keeps sshd off until started by hand.
  systemd.services.sshd.wantedBy = lib.mkForce [ "multi-user.target" ];
  services.openssh.settings = {
    PermitRootLogin = "yes";
    PasswordAuthentication = true;
  };

  users.users.root = {
    # ponytail: plaintext bootstrap password in store; image is short-lived, change it if the LAN is untrusted.
    initialHashedPassword = lib.mkForce null;
    initialPassword = "nixos";
    openssh.authorizedKeys.keys = primary.authorizedKeys;
  };

  # Host configs use ZFS (disko runs from this kernel).
  boot.supportedFilesystems.zfs = true;
  boot.zfs.forceImportRoot = false;
  networking.hostId = "8425e349";

  # Everything arrives via nix copy; never try cache.nixos.org (hangs behind proxy).
  nix.settings = {
    substituters = lib.mkForce [ ];
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  system.stateVersion = "26.05";
}
