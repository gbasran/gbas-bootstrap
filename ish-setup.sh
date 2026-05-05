#!/bin/sh
# ish-setup.sh — one-shot iSH bootstrap for fsoc mobile access.
#
# Meant to run inside iSH Shell on iPhone. POSIX sh (Alpine BusyBox ash).
# Pairs with the rest of https://github.com/gbasran/gbas-bootstrap and the
# dev-fortress + WSL endpoints from the fsoc homelab.
#
# What this script does (idempotent; safe to re-run):
#   [1/6] apk update + add mosh tmux openssh-client ca-certificates
#   [2/6] mkdir -p ~/.ssh with 700 perms
#   [3/6] ssh-keygen a passphrased ed25519 key (interactive prompt),
#         skipped if ~/.ssh/id_dev-fortress already exists
#   [4/6] Append a `Host dev-fortress` block to ~/.ssh/config (if absent)
#   [5/6] Append a `Host wsl` block to ~/.ssh/config (if absent) — uses the
#         reverse-tunnel pattern: ssh -J root@docker-services -p 2222 gbas@localhost
#         (autossh on WSL maintains the tunnel; loopback-only bind is by design)
#   [6/6] Add aliases to ~/.profile:
#           devfort   -> mosh dev-fortress -- tmux new-session -A -D -s main
#           wsl-go    -> ssh wsl -t 'tmux new-session -A -D -s main'
# Then prints the pubkey in a framed block so user can tap-copy it into
# Vaultwarden for the operator to append to dev-fortress + WSL + docker-services
# authorized_keys (one pubkey, three targets — single-key model).
#
# One-liner to invoke from inside iSH (re-runnable, fixes config drift):
#   apk update && apk add curl ca-certificates && \
#     curl -fsSL https://raw.githubusercontent.com/gbasran/gbas-bootstrap/main/ish-setup.sh | sh

set -eu

KEY_PATH="$HOME/.ssh/id_dev-fortress"
CFG_PATH="$HOME/.ssh/config"
HOST_BLOCK_MARKER="Host dev-fortress"
WSL_BLOCK_MARKER="Host wsl"

say() { printf '\n=== %s ===\n' "$1"; }

say "iSH -> fsoc bootstrap (dev-fortress + wsl)"
printf '  dev-fortress: 10.20.20.12 (gbas, mosh)\n'
printf '  wsl:          via ssh -J root@10.20.20.10 -p 2222 gbas@localhost\n'
printf '  key:          %s (passphrased ed25519, shared)\n' "$KEY_PATH"

say "[1/6] apk packages"
printf '(apk update can take several minutes on iSH x86 emulation; please be patient.)\n'
apk update
apk add mosh tmux openssh-client ca-certificates

say "[2/6] ~/.ssh directory"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"

say "[3/6] ed25519 SSH key"
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

say "[4/6] ~/.ssh/config — dev-fortress block"
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

say "[5/6] ~/.ssh/config — wsl block (reverse-tunnel via docker-services)"
if [ -f "$CFG_PATH" ] && grep -qF "$WSL_BLOCK_MARKER" "$CFG_PATH"; then
  printf 'wsl block already present in %s - leaving it alone\n' "$CFG_PATH"
else
  cat >> "$CFG_PATH" <<'EOF'

# WSL via reverse tunnel:
#   WSL runs autossh -R 2222:localhost:22 -> docker-services
#   Phone hops: WG on -> ssh -J root@10.20.20.10:22 -> tunnel listener on 127.0.0.1:2222
# If `ssh wsl` hangs or refuses, it usually means autossh on WSL is dead.
# Fix from a Windows session:  ~/fsoc/scripts/reverse-tunnel.sh
Host wsl
  HostName localhost
  Port 2222
  User gbas
  ProxyJump root@10.20.20.10:22
  IdentityFile ~/.ssh/id_dev-fortress
  IdentitiesOnly yes
  ServerAliveInterval 30
  ServerAliveCountMax 3
EOF
  printf 'wrote wsl block to %s\n' "$CFG_PATH"
fi
chmod 600 "$CFG_PATH"

say "[6/6] quick-attach aliases (~/.profile)"
PROFILE_PATH="$HOME/.profile"
DEVFORT_ALIAS="alias devfort='mosh dev-fortress -- tmux new-session -A -D -s main'"
WSL_ALIAS="alias wsl-go='ssh wsl -t \"tmux new-session -A -D -s main\"'"

if [ -f "$PROFILE_PATH" ] && grep -qF "alias devfort=" "$PROFILE_PATH"; then
  printf 'devfort alias already present - leaving it alone\n'
else
  printf '%s\n' "$DEVFORT_ALIAS" >> "$PROFILE_PATH"
  printf 'added: %s\n' "$DEVFORT_ALIAS"
fi

if [ -f "$PROFILE_PATH" ] && grep -qF "alias wsl-go=" "$PROFILE_PATH"; then
  printf 'wsl-go alias already present - leaving it alone\n'
else
  printf '%s\n' "$WSL_ALIAS" >> "$PROFILE_PATH"
  printf 'added: %s\n' "$WSL_ALIAS"
fi
printf '(type `. ~/.profile` or restart iSH to pick aliases up)\n'

printf '\n\n'
printf '===============================================================\n'
printf 'DONE. Copy this pubkey into Vaultwarden as\n'
printf '  phone fsoc pubkey  (single key, three targets)\n'
printf 'Operator appends it to authorized_keys on:\n'
printf '  - gbas@dev-fortress  (10.20.20.12)\n'
printf '  - gbas@wsl           (Windows host -> WSL gbas)\n'
printf '  - root@docker-services  (10.20.20.10, for ProxyJump)\n'
printf '===============================================================\n\n'
cat "$KEY_PATH.pub"
printf '\n===============================================================\n'
printf 'After the pubkey is authorized, test with:\n'
printf '  ssh dev-fortress hostname        # mosh path: mosh dev-fortress\n'
printf '  ssh wsl hostname                 # reverse-tunnel path\n'
printf '  devfort                          # mosh + tmux attach (dev-fortress)\n'
printf '  wsl-go                           # ssh + tmux attach (wsl)\n'
printf 'If `ssh wsl` says "connection refused" on port 2222, the autossh\n'
printf 'on WSL is dead. From a Windows session run:\n'
printf '  ~/fsoc/scripts/reverse-tunnel.sh\n'
printf '===============================================================\n\n'
