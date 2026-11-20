# Host registry: every host is declared once here. Pure data.
# age: host age key (sops recipient). ssh: host's own login key, if any.
# managedBy: hosts that install and deploy this one.
# signing: public Nix signing key; hosts trust the keys of their managers.
# users.<name>.login: names from keys.nix humans.zen, else hosts with `ssh`.
# users.<name>.personas: git personas; data in the host's secrets.sops.yaml.
# users.<name>.passwordLogin: allow SSH password login for this user.
# users.<name>.linger: run the user's services without a session.
{
  workstation = {
    age = "age1ust3kmy05n4z4x7f5etmctvpmv9gdy7y0mgvnyv6y9fuhm2lu5ysrasleg";
    signing = "workstation-1:lRM3HgDLnGulNIN31R4ZpE1Zlodhgg8Rk8YsIRyhZKI=";
    managedBy = [ ];
    users = {
      zen = {
        admin = true;
        home = ./home/zen.nix;
        personas = [
          "nullity"
          "real"
          "work"
        ];
        login = [
          "nk1-admin"
          "nk2-admin"
          "research"
        ];
      };
      root.login = [
        "nk1-admin"
        "nk2-admin"
      ];
    };
  };

  research = {
    age = "age1wjm0wahfyagjup8pp0trxewj29vz4s6d9ejfs5a7c6dz37fl24ashts8qg";
    # Software key living on research (not a Nitrokey).
    ssh = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICGsFa3oqBVQR8WTkEkWEp4oQvFYZgDuYTC2ZrTON/Pi research";
    signing = "research-1:xAUCECQEXCLzYNEUXGHxoGcLSzeP+yWnpO+weFKJ7YI=";
    managedBy = [ "workstation" ];
    users = {
      zen = {
        admin = true;
        home = ./home/work.nix;
        personas = [ "work" ];
        login = [
          "nk1-admin"
          "nk2-admin"
        ];
      };
      worker = {
        passwordLogin = true;
        linger = true;
      };
    };
  };

  satellite = {
    age = "age1kvmazlfyp753na53y0wafgr6keg9qv3gwr6r3qq803m60e9g6ycsg6qfux";
    managedBy = [
      "workstation"
      "research"
    ];
    users.zen = {
      admin = true;
      login = [
        "nk1-admin"
        "nk2-admin"
      ];
    };
  };
}
