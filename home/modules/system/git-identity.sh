#!/usr/bin/env bash
# git-identity: write a per-repo git identity (name, email, signing/push key)
# into .git/config. Standalone on purpose: copy to hosts outside this flake.
set -euo pipefail

usage() {
  cat <<EOF
Usage: git-identity [--name NAME] [--email EMAIL] [--key PATH|none]

Writes user.name, user.email and, with a key, ssh commit signing and
core.sshCommand into the current repo. Missing values are asked for.
--key takes a key file (private or .pub) or "none"; empty or omitted picks
interactively from ~/.ssh/*.pub and keys held by ssh-agent.
EOF
}

name="" email="" key="" key_set=0
while [ $# -gt 0 ]; do
  case "$1" in
    --name) name="$2"; shift 2 ;;
    --email) email="$2"; shift 2 ;;
    --key) key="$2"; key_set=1; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

git_dir=$(git rev-parse --absolute-git-dir)

ask() {
  local prompt=$1 current=$2 reply
  read -r -p "$prompt${current:+ [$current]}: " reply
  printf '%s' "${reply:-$current}"
}
[ -n "$name" ] || name=$(ask "Name" "$(git config --local user.name || true)")
[ -n "$email" ] || email=$(ask "Email" "$(git config --local user.email || true)")
[ -n "$name" ] && [ -n "$email" ] || { echo "name and email required" >&2; exit 1; }

# Resolve to a public key file: ssh -i and ssh-keygen -Y sign both use the
# agent when it holds the key, else fall back to the private file next to it.
pick_key() {
  local -a labels=() files=()
  local f line
  for f in "$HOME"/.ssh/*.pub; do
    [ -e "$f" ] || continue
    labels+=("$f  $(cut -d' ' -f3- "$f")"); files+=("$f")
  done
  while IFS= read -r line; do
    grep -qF " $(cut -d' ' -f2 <<<"$line")" "$HOME"/.ssh/*.pub 2>/dev/null && continue
    labels+=("agent: ${line##* }"); files+=("agent:$line")
  done < <(ssh-add -L 2>/dev/null | grep -v '^The agent has no identities' || true)
  labels+=("none (no signing)"); files+=("none")

  PS3="Key: "
  select _ in "${labels[@]}"; do
    [ -n "${REPLY//[^0-9]/}" ] && [ "$REPLY" -ge 1 ] && [ "$REPLY" -le "${#files[@]}" ] && break
  done </dev/tty >&2
  key=${files[$((REPLY - 1))]}
}

[ "$key_set" -eq 1 ] && [ -n "$key" ] || pick_key

pub=""
case "$key" in
  none) ;;
  agent:*)
    # agent-only key (e.g. forwarded): keep its public half with the repo
    pub="$git_dir/identity.pub"
    printf '%s\n' "${key#agent:}" > "$pub" ;;
  *.pub) pub=$key ;;
  *) pub="$key.pub" ;;
esac
[ -z "$pub" ] || [ -r "$pub" ] || { echo "no public key at $pub" >&2; exit 1; }

git config --local user.name "$name"
git config --local user.email "$email"
if [ -n "$pub" ]; then
  git config --local gpg.format ssh
  git config --local user.signingkey "$pub"
  git config --local commit.gpgsign true
  git config --local tag.gpgsign true
  # ssh -i loads the file as a private key: prefer the real one, else the
  # agent-only public half, which ssh still rejects unless it is 0600.
  ssh_id=${pub%.pub}
  [ -e "$ssh_id" ] || { ssh_id=$pub; chmod 600 "$ssh_id"; }
  git config --local core.sshCommand "ssh -i '$ssh_id' -o IdentitiesOnly=yes"
else
  for k in user.signingkey commit.gpgsign tag.gpgsign core.sshCommand; do
    git config --local --unset "$k" || true
  done
fi

echo "$name <$email>${pub:+ key $pub}"
