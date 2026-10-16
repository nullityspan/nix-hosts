# sops creation rules; scripts/sops-config renders this to .sops.yaml.
# Recipients are names from keys.nix.
let
  keys = import ./keys.nix;
  age = {
    inherit (keys.humans.zen) recovery nk1 nk2;
    inherit (keys.machines) workstation research satellite;
  };
  admins = [
    "recovery"
    "nk1"
    "nk2"
  ];

  # Who installs and deploys each host. Installers can decrypt and re-key all
  # of that host's files, so installs never need an admin key.
  installers = {
    workstation = [ ];
    research = [ "workstation" ];
    satellite = [
      "workstation"
      "research"
    ];
  };

  hostRule = host: {
    path = ''nixos/hosts/${host}/((secrets|private)\.sops\.yaml|hardware\.json\.sops)$'';
    to = admins ++ [ host ] ++ installers.${host};
  };

  rules = [
    {
      path = ''secrets/common\.sops\.yaml$'';
      to = admins ++ [ "workstation" ];
    }
  ]
  ++ map hostRule (builtins.attrNames installers);

  concatMap = f: xs: builtins.concatStringsSep "" (map f xs);
  rule =
    r:
    "  - path_regex: ${r.path}\n"
    + "    key_groups:\n"
    + "      - age:\n"
    + concatMap (n: "          - ${age.${n}.age} # ${n}\n") r.to;
in
"# Generated from sops.nix by scripts/sops-config. Do not edit.\n"
+ "creation_rules:\n"
+ concatMap rule rules
