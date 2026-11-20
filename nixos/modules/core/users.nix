{
  config,
  lib,
  ...
}:
let
  hosts = import ../../../hosts.nix;
  keys = import ../../../keys.nix;
  hostUsers = hosts.${config.host.settings.name}.users;
  people = removeAttrs hostUsers [ "root" ];
  withHome = lib.filterAttrs (_: u: u ? home) people;

  # A login name is a human key from keys.nix, else a host's own key.
  loginKeys = u: map (n: keys.humans.zen.${n}.ssh or hosts.${n}.ssh) (u.login or [ ]);

  checkGroups = groups: builtins.filter (g: builtins.hasAttr g config.users.groups) groups;

  # Hashes live in the host's sops file as `<user>-password`.
  passwordOf = name: { hashedPasswordFile = config.sops.secrets."${name}-password".path; };

  homeRules = name: [
    "d /home/${name} 0700 ${name} users -"
    "d /home/${name}/.ssh 0700 ${name} users -"
    "d /home/${name}/.ssh/sockets 0700 ${name} users -"
  ];

  adminGroups = [
    "wheel"
    "networkmanager"
  ]
  ++ checkGroups [
    "audio"
    "video"
    "libvirtd"
    "scanner"
    "lp"
    "kvm"
    "wireshark"
  ];

  mkUser =
    name: u:
    {
      isNormalUser = true;
      openssh.authorizedKeys.keys = loginKeys u;
      extraGroups = lib.optionals (u.admin or false) adminGroups;
      # Keeps the user's rootless docker daemon running without a session.
      linger = u.linger or false;
    }
    // passwordOf name;

  # Git persona fragments for `git-identity <persona>`: a gitconfig include,
  # its allowed_signers file and its key. PII stays out of the store.
  personaSecrets =
    name: u:
    lib.genAttrs
      (lib.concatMap (p: [
        "git-persona/${p}"
        "git-persona/${p}.signers"
        "git-persona/${p}.key"
      ]) (u.personas or [ ]))
      (_: {
        sopsFile = ../../hosts + "/${config.host.settings.name}/secrets.sops.yaml";
        owner = name;
      });
in
{
  # Ensure home directories exist
  systemd.tmpfiles.rules = lib.concatMap homeRules (builtins.attrNames people);

  sops.secrets = lib.concatMapAttrs personaSecrets people;

  # Match blocks must come last in sshd_config.
  services.openssh.extraConfig = lib.mkAfter (
    lib.concatMapStrings (n: "Match User ${n}\n  PasswordAuthentication yes\n") (
      builtins.attrNames (lib.filterAttrs (_: u: u.passwordLogin or false) people)
    )
  );

  # sops is the only password source; `switch` applies changes.
  users.mutableUsers = false;

  users.users = lib.mapAttrs mkUser people // {
    root = {
      openssh.authorizedKeys.keys = loginKeys (hostUsers.root or { });
    }
    // passwordOf "root";
  };

  home-manager.users = lib.mapAttrs (name: u: {
    imports = [ u.home ];
    _module.args.user = { inherit name; };
  }) withHome;
}
