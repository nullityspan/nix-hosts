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
- After code changes run `scripts/check`.
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

The user still has to:

- Rebuild the hosts. Until then the `templates#<name>` alias is not active, and `taplo`, `prettier`, `bash-language-server` and
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
2. Now: "Identity work" below. The design is agreed (2026-11-15); steps 1
   to 5 and 7 are done on the workstation and research; step 6 is dropped.
3. Left: rebuild satellite (login check with both tokens), then the first
   `scripts/rebuild <host> --target` deploy (step 5 is untested end to end).

## Open sections

### Host rebuild

- Workstation rebuilt and activated (user, 2026-11-15). The ambient tools
  from `tooling.nix` are on `PATH`; `hx --health` is green for nix, bash,
  json, yaml, toml and markdown.
- research: rebuilt 2026-11-20, login with both admin tokens confirmed by
  the user. satellite: not rebuilt.

### graphify

Dropped 2026-11-17: package, Nix parser patch, skill, `.graphifyignore`,
project hooks and `graphify-out/` removed. Not built on a host.

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
  inside a devShell; `zeditor ssh://zen@research/<path>`; Zed's
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

## Identity work

Design agreed by the user on 2026-11-15. Step 2 is implemented (2026-11-20,
uncommitted, no host rebuilt); the rest is not.

Problems it fixes:

- Login keys are not role-named: the old nk1/nk2 SSH public keys carry a
  personal FIDO application string and are in `authorized_keys` for `zen` and root
  on research and satellite.
- `worker` on research is in the rootful `docker` group, so it is root.
- `host.users.personas` is empty on both hosts: no managed git identity.
- `scripts/rebuild --target` copies closures as a user that is no longer
  trusted, so remote deploy does not work.

Already in the tree, do not redo: password SSH login is off globally
(`nixos/modules/core/sops.nix`); rootless docker with CDI is on for every
user (`nixos/modules/virtualisation/docker.nix`).

### Step 1: admin keys (done on workstation and research 2026-11-20; satellite left)

- User enrols a resident key with application `ssh:admin` on nk1 and nk2
  (`ssh-keygen -t ed25519-sk -O resident -O application=ssh:admin`).
- Add them to `keys.nix` as `nk1-admin` and `nk2-admin`, next to the old keys.
- `login` lists on research and satellite name only the new keys. The
  workstation keeps the old keys until step 4 is finished.
- age recipients stay; they carry no name.
- Verify: login to every host with each token before an old key is removed.

### Step 2: registry fields (done 2026-11-20)

Users stay inside `hosts.nix`; no separate user file, no general feature
flags. Three new optional fields per user, derived in
`nixos/modules/core/users.nix`:

- `personas` (list): creates `git-persona/<p>`, `.signers` and `.key` sops
  secrets from the host's `secrets.sops.yaml`, owned by that user.
- `passwordLogin` (bool): emits `Match User <name>` with
  `PasswordAuthentication yes`.
- `linger` (bool): sets `users.users.<name>.linger`, so the user's rootless
  docker daemon runs without a session.

Delete: the `host.users.personas` option (`options.nix`), the commented
persona lists in the workstation and research configs, the hand-written
`git-persona/work.key` secret and the `worker.extraGroups` line in
`nixos/hosts/research/default.nix`.

All `personas` lists stay empty in this step: a listed persona fails the
build until its sops entries exist (step 4).

Verify: `scripts/check`; evaluate the research config and read back
`services.openssh.extraConfig`, `users.users.worker.linger` and
`users.users.worker.extraGroups`. Evaluated: the `Match` block renders last
in `sshd_config`. Not checked: behaviour on a running host.

### Step 3: `worker` on research (done 2026-11-20)

- The admin user is `zen` on every host (was `moloch` on research and
  satellite). The sops key `moloch-password` must be renamed to
  `zen-password` in both files before a rebuild.
- CDI is on for the rootless daemon too (`docker.nix`).

- `hosts.nix`: `worker = { passwordLogin = true; linger = true; };`.
  fail2ban stays.
- User tests on research after a rebuild, as `worker`:
  `docker run --rm --device nvidia.com/gpu=all ubuntu nvidia-smi`.
- Checked on the workstation (2026-11-20): rootless docker with CDI runs
  `nvidia-smi` in a container, user not in the `docker` group. The user
  confirmed the same test as `worker` on research (2026-11-20).
  If it fails, `worker` stays in the `docker` group and this plan says so.

### Step 4: persona keys (done 2026-11-20; work forge key not set, forge unavailable)

- `scripts/persona <host> <persona> "<name>" "<email>"` writes the three
  sops entries and prints the public key; a key that exists in another
  host's file is reused. Run it for workstation (all three) and research
  (`work`, reuses the existing key), then fill the `personas` lists.

- One software ed25519 key per persona (names in `hosts.nix`), stored
  in the sops file of each host that uses it: workstation all three, research
  only `work`.
- Each persona's gitconfig fragment forces its own key and disables the agent
  (`IdentitiesOnly`), so a forge never sees two personas' keys in one
  connection.
- Fill the `personas` lists from step 2.
- User swaps the keys on GitHub. Then remove the old personal
  Nitrokey keys from `keys.nix` and every `login` list.
- Name, email and other PII only in encrypted values.

### Step 5: signed closures (in the tree 2026-11-20; untested end to end)

- Workstation and research each get a Nix signing key: secret in their own
  sops file, public key as `signing` in `hosts.nix`.
- Each target sets `trusted-public-keys` from the `signing` keys of its
  `managedBy` hosts.
- `scripts/rebuild --target` signs the closure before the copy and passes
  `--use-substitutes`.
- Not checked: that `nixos-rebuild --target-host` accepts signed paths from
  an untrusted user without further settings.

### Step 6: `~/.ssh/config` (dropped 2026-11-20)

The user decided the ssh client configuration is not part of this repo.
`~/.ssh/config` stays a hand-edited file.

### Step 7: README "Secrets" section (done 2026-11-20)

Including the sops edit and re-key workflow.

### Settled, do not reopen

No disk encryption; backups wait for a NAS; Nitrokeys are admin keys only;
personas stay separate, no key or name of one is used for another; research
manages satellite; no SSH CA, no `includeIf`; fail2ban stays.
