# Helix editor: settings + language configuration.
# LSP/formatter commands are bare names resolved from PATH: ambient tools from
# the global home profile (see tooling.nix), per-project tools from the direnv
# devShell. Language entries for non-ambient toolchains (rust/zig/typst/latex)
# are kept so editing works once a project devShell provides the tool.
{
  inputs,
  osConfig,
  pkgs,
  ...
}:
let
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };
  nixpkgsChannel = osConfig.system.nixos.release;
in
{
  home.packages = [ pkgs.mcp-nixos ];

  programs.helix = {
    enable = true;
    package = unstable.helix;
    defaultEditor = true;
    settings = {
      theme = "ayu_dark";
      editor = {
        line-number = "absolute";
        true-color = true;
        rulers = [
          80
          120
        ];
        color-modes = true;
        end-of-line-diagnostics = "hint";
        auto-pairs = true;
        auto-completion = true;
        auto-format = true;

        indent-guides = {
          render = true;
          character = "|";
        };

        cursor-shape = {
          insert = "bar";
          normal = "block";
          select = "underline";
        };

        search = {
          smart-case = true;
          wrap-around = true;
        };

        file-picker = {
          hidden = false;
          follow-symlinks = true;
          git-ignore = true;
        };

        statusline = {
          left = [
            "mode"
            "spinner"
            "file-name"
            "file-modification-indicator"
          ];
          right = [
            "diagnostics"
            "selections"
            "position"
            "file-encoding"
          ];
        };

        lsp = {
          display-messages = true;
          display-inlay-hints = true;
        };
      };
    };

    languages = {
      language-server = {
        nixd = {
          command = "nixd";
          config.nixd = {
            nixpkgs.expr = ''
              import (builtins.getFlake "github:NixOS/nixpkgs/nixos-${nixpkgsChannel}") { system = "x86_64-linux"; }
            '';
            options = {
              nixos.expr = ''
                let
                  nixpkgs = builtins.getFlake "github:NixOS/nixpkgs/nixos-${nixpkgsChannel}";
                in (nixpkgs.lib.nixosSystem {
                  system = "x86_64-linux";
                  modules = [
                    (builtins.getFlake "github:Mic92/sops-nix").nixosModules.sops
                    (builtins.getFlake "github:nix-community/impermanence").nixosModules.impermanence
                    (builtins.getFlake "github:nix-community/disko").nixosModules.disko
                    (builtins.getFlake "github:numtide/nixos-facter-modules").nixosModules.facter
                  ];
                }).options
              '';
              home-manager.expr = ''
                let
                  hm = builtins.getFlake "github:nix-community/home-manager";
                  nixpkgs = builtins.getFlake "github:NixOS/nixpkgs/nixos-${nixpkgsChannel}";
                in (hm.lib.homeManagerConfiguration {
                  pkgs = import nixpkgs { system = "x86_64-linux"; };
                  modules = [{
                    home.stateVersion = "24.11";
                    home.username = "dummy";
                    home.homeDirectory = "/home/dummy";
                  }];
                }).options
              '';
            };
          };
        };

        bash-language-server = {
          command = "bash-language-server";
          args = [ "start" ];
        };
        ty = {
          command = "ty";
          args = [ "server" ];
        };
        ruff = {
          command = "ruff";
          args = [ "server" ];
        };
        zls = {
          command = "zls";
        };
        clangd = {
          command = "clangd";
          args = [
            "--background-index"
            "--clang-tidy"
            "--completion-style=detailed"
            "--header-insertion=iwyu"
          ];
        };
        rust-analyzer = {
          command = "rust-analyzer";
        };
        taplo = {
          command = "taplo";
          args = [
            "lsp"
            "stdio"
          ];
        };
        vscode-json-languageserver = {
          command = "vscode-json-languageserver";
          args = [ "--stdio" ];
        };
        yaml-language-server = {
          command = "yaml-language-server";
          args = [ "--stdio" ];
        };
        marksman = {
          command = "marksman";
          args = [ "server" ];
        };
        tinymist = {
          command = "tinymist";
        };
        texlab = {
          command = "texlab";
        };
      };

      language = [
        {
          name = "nix";
          auto-format = true;
          language-servers = [ "nixd" ];
          formatter.command = "nixfmt";
        }
        {
          name = "bash";
          auto-format = true;
          language-servers = [ "bash-language-server" ];
          formatter = {
            command = "shfmt";
            args = [
              "-i"
              "2"
              "-ci"
              "-bn"
            ];
          };
        }
        {
          name = "python";
          auto-format = true;
          language-servers = [
            "ty"
            "ruff"
          ];
          formatter = {
            command = "ruff";
            args = [
              "format"
              "-"
            ];
          };
        }
        {
          name = "zig";
          auto-format = true;
          language-servers = [ "zls" ];
          formatter = {
            command = "zig";
            args = [
              "fmt"
              "--stdin"
            ];
          };
        }
        {
          name = "c";
          auto-format = true;
          language-servers = [ "clangd" ];
          formatter = {
            command = "clang-format";
            args = [
              "--style=file"
              "--fallback-style=LLVM"
            ];
          };
        }
        {
          name = "cpp";
          auto-format = true;
          language-servers = [ "clangd" ];
          formatter = {
            command = "clang-format";
            args = [
              "--style=file"
              "--fallback-style=LLVM"
            ];
          };
        }
        {
          name = "rust";
          auto-format = true;
          language-servers = [ "rust-analyzer" ];
          formatter = {
            command = "rustfmt";
            args = [
              "--edition"
              "2021"
            ];
          };
        }
        {
          name = "toml";
          auto-format = true;
          language-servers = [ "taplo" ];
          formatter = {
            command = "taplo";
            args = [
              "fmt"
              "-"
            ];
          };
        }
        {
          name = "json";
          auto-format = true;
          language-servers = [ "vscode-json-languageserver" ];
          formatter = {
            command = "prettier";
            args = [
              "--parser"
              "json"
            ];
          };
        }
        {
          name = "yaml";
          auto-format = true;
          language-servers = [ "yaml-language-server" ];
          formatter = {
            command = "prettier";
            args = [
              "--parser"
              "yaml"
            ];
          };
        }
        {
          name = "markdown";
          auto-format = true;
          language-servers = [ "marksman" ];
          formatter = {
            command = "prettier";
            args = [
              "--parser"
              "markdown"
              "--prose-wrap"
              "always"
            ];
          };
        }
        {
          name = "typst";
          auto-format = true;
          language-servers = [ "tinymist" ];
          formatter = {
            command = "typstyle";
            args = [ "--stdout" ];
          };
        }
        {
          name = "latex";
          auto-format = true;
          language-servers = [ "texlab" ];
        }
        {
          name = "bibtex";
          auto-format = true;
          language-servers = [ "texlab" ];
        }
        {
          name = "sql";
          auto-format = true;
          formatter = {
            command = "pg_format";
            args = [
              "--keyword-case"
              "2"
              "--type-case"
              "2"
            ];
          };
        }
      ];
    };
  };

  xdg.configFile."helix/ignore".text = ''
    .git/
    node_modules/
    target/
    .direnv/
    result
    result-*
    *.tmp
    *.log
    __pycache__/
    *.pyc
    .zig-cache/
    zig-out/
    build/
    _minted-*/
    *.aux
    *.fls
    *.fdb_latexmk
    *.bbl
    *.blg
    *.toc
    *.out
  '';
}
