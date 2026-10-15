_: {
  boot.loader = {
    systemd-boot = {
      enable = true;
      configurationLimit = 5;
      editor = false;
    };
    efi.canTouchEfiVariables = true;
  };
}
