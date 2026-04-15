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

## Symlink architecture: risks and mitigations

Symlinks are live pointers. The files your system reads (`~/.zshrc`, `~/.gitconfig`, etc.) are the files in this repo. That's the whole point — edit once, live everywhere — but it means changes to the repo affect your running system immediately.

### Failure modes

**Repo moves or is deleted.** All symlinks break instantly. Shell loses PATH additions (no brew, no nvm, no `~/.local/bin`), git loses signing config and aliases. The tools you'd normally use to fix this depend on the broken configs — a chicken-and-egg problem.

**Branch checkout / stash / reset in the primary worktree.** Symlinks point to files in the primary worktree (`~/dev/dotfiles/`). A `git checkout` that modifies a tracked file changes your live config immediately. A `git stash` mid-edit could temporarily blank a file. A `git reset --hard` reverts live configs without warning.

**Editor replaces file instead of writing in place.** Some editors and tools (vim with certain backup settings, `sed -i` on macOS) delete and recreate files rather than overwriting them. This can sever the symlink, leaving a regular file at the destination that is no longer connected to the repo.

**No atomic multi-file updates.** If you're editing related configs across multiple files, your live system sees partial state between saves.

### Mitigations

**Use git worktrees for all changes (strongest mitigation).** Worktrees check out into a separate directory. Symlinks point to the primary worktree on `main`, so stashing, deleting, or destructively editing files in a worktree has zero effect on the live symlinked configs. Changes only reach your live system when they are merged to `main` and pulled into the primary worktree — a deliberate, reviewable action. This eliminates the branch-checkout, stash, and reset failure modes entirely.

**Keep the repo on a stable path.** `~/dev/dotfiles` should never move. If it does, re-run `./bootstrap.sh --apply`.

**Branch protection enforces the PR workflow.** The `main-protection` ruleset requires PRs and blocks force pushes. Combined with worktrees, this means live config changes always go through review first.

**Don't stash in the primary worktree.** If you need to context-switch, use a worktree or commit to a branch. Never leave the primary worktree in a dirty state.

### Emergency recovery

If symlinks break and your shell is missing PATH entries, restore the critical configs using absolute paths (no dependencies on brew, nvm, or PATH):

```bash
/bin/ln -sf ~/dev/dotfiles/shell/zshrc ~/.zshrc && \
/bin/ln -sf ~/dev/dotfiles/shell/zprofile ~/.zprofile && \
/bin/ln -sf ~/dev/dotfiles/git/gitconfig ~/.gitconfig
```

Then open a new shell and run `./bootstrap.sh --apply` to restore the rest.

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
