{
  pkgs,
  user,
  lib,
  ...
}:
let
  # Hardware (FIDO) keys double as commit signing keys.
  skKeys = builtins.filter (lib.hasPrefix "sk-") user.authorizedKeys;
in
{
  # No global identity: each repo gets one via `git-identity`.
  home.packages = [
    (pkgs.writeShellApplication {
      name = "git-identity";
      text = builtins.readFile ./git-identity.sh;
    })
  ];

  programs.git = {
    enable = true;
    settings.user.useConfigOnly = true;
    settings.gpg.format = "ssh";
    settings.gpg.ssh.allowedSignersFile = toString (
      builtins.toFile "allowed_signers" (
        lib.concatMapStrings (k: "${user.email} namespaces=\"git\" ${k}\n") skKeys
      )
    );
  };

  programs.gitui = {
    enable = true;
    keyConfig = ''
      (
          move_left: Some(( code: Char('h'), modifiers: "")),
          move_right: Some(( code: Char('l'), modifiers: "")),
          move_up: Some(( code: Char('k'), modifiers: "")),
          move_down: Some(( code: Char('j'), modifiers: "")),
          stash_open: Some(( code: Char('l'), modifiers: "")),
          open_help: Some(( code: F(1), modifiers: "")),
          status_reset_item: Some(( code: Char('U'), modifiers: "SHIFT")),
      )
    '';
  };

  xdg.configFile."git/ignore".text = ''
    # Editor files
    .vscode/
    .idea/
    *.swp
    *.swo
    *~

    # OS files
    .DS_Store
    Thumbs.db

    # Development environment
    .direnv/
    .envrc.local

    # Logs and temporary files
    *.log
    *.tmp
    *.temp
  '';
}
