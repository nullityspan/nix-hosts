{ config, lib, ... }:
{

  options.host = {
    hardware = {
      hasNvidia = lib.mkOption {
        type = lib.types.bool;
        default = builtins.any (gpu: (gpu.vendor.hex or "") == "10de") (
          config.facter.report.hardware.graphics_card or [ ]
        );
      };
      hasBluetooth = lib.mkOption {
        type = lib.types.bool;
        default = builtins.length (config.facter.report.hardware.bluetooth or [ ]) > 0;
      };
    };
    settings = {
      name = lib.mkOption { type = lib.types.str; };
      # Real hostname when it differs from the flake codename in
      # host.settings.name (e.g. codename "research", hostname "REDACTED").
      hostName = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      stateVersion = lib.mkOption { type = lib.types.str; };
      timeZone = lib.mkOption { type = lib.types.str; };
      defaultLocale = lib.mkOption { type = lib.types.str; };
      extraLocale = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      keyboardLayout = lib.mkOption {
        type = lib.types.str;
        default = "us";
      };
      extraSupportedFilesystems = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
    };
    # Set by the host's private.nix; false means the stub input is active.
    private.loaded = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    users = {
      primary = lib.mkOption { type = lib.types.str; };
      # Secondary users without home-manager, resolved from users/<name>.nix.
      extra = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
    };
    partition = {
      device = lib.mkOption { type = lib.types.str; };
      persist = {
        path = lib.mkOption {
          default = "/persist";
          type = lib.types.str;
        };
        extraFiles = lib.mkOption {
          default = [ ];
          type = lib.types.listOf (lib.types.either lib.types.str lib.types.attrs);
        };
        extraDirectories = lib.mkOption {
          default = [ ];
          type = lib.types.listOf (lib.types.either lib.types.str lib.types.attrs);
        };
      };
      boot.size = lib.mkOption {
        default = "1M";
        type = lib.types.str;
      };
      esp.size = lib.mkOption {
        default = "512M";
        type = lib.types.str;
      };
      swap.size = lib.mkOption {
        default = "4G";
        type = lib.types.str;
      };
      # Partlabel already written to disk; differs per host because the
      # partition attr was renamed after some hosts were installed.
      swap.label = lib.mkOption {
        default = "disk-main-swap";
        type = lib.types.str;
      };
      root.size = lib.mkOption {
        default = "100%";
        type = lib.types.str;
      };
    };
  };
}
