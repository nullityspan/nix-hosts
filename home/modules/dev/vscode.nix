# VSCodium: declarative extensions (Open VSX via nix-vscode-extensions) and
# settings. Per-project language servers come from the project devShell: the
# direnv extension loads .envrc so the editor + integrated terminal inherit the
# devShell PATH, and the LSP extensions call those project binaries.
{
  inputs,
  pkgs,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
  ext = inputs.nix-vscode-extensions.extensions.${system}.open-vsx;
in
{
  # programs.vscodium (not programs.vscode) so config is written to VSCodium's
  # own paths (~/.config/VSCodium, ~/.vscode-oss) rather than VS Code's.
  programs.vscodium = {
    enable = true;
    # profiles is mutually exclusive with mutableExtensionsDir, so using it
    # makes the declared extension set authoritative (fully declarative).
    profiles.default = {
      extensions = [
        ext.llvm-vs-code-extensions.vscode-clangd
        # MIT base extension (no Pylance); ruff + ty depend on it for activation.
        ext.ms-python.python
        ext.charliermarsh.ruff
        ext.astral-sh.ty
        ext.tamasfe.even-better-toml
        ext.jnoortheen.nix-ide
        ext.mkhl.direnv
        ext.esbenp.prettier-vscode
      ];

      userSettings = {
        "editor.formatOnSave" = true;
        "telemetry.telemetryLevel" = "off";
        "workbench.sideBar.location" = "right";

        # direnv: load the project devShell so LSP extensions find their tools.
        "direnv.restart.automatic" = true;

        # Nix
        "nix.enableLanguageServer" = true;
        "nix.serverPath" = "nixd";
        "nix.formatterPath" = "nixfmt";
        "[nix]" = {
          "editor.defaultFormatter" = "jnoortheen.nix-ide";
        };

        # Python: ruff for formatting, ty for type analysis. Disable the
        # ms-python base extension's own language server (Pylance/Jedi) so ty
        # owns type checking.
        "python.languageServer" = "None";
        # Use the ty/ruff binaries from the project devShell (direnv PATH), not
        # the extensions' bundled binaries — those are prebuilt and fail to exec
        # on NixOS (the bundled-binary spawn dies → EPIPE / stream-destroyed on
        # the language-server pipe). importStrategy=fromEnvironment is already
        # the default and resolves adjacent to the Python interpreter, which is
        # not where direnv puts ty/ruff; an explicit bare-name path forces a
        # plain PATH lookup so the devShell binaries are used.
        "ty.path" = [ "ty" ];
        "ty.importStrategy" = "fromEnvironment";
        "ruff.path" = [ "ruff" ];
        "ruff.importStrategy" = "fromEnvironment";
        "ruff.nativeServer" = true;
        "[python]" = {
          "editor.defaultFormatter" = "charliermarsh.ruff";
        };

        # Prettier for the web/markup ambient set.
        "[json]" = {
          "editor.defaultFormatter" = "esbenp.prettier-vscode";
        };
        "[jsonc]" = {
          "editor.defaultFormatter" = "esbenp.prettier-vscode";
        };
        "[yaml]" = {
          "editor.defaultFormatter" = "esbenp.prettier-vscode";
        };
        "[markdown]" = {
          "editor.defaultFormatter" = "esbenp.prettier-vscode";
        };

        # TOML
        "[toml]" = {
          "editor.defaultFormatter" = "tamasfe.even-better-toml";
        };
      };
    };
  };
}
