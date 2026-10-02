{
  inputs,
  config,
  lib,
  ...
}:
let
  primary = import "${inputs.self}/users/${config.host.users.primary}.nix";
  extras = map (n: import "${inputs.self}/users/${n}.nix") config.host.users.extra;

  checkGroups = groups: builtins.filter (g: builtins.hasAttr g config.users.groups) groups;

  # Hashes live in the host's sops file as `<user>-password`.
  passwordOf = name: { hashedPasswordFile = config.sops.secrets."${name}-password".path; };

  homeRules = user: [
    "d /home/${user.name} 0700 ${user.name} users -"
    "d /home/${user.name}/.ssh 0700 ${user.name} users -"
    "d /home/${user.name}/.ssh/sockets 0700 ${user.name} users -"
  ];

  mkExtraUser = user: {
    isNormalUser = true;
    description = user.identity;
    openssh.authorizedKeys.keys = user.authorizedKeys;
    extraGroups = [
      "networkmanager"
    ]
    ++ checkGroups [
      "docker"
      "libvirtd"
      "kvm"
    ];
  };
in
{
  # Ensure home directories exist
  systemd.tmpfiles.rules = lib.concatMap homeRules ([ primary ] ++ extras);

  # sops is the only password source; `switch` applies changes.
  users.mutableUsers = false;

  users.users =
    builtins.listToAttrs (
      map (user: {
        inherit (user) name;
        value = mkExtraUser user // passwordOf user.name;
      }) extras
    )
    // {
      # Create primary user account
      ${primary.name} = {
        isNormalUser = true;
        description = primary.identity;
        openssh.authorizedKeys.keys = primary.authorizedKeys;
        extraGroups = [
          "wheel"
          "networkmanager"
        ]
        ++ checkGroups [
          "audio"
          "video"
          "docker"
          "libvirtd"
          "scanner"
          "lp"
          "kvm"
          "wireshark"
        ];
      }
      // passwordOf primary.name;

      # Root: own emergency password, only primary's hardware (FIDO) SSH keys
      root = {
        openssh.authorizedKeys.keys = builtins.filter (lib.hasPrefix "sk-") primary.authorizedKeys;
      }
      // passwordOf "root";
    };
}
