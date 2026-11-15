# Host registry: every host is declared once here. Pure data.
# age: host age key (sops recipient). ssh: host's own login key, if any.
# managedBy: hosts that install and deploy this one.
# users.<name>.login: names from keys.nix humans.zen, else hosts with `ssh`.
{
  workstation = {
    age = "age1ust3kmy05n4z4x7f5etmctvpmv9gdy7y0mgvnyv6y9fuhm2lu5ysrasleg";
    managedBy = [ ];
    users = {
      zen = {
        admin = true;
        home = ./home/zen.nix;
        login = [
          "nk1"
          "nk2"
          "research"
        ];
      };
      root.login = [
        "nk1"
        "nk2"
      ];
    };
  };

  research = {
    age = "age1wjm0wahfyagjup8pp0trxewj29vz4s6d9ejfs5a7c6dz37fl24ashts8qg";
    # Software key living on research (not a Nitrokey).
    ssh = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICGsFa3oqBVQR8WTkEkWEp4oQvFYZgDuYTC2ZrTON/Pi research";
    managedBy = [ "workstation" ];
    users = {
      moloch = {
        admin = true;
        home = ./home/work.nix;
        login = [
          "nk1"
          "nk2"
        ];
      };
      worker = { };
    };
  };

  satellite = {
    age = "age1kvmazlfyp753na53y0wafgr6keg9qv3gwr6r3qq803m60e9g6ycsg6qfux";
    managedBy = [
      "workstation"
      "research"
    ];
    users.moloch = {
      admin = true;
      login = [
        "nk1"
        "nk2"
      ];
    };
  };
}
