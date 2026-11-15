# Plan: development tools and environments

State at the end of 2026-11-15. Findings come from the 2026-11-14 review.
Everything below is committed (2026-11-15), including the host-registry
refactor; only the workstation has been rebuilt, and not with the latest tree.

## Ground rules

- One section at a time: change, verify, report, stop.
- Host builds need sudo to decrypt private data, so only the user runs
  `scripts/rebuild <host> build`. Plain `nixos-rebuild` fails on purpose (stub
  `private` input).
- Do not commit, stage or stash unless the user asks.
- After code changes run `scripts/check`, then `graphify update .`
  (`PYTHONHASHSEED=0 graphify update .` until the workstation is rebuilt).
- Do not write "done" for something that was not verified.

## Done, waiting for the user

Changed and checked as far as possible without sudo. `scripts/check` passes.

- **Repo devShell** (`flake.nix`): reduced to `deadnix`, `nixfmt`, `statix`,
  `shellcheck`, `shfmt`, `sops`, `ssh-to-age`, `nix-diff`, `nix-tree`. The
  `graphify` entry leaked a python3.14 `PYTHONPATH` and crashed the MCP
  servers. Confirmed fixed after `direnv reload` and a Claude Code restart
  (`nixos` and `context7` answered; `fetch` and `git` connect, not called).
- **Templates** (`templates/`): `python-fhs/.envrc` removed (direnv cannot
  enter the FHS sandbox; use interactive `nix develop`), uv guards in
  `python`, six `flake.lock` files removed, `nix.registry.templates` in
  `nixos/modules/core/common.nix`, README section.
- **Scripts** (`scripts/`): single lint path in `check`, new `shellcheck`
  flake check, `test` deleted (`scripts/rebuild <host> build` replaces it),
  `vmtest` cleanup fixed, `--inputs-from` in `facter` and `lib/private.sh`.
- **graphify wrapper** (`home/modules/dev/agents.nix`): pins
  `PYTHONHASHSEED`, so `graphify update` no longer re-executes into a Python
  without its modules.

The user still has to:

- Rebuild the hosts. Until then the `templates#<name>` alias and the graphify
  wrapper are not active, and `taplo`, `prettier`, `bash-language-server` and
  `vscode-langservers-extracted` are missing from editors in this repo.
- Run `scripts/rebuild <host> build` (covers the `private.sh` change) and
  `scripts/vmtest <host>` once.

Nobody has run: `scripts/fmt`, `scripts/facter`, `templates/python-fhs/setup`
after their edits; `direnv allow` in a freshly initialised template project;
the other templates' shells after losing their locks.

## Order of the remaining work

Set by the user on 2026-11-15:

1. Editors (`home/modules/dev/`): Helix and Zed. Code items closed
   2026-11-15; the GUI checks are left.
2. Now: personas, hosts and identities ("Identity work" below, plus the
   plan-first items: `worker` root-equivalence on research, personal key label on
   work hosts, host registry with user definitions). Design first, no edits
   before the user agrees.

## Open sections

### Host rebuild

- Workstation rebuilt and activated (user, 2026-11-15). The ambient tools
  from `tooling.nix` are on `PATH`; `hx --health` is green for nix, bash,
  json, yaml, toml and markdown.
- research and satellite: not rebuilt. They come after the identity work
  (user, 2026-11-15).

### graphify in this repo

Changed 2026-11-15. `scripts/check` passes; the package and the skill build
from `agents.nix`; not activated on a host.

- Nix parser: `home/modules/dev/graphify-nix.py`, patched into the graphify
  package by `agents.nix`, so it applies in every project. It emits file
  nodes, top-level bindings and `imports_from` edges for relative paths. The
  graph here now holds all 68 `.nix` files (464 nodes, 85 import edges).
- Until the rebuild, `graphify` on `PATH` is the unpatched build: it keeps
  the Nix nodes but does not refresh them.
- The skill now uses a pinned Python that imports graphify. Its own detection
  fell through to `pip install`. The stale `.graphify_python` is deleted.
- `.graphifyignore` excludes encrypted `*.sops.*` files, not `.sops.yaml`.
- Graph rebuilt with a Sonnet subagent on 2026-11-15: 600 nodes, 744 edges,
  27 named communities, semantic pass over `README.md`,
  `docs/remote-install.md` and `.sops.yaml`. Their semantic cache is in
  `graphify-out/cache/semantic` and matches the manifest.
- `PLAN.md` is in `.graphifyignore` since 2026-11-15: it changes every
  session, so its semantic nodes were always stale.
- After editing `graphify-nix.py`, delete `graphify-out/cache`; the cache
  does not notice an extractor change.
- A hand-done semantic extraction must stamp its nodes and edges
  `_origin: "semantic"`. The skill does this; unstamped ones are deleted
  without warning by the next `graphify update .`.
- Hooks and the `CLAUDE.md` rule stay per project (`graphify claude
  install`); `~/.claude/settings.json` is not managed by home-manager.

### Agentic tooling (`home/modules/dev/agents.nix`)

