{ pkgs, ... }:
{
  programs = {

    bash = {
      enable = true;
      enableCompletion = true;
      shellAliases = {
        sysinfo = "inxi -Fxxxz";
        nixgen = "sudo nix-env --list-generations --profile /nix/var/nix/profiles/system";
        nixclean = "sudo nix-collect-garbage -d && nix-collect-garbage -d";
        ls = "ls --color=auto";
        grep = "grep --color=auto";
        fgrep = "fgrep --color=auto";
        egrep = "egrep --color=auto";
        df = "df -h";
        du = "du -h";
        free = "free -h";
        less = "less -i";
        mkdir = "mkdir -pv";
        ping = "ping -c 3";
        ".." = "cd ..";
      };
      bashrcExtra = ''
        export HISTSIZE=10000
        export HISTFILESIZE=20000
        export HISTCONTROL=ignoreboth:erasedups
      '';
    };

    starship = {
      enable = true;
      enableBashIntegration = true;
      settings = {
        character = {
          success_symbol = "[>](bold green)";
          error_symbol = "[x](bold red)";
          vimcmd_symbol = "[<](bold green)";
        };
        git_status = {
          ahead = ">";
          behind = "<";
          diverged = "<>";
          renamed = "r";
          deleted = "x";
        };
        directory.read_only = " ro";
        git_branch.symbol = "git ";
        nix_shell.symbol = "nix ";
        os.symbols.NixOS = "nix ";
      };
    };

    direnv = {
      enable = true;
      enableBashIntegration = true;
      nix-direnv.enable = true;
      config = {
        warn_timeout = "1h";
        load_dotenv = true;
      };
    };

    zoxide = {
      enable = true;
      enableBashIntegration = true;
    };

    zellij = {
      enable = true;
      enableBashIntegration = false;
      settings = {
        simplified_ui = true;
        show_startup_tips = false;
        copy_command = "${pkgs.wl-clipboard}/bin/wl-copy";
      };
    };
  };

  services.ssh-agent.enable = true;

  home.packages = with pkgs; [
    gh
    fd
    ripgrep
    bat
    eza
    inxi
    btop
    ncdu
  ];

  home.sessionVariables = {
    PAGER = "less";
    LESS = "-R";
  };
}
