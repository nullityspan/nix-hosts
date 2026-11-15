# Ambient, editor-agnostic toolchain: LSPs/formatters touched in every repo.
# Per-language toolchains (python/c/rust/zig/typst/latex) live in flake
# templates and are delivered per-project via direnv.
{
  unstable,
  ...
}:
{
  home.packages = with unstable; [
    # Nix
    nixd
    nixfmt
    statix
    deadnix

    # Bash
    bash-language-server
    shfmt
    shellcheck

    # TOML
    taplo

    # JSON
    vscode-langservers-extracted
    prettier

    # YAML
    yaml-language-server

    # Markdown
    marksman

    # General
    tree-sitter
  ];
}
