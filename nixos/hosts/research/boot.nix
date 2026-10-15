_: {
  boot = {
    #       BOOTLOADER
    loader = {
      systemd-boot = {
        enable = true;
        configurationLimit = 5;
        editor = false;
      };
      efi.canTouchEfiVariables = true;
    };

    #       EMULATION SUPPORT
    binfmt.emulatedSystems = [ "aarch64-linux" ];

    #       KERNEL PARAMETERS
    kernel.sysctl = {
      # TCP optimizations
      "net.ipv4.tcp_fastopen" = 3;
      "net.ipv4.tcp_syncookies" = 1;
    };
  };
}
