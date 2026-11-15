# Offline bootstrap ISO: boots straight into sshd so nixos-anywhere can push a
# host closure from this machine. Target needs no internet or proxy.
{
  lib,
  modulesPath,
  ...
}:
let
  keys = import ../../keys.nix;
  hosts = import ../../hosts.nix;
in
{
  imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix" ];

  # Installer profile keeps sshd off until started by hand.
  systemd.services.sshd.wantedBy = lib.mkForce [ "multi-user.target" ];
  services.openssh.settings = {
    PermitRootLogin = "yes";
    PasswordAuthentication = true;
  };

  # No password baked in: set one per install on the console (`sudo passwd`).
  users.users.root.openssh.authorizedKeys.keys = map (
    n: keys.humans.zen.${n}.ssh or hosts.${n}.ssh
  ) hosts.workstation.users.zen.login;

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
