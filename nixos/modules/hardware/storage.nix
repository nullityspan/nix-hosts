{
  inputs,
  config,
  ...
}:
let
  cfg = config.host.partition;

  zfs = rec {
    pool = "rpool";
    root = "local/root";
    path = "${pool}/${root}";
    blank = "${path}@blank";
    rollback = ''
      # During the post device phase the ZFS pools are not yet imported and
      # to avoid any issues with a rollback we have to manually do it. This
      # is not done automatically anymore. Some change in a NixOS version
      # bricked the direct rollback. Also, disko might not export the pools
      # properly. So we need to pre-import the pools without mounting:
      #
      # -N prevents automatic mounting (let the mount phase handle this)
      # -f forces import even if the pool wasn't cleanly exported (unsure)
      #
      if ! zpool list ${zfs.pool} > /dev/null 2>&1; then
        zpool import -N -f ${zfs.pool}
        echo "ZFS[code=$?]: imported pool ${zfs.pool}"
      else
        echo "ZFS: pool ${zfs.pool} already imported"
      fi

      zfs rollback -r ${zfs.blank}
      echo "ZFS[code=$?]: rollback of partition ${zfs.blank}"
    '';
  };

  # ===============================================================
  #       ZFS AUXILIARY
  # ===============================================================
  zpoolOptions = {
    ashift = "12";
    autotrim = "on";
  };

  rootFsOptions = {
    acltype = "posixacl";
    canmount = "off";
    dnodesize = "auto";
    normalization = "formD";
    relatime = "on";
    xattr = "sa";
    compression = "zstd";
  };

  snapshotScript = ''
    set -o errexit
    set -o nounset
    set -o pipefail

    if ! zfs list -t snapshot '${zfs.blank}' > /dev/null 2>&1; then
      echo "Creating blank snapshot: ${zfs.blank}"
      zfs snapshot "${zfs.blank}"
    else
      echo "Blank snapshot already exists: ${zfs.blank}"
    fi
  '';
in
{
  # ===============================================================
  #       IMPORTS
  # ===============================================================
  imports = [
    inputs.disko.nixosModules.disko
    inputs.impermanence.nixosModules.impermanence
  ];

  # ===============================================================
  #       ZFS SERVICES
  # ===============================================================
  services.zfs = {
    autoScrub.enable = true;
    autoSnapshot.enable = false;
    trim.enable = true;
    trim.interval = "weekly";
  };

  # ===============================================================
  #       IMPERMANENCE
  # ===============================================================
  environment.persistence."${cfg.persist.path}" = {
    enable = true;
    hideMounts = true;
    directories = config.host.partition.persist.extraDirectories ++ [
      "/var/lib/nixos"
      "/var/lib/systemd/coredump"
      "/var/log"
    ];
    files = config.host.partition.persist.extraFiles;
  };

  # ===============================================================
  #       BOOT CONFIGURATION
  # ===============================================================
  boot = {
    # ZFS rollback for impermanence (systemd initrd)
    initrd.systemd.services.zfs-rollback = {
      description = "Rollback root ZFS dataset to blank snapshot";
      wantedBy = [ "initrd.target" ];
      after = [ "zfs-import-rpool.service" ];
      before = [ "sysroot.mount" ];
      unitConfig.DefaultDependencies = "no";
      serviceConfig.Type = "oneshot";
      script = zfs.rollback;
    };
    zfs.forceImportRoot = false; # exclude risk of data loss
    tmp.cleanOnBoot = true;
    supportedFilesystems = config.host.settings.extraSupportedFilesystems ++ [
      "vfat"
      "zfs"
    ];
  };

  # Disko has no option yet to set this for zfs datasets. We can assume that
  # the persist path exists. So we are safe to do it manually.
  fileSystems."${cfg.persist.path}".neededForBoot = true;

  # ===============================================================
  #       DISKO DISK CONFIGURATION
  # ===============================================================
  disko = {
    devices = {
      # ===============================================================
      #       DISK PARTITIONING
      # ===============================================================
      disk.main = {
        imageName = "nixos-disko-root-zfs";
        imageSize = "32G";
        inherit (cfg) device;
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            # ===============================================================
            #       BIOS BOOT PARTITION
            # ===============================================================
            boot = {
              label = "BOOT";
              inherit (cfg.boot) size;
              type = "EF02"; # BIOS boot partition
            };

            # ===============================================================
            #       EFI SYSTEM PARTITION
            # ===============================================================
            esp = {
              label = "EFI";
              inherit (cfg.esp) size;
              type = "EF00"; # EFI system partition
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "umask=0077" ];
              };
            };

            # ===============================================================
            #       ENCRYPTED SWAP PARTITION
            # ===============================================================
            swap = {
              inherit (cfg.swap) size label;
              content = {
                type = "swap";
                randomEncryption = true;
                priority = 100;
              };
            };

            # ===============================================================
            #       ZFS ROOT PARTITION
            # ===============================================================
            root = {
              inherit (cfg.root) size;
              content = {
                type = "zfs";
                inherit (zfs) pool;
              };
            };
          };
        };
      };

      # ===============================================================
      #       ZFS POOL CONFIGURATION
      # ===============================================================
      zpool."${zfs.pool}" = {
        type = "zpool";
        mountpoint = "/";
        options = zpoolOptions;
        inherit rootFsOptions;
        datasets = {
          # ===============================================================
          #       LOCAL DATASETS (EPHEMERAL)
          # ===============================================================
          "local" = {
            type = "zfs_fs";
            options.mountpoint = "none";
          };

          # Root filesystem - rolled back on boot to blank snapshot
          "${zfs.root}" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/";
            postCreateHook = snapshotScript;
          };

          # Nix store - persistent across reboots
          "local/nix" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/nix";
          };

          # ===============================================================
          #       SAFE DATASETS (PERSISTENT)
          # ===============================================================
          "safe" = {
            type = "zfs_fs";
            options.mountpoint = "none";
          };

          # User home directories
          "safe/home" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = "/home";
          };

          # System persistence directory
          "safe/persist" = {
            type = "zfs_fs";
            options.mountpoint = "legacy";
            mountpoint = cfg.persist.path;
          };
        };
      };
    };
  };
}
