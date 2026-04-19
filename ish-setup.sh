#!/bin/sh
# ish-setup.sh — one-shot iSH bootstrap for dev-fortress mobile access.
#
# Meant to run inside iSH Shell on iPhone. POSIX sh (Alpine BusyBox ash).
# Pairs with the rest of https://github.com/gbasran/gbas-bootstrap and the
# dev-fortress endpoint from the fsoc homelab.
#
# What this script does (idempotent; safe to re-run):
#   [1/4] apk update + add mosh tmux openssh-client ca-certificates
#   [2/4] mkdir -p ~/.ssh with 700 perms
#   [3/4] ssh-keygen a passphrased ed25519 key (interactive prompt),
#         skipped if ~/.ssh/id_dev-fortress already exists
#   [4/4] Append a `Host dev-fortress` block to ~/.ssh/config (if absent)
# Then prints the pubkey in a framed block so user can tap-copy it into
# Vaultwarden for the operator to append to dev-fortress authorized_keys.
#
# One-liner to invoke from inside iSH:
#   apk update && apk add curl ca-certificates && \
#     curl -fsSL https://raw.githubusercontent.com/gbasran/gbas-bootstrap/main/ish-setup.sh | sh

set -eu

KEY_PATH="$HOME/.ssh/id_dev-fortress"
CFG_PATH="$HOME/.ssh/config"
HOST_BLOCK_MARKER="Host dev-fortress"

say() { printf '\n=== %s ===\n' "$1"; }

say "iSH -> dev-fortress bootstrap"
printf '  target: 10.20.20.12 (dev-fortress)\n'
printf '  user:   gbas\n'
printf '  key:    %s (passphrased ed25519)\n' "$KEY_PATH"

say "[1/4] apk packages"
printf '(apk update can take several minutes on iSH x86 emulation; please be patient.)\n'
apk update
apk add mosh tmux openssh-client ca-certificates

say "[2/4] ~/.ssh directory"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

say "[3/4] ed25519 SSH key"
if [ -f "$KEY_PATH" ]; then
  printf 'key already exists at %s - skipping generation\n' "$KEY_PATH"
else
  printf 'Generating passphrased ed25519 key.\n'
  printf 'You will be prompted for a passphrase. Use 24+ chars; high entropy.\n'
  printf 'Store the passphrase in Vaultwarden as "phone-dev-fortress:ssh-key-passphrase".\n\n'
  ssh-keygen -t ed25519 \
    -C "iphone-dev-fortress-$(date +%Y%m%d)" \
    -f "$KEY_PATH"
  chmod 600 "$KEY_PATH"
fi

say "[4/4] ~/.ssh/config"
if [ -f "$CFG_PATH" ] && grep -qF "$HOST_BLOCK_MARKER" "$CFG_PATH"; then
  printf 'dev-fortress block already present in %s - leaving it alone\n' "$CFG_PATH"
else
  cat >> "$CFG_PATH" <<'EOF'

Host dev-fortress
  HostName 10.20.20.12
  User gbas
  IdentityFile ~/.ssh/id_dev-fortress
  IdentitiesOnly yes
  ServerAliveInterval 30
EOF
  printf 'wrote dev-fortress block to %s\n' "$CFG_PATH"
fi
chmod 600 "$CFG_PATH"

printf '\n\n'
printf '===============================================================\n'
printf 'DONE. Copy this pubkey into Vaultwarden as\n'
printf '  phone dev-fortress pubkey\n'
printf 'Then have the operator append it to dev-fortress authorized_keys.\n'
printf '===============================================================\n\n'
cat "$KEY_PATH.pub"
printf '\n===============================================================\n'
printf 'After the pubkey is authorized, test with:\n'
printf '  ssh dev-fortress hostname\n'
printf '  mosh dev-fortress -- tmux attach -t main\n'
printf '===============================================================\n\n'
