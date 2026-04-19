# gbas-bootstrap

Fresh-host provisioner for `gbas`'s Claude Code environment. Pairs with the private dotfiles repo at `gbasran/gbasran-claude-dotfiles`.

## One-liner

```bash
curl -fsSL https://raw.githubusercontent.com/gbasran/gbas-bootstrap/main/bootstrap.sh | bash
```

On a fresh Debian-family host (Debian 12+, Ubuntu 22.04+) with user `gbas` and home `/home/gbas`, this installs `gh git curl jq ca-certificates build-essential`, then prompts for a GitHub device-flow auth in your browser, clones the private dotfiles repo into `~/.dotfiles/claude/`, and runs `install.sh` to set up the Claude Code environment (node + claude CLI + symlinks + 7-step smoke test).

Total wall-clock: ~90 seconds plus two browser clicks (GitHub + Anthropic OAuth).

## What it is NOT

- Not multi-user — hardcoded for `gbas` at `/home/gbas`. If you're looking at this: yes, this is intentional.
- Not a fresh-install tool in the distro sense — assumes apt + sudo + a working internet connection.
- Not secret-free — while `bootstrap.sh` itself has no secrets, it prompts the user to authenticate via OAuth. That auth state persists on the host per `gh` defaults (`~/.config/gh/hosts.yml`).

## Pairs with

- Private dotfiles: `gbasran/gbasran-claude-dotfiles` (requires `repo` scope to clone).
- Full architecture: described in the private repo's `README.md`, `MANIFEST.md`, and `docs/BOOTSTRAP.md`.

## Repo scope discipline

GitHub auth uses the default interactive scope set (`repo, workflow, gist, read:org`). Not narrowed to `repo` only because the operator needs `workflow` + `read:org` for routine work on their daily drivers, and every host in this ecosystem runs LUKS-encrypted + single-operator + key-authenticated. Blast-radius control is wholesale revoke on decommission via GitHub UI rather than per-token scope narrowing.
