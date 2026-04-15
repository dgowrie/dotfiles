# dotfiles

Personal dotfiles, shell configs, and scripts. Version-controlled for backup, portability, and auditability.

## Quick start

```bash
git clone git@github.com:dgowrie/dotfiles.git ~/dev/dotfiles
cd ~/dev/dotfiles
./bootstrap.sh          # dry run - preview changes
./bootstrap.sh --apply  # create symlinks
```

## Prerequisites

Install these before running the bootstrap script:

| Tool | Install | Used by |
| --- | --- | --- |
| Homebrew | [brew.sh](https://brew.sh) | Shell init, everything else |
| git | `brew install git` | Core |
| gh | `brew install gh` | git-bypass, PR workflows |
| jq | `brew install jq` | git-bypass |
| nvm | `brew install nvm` | Node version management |
| Docker Desktop | [docker.com](https://www.docker.com/products/docker-desktop/) | wtdev |

> **Future work:** Add an optional dependency installation step to bootstrap.sh (see [GNU Stow](https://www.gnu.org/software/stow/) as an alternative to the current symlink approach).

## What's tracked

### Shell

| Source | Destination | Purpose |
| --- | --- | --- |
| `shell/zshrc` | `~/.zshrc` | nvm setup, Docker completions, PATH |
| `shell/zprofile` | `~/.zprofile` | Homebrew init |
| `shell/nvmrc` | `~/.nvmrc` | Default Node version |

### Git

| Source | Destination | Purpose |
| --- | --- | --- |
| `git/gitconfig` | `~/.gitconfig` | User, signing (1Password), aliases |
| `git/ignore` | `~/.config/git/ignore` | Global gitignore |

### GitHub CLI

| Source | Destination | Purpose |
| --- | --- | --- |
| `gh/config.yml` | `~/.config/gh/config.yml` | gh preferences, aliases |

### Scripts

| Source | Destination | Purpose |
| --- | --- | --- |
| `scripts/git-bypass` | `~/.local/bin/git-bypass` | Temporarily disable GitHub branch protection rulesets for a single command (`git bypass <cmd>`) |
| `scripts/wtdev` | `~/.local/bin/wtdev` | Start local dev environments from git worktrees (Docker Compose + JS/TS dev server) |

## Not yet tracked

Configs and artifacts that exist locally but aren't in this repo yet. Review periodically to decide if they belong here.

- `~/.claude/` - Claude Code config, skills, memory (CLAUDE.md already version-controlled in [claude-workflows](https://github.com/dgowrie/claude-workflows))
- `~/.ssh/config` - SSH config (sensitive, needs scrubbing or templating)
- VS Code / Cursor settings
- Docker config

## Future work

- [ ] Optional dependency installation in bootstrap.sh
- [ ] Evaluate [GNU Stow](https://www.gnu.org/software/stow/) as symlink manager alternative
- [ ] Evaluate splitting `wtdev` into generic utilities (docker cleanup, port management, worktree resolution) and repo-specific wrappers, once a second project uses it
- [ ] Template or scrub sensitive configs (SSH) for inclusion
