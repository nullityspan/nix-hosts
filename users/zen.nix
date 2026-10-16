let
  keys = import ../keys.nix;
in
{
  name = "zen";
  identity = "nullityspan";
  email = "336519743+nullityspan@users.noreply.github.com";
  authorizedKeys = [
    keys.humans.zen.nk1.ssh
    keys.humans.zen.nk2.ssh
    keys.machines.research.ssh
  ];
}
