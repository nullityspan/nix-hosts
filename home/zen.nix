# home/zen.nix — home-manager entry point.
# `user` (identity: name, email, keys) is injected via home-manager.extraSpecialArgs in flake.nix.
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
