# home/work.nix — home-manager entry point for the research host.
# moloch's modules minus free-time ones (creative, gaming).
# `user` ({ name }) is injected from hosts.nix by nixos/modules/core/users.nix.
{ user, ... }:
{
  imports = [
    ./modules/dev
    ./modules/system
    ./modules/desktop/wayland.nix
    ./modules/desktop/theming.nix
    ./modules/desktop/applications.nix
  ];

  home = {
    username = user.name;
    homeDirectory = "/home/${user.name}";
    stateVersion = "24.11";
  };

  nixpkgs.config.allowUnfree = true;
  programs.home-manager.enable = true;
}