Changed 2026-11-15. `scripts/check` passes and the agent files evaluate; not
built on a host, so the running `claude` still loads the caveman plugin until
the next rebuild.

- caveman removed: flake input, lock entry and plugin. ponytail stays.
- `mattpocock-skills` removed with its `grill-me` and `grilling` skills; the
  user's own account-synced `grill-me-dialog` skill replaces them.
- MCP servers reduced to `nixos` and `context7`. `fetch` and `git` duplicated
  built-in tools.
- Model roles: daily driver opus at medium effort (set in Claude Code, not in
  Nix), `delegate-worker` on haiku, new `vision` agent on sonnet.
- Outside Nix, in `~/.claude`: the caveman rule is gone from `CLAUDE.md`; the
  `caveman-commit` and `developer-mode` skills, the caveman marketplace and
  state files, and the stale `mcpServers` entry in `settings.json` were moved
  or backed up to `~/.claude/backups/removed-2026-11-15/`.
- Still loaded and not controlled from this repo: the account-synced plugins
  and skills (tavily, pdf-viewer, office and browser skills), the claude.ai
  connectors, Claude in Chrome, the `claude-council` skill, and the
  `pyright-lsp` and `code-simplifier` plugins.
- `~/.claude/settings.json` stays unmanaged: a home-manager symlink would make
  `/config` and `/model` unable to save.
- The graphify hook guard in `.claude/settings.json` no longer runs on `Bash`
  (changed 2026-11-15); it nudged on any `grep` or `find`, also outside the
  repo. It still runs on `Grep`, `Read` and `Glob`, where it skips non-source
  files itself. `graphify claude install` would put `Bash` back.

### Editors (`home/modules/dev/`)

- VSCodium dropped 2026-11-15: `vscode.nix` deleted, `nix-vscode-extensions`
  input removed from `flake.nix` and `flake.lock`. Not built on a host. The
  old `~/.config/VSCodium` and `~/.vscode-oss` directories stay on disk.
- Changed 2026-11-15, `scripts/check` passes and the setting evaluates, not
  built on a host: Zed's `lsp.nixd.settings` reads the nixd options from
  `helix.nix`, so both editors share one definition. The rest of the Zed
  language config is Zed-specific, not a duplicate.
- Changed 2026-11-15, `scripts/check` passes, not built on a host:
  `helix.nix` no longer installs `mcp-nixos` (`agents.nix` already references
  it by store path), and the Helix JSON server command is
  `vscode-json-language-server` (the old name is not in
  `vscode-langservers-extracted`).
- Zed 1.27.0 is installed on the workstation and its extensions (`nix`,
  `zig`, `dockerfile`, `docker-compose`, `toml`) are downloaded. Still to
  check by hand in the GUI: `nixd`, `ty`/`ruff`, `vtsls`, Docker and Zig
  inside a devShell; `zeditor ssh://moloch@research/<path>`; Zed's
  self-uploaded remote server on satellite.
- `ty`, `ruff` and `vtsls` are not ambient on purpose: Python tools come from
  the project devShell, and Zed fetches `vtsls` itself with the Nix `node`.

### Python and CUDA

Rework later (user, 2026-11-15).

- `python-fhs` stays: prebuilt CUDA wheels need the FHS libraries. Its cost
  is that editors do not see the project environment.
- `programs.nix-ld` is the alternative. It only helps when Python itself is a
  prebuilt binary (uv-managed), so an ML template would drop the uv guards,
  and `/run/opengl-driver/lib` probably has to be added by hand. Not tested.

### Evaluation

- Changed 2026-11-15: unstable nixpkgs is imported once in `flake.nix` and
  passed to home-manager as `unstable` through `extraSpecialArgs`. The nine
  modules in `home/modules/dev/` and `home/modules/desktop/` take it as an
  argument. `scripts/check` passes and the workstation Helix and Zed packages
  evaluate; not built on a host.

## Identity work (from the wiped plan)

`TODO.md` no longer exists, so the remaining steps are listed here. Step 1
(`hosts.nix` registry) is in the tree, not yet built on real hosts.

1. Fresh admin credential: new resident keys (`ssh:admin`) on nk1 and nk2,
   added next to the old ones; remove the old keys only after login is
   confirmed on every host with both tokens.
2. Remote update with signed closures: one signing key per managing host,
   `trusted-public-keys` derived from `managedBy`. The current deploy path
   still depends on `trusted-users`, which was removed.
3. `worker` on research: rootless docker with GPU (CDI), password SSH login
   through a `Match User worker` block.
4. Persona software keys in sops (`git-persona/<p>`, `.signers`, `.key`);
   then re-enable the workstation personas.
5. Managed `~/.ssh/config` through home-manager with a sops-rendered include.
6. README "Secrets" section.

Settled earlier and still valid: no disk encryption; backups wait for a NAS;
Nitrokeys are admin keys only; personas stay separate, no key or name of one is used for another; research manages satellite; no SSH CA, no
`includeIf`.
