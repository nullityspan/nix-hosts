# home/work.nix — home-manager entry point for the research host.
# zen's modules minus free-time ones (creative, gaming).
# `user` is injected via home-manager.extraSpecialArgs in nixos/hosts/research/default.nix.
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
