# shellcheck shell=bash
# Sourced by scripts/*. Builds the `private` flake input for a host in a
# tmpfs dir and sets PRIVATE_ARGS for nix/nixos-rebuild.
#
#   nixos/hosts/<host>/private.nix.sops   tracked, sops-encrypted NixOS module
#   /persist/etc/nix-local/<host>/hardware.json   nixos-facter report, untracked

private_prepare() {
	local host=$1 repo enc hw hostkey=/etc/ssh/ssh_host_ed25519_key
	repo=$(git rev-parse --show-toplevel)
	enc="$repo/nixos/hosts/$host/private.nix.sops"
	hw="${NIX_LOCAL_DIR:-/persist/etc/nix-local}/$host/hardware.json"

	[ -f "$enc" ] || { echo "missing $enc" >&2; return 1; }
	[ -f "$hw" ] || {
		echo "missing $hw — generate it on $host: scripts/facter $host" >&2
		return 1
	}

	PRIVATE_DIR=$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/nix-private.XXXXXX")
	trap 'rm -rf "$PRIVATE_DIR"' EXIT

	# Recipients are the host key converted to X25519 (as sops-nix does), so
	# convert it too; the raw ssh-ed25519 identity would not match.
	local s2a
	s2a=$(nix build --no-link --print-out-paths nixpkgs#ssh-to-age)/bin/ssh-to-age

	# Host key only. No fallback to the caller's keys: a PGP card behind it
	# would burn PIN attempts on every failed run. Other hosts' files (remote
	# deploys) need SOPS_AGE_KEY_FILE set explicitly.
	# Redirect runs as the caller on purpose: the dir is theirs.
	# shellcheck disable=SC2024,SC2016
	if [ -n "${SOPS_AGE_KEY_FILE:-}" ]; then
		SOPS_DECRYPTION_ORDER=age sops -d --input-type binary --output-type binary "$enc" >"$PRIVATE_DIR/private.nix"
	elif ! sudo S2A="$s2a" HOSTKEY="$hostkey" ENC="$enc" bash -c \
		'SOPS_AGE_KEY=$("$S2A" -private-key -i "$HOSTKEY") SOPS_DECRYPTION_ORDER=age \
			exec sops -d --input-type binary --output-type binary "$ENC"' \
		>"$PRIVATE_DIR/private.nix"; then
		echo "cannot decrypt $enc with $hostkey (set SOPS_AGE_KEY_FILE for other hosts)" >&2
		return 1
	fi
	cp "$hw" "$PRIVATE_DIR/hardware.json"

	# shellcheck disable=SC2034 # used by the sourcing script
	PRIVATE_ARGS=(--override-input private "path:$PRIVATE_DIR" --no-write-lock-file)
}
