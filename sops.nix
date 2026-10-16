# sops creation rules; scripts/sops-config renders this to .sops.yaml.
# Recipients are names from keys.nix.
let
  keys = import ./keys.nix;
  age = {
    inherit (keys.humans.zen) recovery nk1 nk2;
    inherit (keys.machines) workstation research satalite;
  };
  admins = [
    "recovery"
    "nk1"
    "nk2"
  ];

  rules = [
    {
      path = ''secrets/common\.sops\.yaml$'';
      to = admins ++ [ "workstation" ];
    }
    {
      path = ''nixos/hosts/workstation/(secrets|private)\.sops\.yaml$'';
      to = admins ++ [ "workstation" ];
    }
    {
      path = ''nixos/hosts/research/((secrets|private)\.sops\.yaml|private\.nix\.sops)$'';
      to = admins ++ [ "research" ];
    }
    # research builds and deploys satalite, so it needs the private data
    # (not the runtime secrets).
    {
      path = ''nixos/hosts/satalite/private\.sops\.yaml$'';
      to = admins ++ [
        "satalite"
        "research"
      ];
    }
    {
      path = ''nixos/hosts/satalite/secrets\.sops\.yaml$'';
      to = admins ++ [ "satalite" ];
    }
  ];

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
