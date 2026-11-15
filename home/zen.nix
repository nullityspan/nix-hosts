# home/zen.nix — home-manager entry point.
# `user` ({ name }) is injected from hosts.nix by nixos/modules/core/users.nix.
{ user, ... }:
{
  imports = [
    ./modules/dev
    ./modules/desktop
    ./modules/system
  ];

  home = {
    username = user.name;
    homeDirectory = "/home/${user.name}";
    stateVersion = "24.11";
  };

  nixpkgs.config.allowUnfree = true;
  programs.home-manager.enable = true;
}
