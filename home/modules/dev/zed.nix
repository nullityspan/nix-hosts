# Zed: primary GUI editor. Helix remains $EDITOR for terminal and headless work.
# Language servers resolve from PATH like helix.nix: ambient tools from
# tooling.nix, per-project tools from the direnv devShell (Zed's load_direnv
# default). Zed's downloaded native binaries fail to exec on NixOS.
{
  inputs,
  pkgs,
  ...
}:
let
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
in
{
  programs.zed-editor = {
    enable = true;
    package = unstable.zed-editor;
    installRemoteServer = true;
    # npm-based servers (vtsls, Dockerfile, Compose) need a Nix-built node.
    extraPackages = [ unstable.nodejs ];
    extensions = [
      "nix"
      "zig"
      "dockerfile"
      "docker-compose"
      "toml"
    ];

    userSettings = {
      auto_update = false;
      telemetry = {
        diagnostics = false;
        metrics = false;
      };
      theme = "Ayu Dark";
      buffer_font_family = "JetBrains Mono";
      format_on_save = "on";

      languages = {
        Nix = {
          language_servers = [
            "nixd"
            "!nil"
          ];
          formatter.external.command = "nixfmt";
        };
        Python.language_servers = [
          "ty"
          "ruff"
          "!basedpyright"
          "..."
        ];
      };
    };
  };
}
