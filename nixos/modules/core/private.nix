{ inputs, lib, ... }:
let
  # Non-secret private data, decrypted by scripts/lib/private.sh from
  # nixos/hosts/<host>/private.sops.yaml.
  file = "${inputs.private}/host.json";
  loaded = builtins.pathExists file;
in
{
  options.host.private = {
    # false means the stub input is active.
    loaded = lib.mkOption {
      type = lib.types.bool;
      default = loaded;
      readOnly = true;
    };
    host = lib.mkOption {
      type = lib.types.attrs;
      default = if loaded then lib.importJSON file else { };
    };
  };
}
