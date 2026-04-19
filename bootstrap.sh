#!/usr/bin/env bash
# gbas-bootstrap — provision a fresh Debian-family host with Claude Code + the
# full gbasran-claude-dotfiles environment. Two-stage:
#   [1] apt prereqs (gh, git, curl, jq, ca-certificates, build-essential)
#   [2] gh device-flow auth (default scope set) → clone the private dotfiles
#       repo → exec its install.sh
# Fresh-host one-liner:
#   curl -fsSL https://raw.githubusercontent.com/gbasran/gbas-bootstrap/main/bootstrap.sh | bash
set -euo pipefail

[[ "$(whoami)" == "gbas" ]] || { printf 'ERROR: must run as gbas (saw %s)\n' "$(whoami)" >&2; exit 1; }
[[ "$HOME" == "/home/gbas" ]] || { printf 'ERROR: HOME=%s, expected /home/gbas\n' "$HOME" >&2; exit 1; }

printf '=== [1/4] apt prereqs ===\n'
sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  gh git curl jq ca-certificates build-essential

printf '=== [2/4] GitHub auth (device flow) ===\n'
if ! gh auth status -h github.com >/dev/null 2>&1; then
  # gh's default interactive scope set is currently `repo, read:org, gist`.
  # -s workflow is ADDED on top so the token can edit .github/workflows/*.yml,
  # matching WSL's token set (repo, read:org, gist, workflow). Every host in
  # this ecosystem is LUKS-encrypted + single-operator + key-authenticated,
  # so broad scope is the operator's deliberate choice. Blast-radius control
  # is wholesale revoke via GitHub UI on decommission.
  gh auth login -h github.com -p https -w -s workflow
fi
# If this host was bootstrapped before the -s workflow change, add it now.
# Idempotent: does nothing if scope is already granted.
gh auth refresh -h github.com -s workflow 2>/dev/null || true
gh auth setup-git

printf '=== [3/4] clone private dotfiles ===\n'
mkdir -p "$HOME/.dotfiles"
if [[ -d "$HOME/.dotfiles/claude/.git" ]]; then
  printf 'dotfiles already cloned; pulling latest\n'
  git -C "$HOME/.dotfiles/claude" pull
else
  gh repo clone gbasran/gbasran-claude-dotfiles "$HOME/.dotfiles/claude"
fi

printf '=== [4/4] hand off to install.sh ===\n'
cd "$HOME/.dotfiles/claude" && bash install.sh

printf '\n=== bootstrap complete ===\n'
printf 'Next: run `claude` and complete the Anthropic device-flow login.\n'
