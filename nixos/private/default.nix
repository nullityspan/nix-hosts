# Only module that reads the `private` flake input; hosts consume
# config.host.private instead.
{ inputs, lib, ... }:
let
  # Non-secret private data, decrypted by scripts/lib/private.sh from
  # nixos/hosts/<host>/private.sops.yaml.
  file = "${inputs.private}/host.json";
  loaded = builtins.pathExists file;
  # Generated per host by nixos-facter; not tracked (see scripts/rebuild).
  report = "${inputs.private}/hardware.json";
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

  config.facter.reportPath = if builtins.pathExists report then report else null;
}
