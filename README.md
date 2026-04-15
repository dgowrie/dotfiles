# dotfiles

Personal dotfiles, shell configs, and scripts. Version-controlled for backup, portability, and auditability.

## Quick start

```bash
git clone git@github.com:dgowrie/dotfiles.git ~/dev/dotfiles
cd ~/dev/dotfiles
./bootstrap.sh          # dry run - preview changes
./bootstrap.sh --apply  # create symlinks
```

## How bootstrap.sh works

The bootstrap script is the central mechanism for linking repo files to their expected filesystem locations. It is also the manifest — the single source of truth for what goes where.

**Key behaviors:**

- **Dry run by default** — running without `--apply` previews all changes. Nothing is written.
- **Idempotent** — safe to re-run at any time. Correct symlinks show `OK` and are skipped.
- **Backs up before replacing** — existing regular files are copied to `<path>.backup.<timestamp>` before being replaced with a symlink.
- **Creates parent directories** — missing intermediate dirs (e.g., `~/.config/git/`) are created automatically.
- **Location-independent** — resolves its own path, so it works from any working directory.

**Output states:**

| State | Meaning |
| --- | --- |
| `OK` | Symlink already correct, no action needed |
| `CREATE` | No file at destination, symlink will be created |
| `REPLACE` | Regular file exists, will be backed up then symlinked |
| `RELINK` | Symlink exists but points elsewhere, will be updated |
| `MISSING` | Source file not found in repo (error) |

**Adding a new dotfile:**

1. Add the file to the appropriate category directory (`shell/`, `git/`, `gh/`, `scripts/`)
2. Add a `"source:destination"` entry to the `MANIFEST` array in `bootstrap.sh`
3. Run `./bootstrap.sh` to preview, then `./bootstrap.sh --apply`
4. Update the "What's tracked" tables in this README

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
