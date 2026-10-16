let
  keys = import ../keys.nix;
in
{
  name = "moloch";
  identity = "nullityspan";
  email = "336519743+nullityspan@users.noreply.github.com";
  signingKey = "id_nullityspan_nk1"; # ~/.ssh key handle; nk2 = backup
  authorizedKeys = [
    keys.humans.zen.nk1.ssh
    keys.humans.zen.nk2.ssh
    keys.machines.research.ssh
  ];
}
