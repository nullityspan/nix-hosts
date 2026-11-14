{
  inputs,
  config,
  ...
}:
{
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  # ===============================================================
  #       SOPS Settings
  # ===============================================================
  # Host decryption key derived from the SSH host key. Per-host secrets are
  # declared under `sops.secrets` in the host module (e.g. zen-password in
  # hosts/workstation/default.nix), keyed against secrets.sops.yaml.
  sops.age.sshKeyPaths = [ "${config.host.partition.persist.path}/etc/ssh/ssh_host_ed25519_key" ];

  # ===============================================================
  #       SSH SERVER
  # ===============================================================
  host.partition.persist.extraFiles = [
    {
      file = "/etc/ssh/ssh_host_ed25519_key";
      parentDirectory.mode = "0755";
    }
    {
      file = "/etc/ssh/ssh_host_ed25519_key.pub";
      parentDirectory.mode = "0755";
    }
    {
      file = "/etc/ssh/ssh_host_rsa_key";
      parentDirectory.mode = "0755";
    }
    {
      file = "/etc/ssh/ssh_host_rsa_key.pub";
      parentDirectory.mode = "0755";
    }
  ];
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      Banner = "/etc/ssh/banner";
      MaxAuthTries = 3;
      LoginGraceTime = 30;
      AllowTcpForwarding = false;
      AllowAgentForwarding = false;
      ClientAliveInterval = 300;
      ClientAliveCountMax = 2;
    };
  };
  environment.etc."ssh/banner".text = ''
    █▄ █ █ ▀▄▀ █▀█ █▀▀
    █ ▀█ █ █ █ █▄█ ▄▄█
  '';
}
