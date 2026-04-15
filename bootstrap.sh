#!/usr/bin/env bash
set -euo pipefail

# bootstrap.sh — symlink dotfiles into their expected locations
#
# Usage:
#   ./bootstrap.sh          dry run (default) - preview what would change
#   ./bootstrap.sh --apply  create/update symlinks
#   ./bootstrap.sh --help   show this help
#
# Behavior:
#   - Dry run by default. Nothing changes without --apply.
#   - Idempotent. Safe to re-run; existing correct symlinks show as OK.
#   - Backs up existing files before replacing them with symlinks.
#     Backups are saved alongside the original with a .backup.<timestamp> suffix.
#   - Creates parent directories as needed.
#   - Can be run from any directory (resolves its own location).
#
# Output states:
#   OK       symlink already points to the correct source
#   CREATE   no file at destination; symlink will be created
#   REPLACE  regular file at destination; will be backed up, then symlinked
#   RELINK   symlink exists but points elsewhere; will be updated
#   MISSING  source file not found in repo (error)
#
# Adding a new dotfile:
#   1. Add the file to the appropriate category directory (shell/, git/, etc.)
#   2. Add a "source:destination" entry to the MANIFEST array below
#   3. Run ./bootstrap.sh to verify, then ./bootstrap.sh --apply

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# --- Help ---
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  sed -n '3,/^$/{ s/^# //; s/^#//; p; }' "$0"
  exit 0
fi

# --- Symlink manifest ---
# Format: "source:destination"
# Source paths are relative to this repo root.
# Destination paths are absolute ($HOME is expanded at runtime).
MANIFEST=(
  "shell/zshrc:$HOME/.zshrc"
  "shell/zprofile:$HOME/.zprofile"
  "shell/nvmrc:$HOME/.nvmrc"
  "git/gitconfig:$HOME/.gitconfig"
  "git/ignore:$HOME/.config/git/ignore"
  "gh/config.yml:$HOME/.config/gh/config.yml"
  "scripts/git-bypass:$HOME/.local/bin/git-bypass"
  "scripts/wtdev:$HOME/.local/bin/wtdev"
)

dry_run=true
if [[ "${1:-}" == "--apply" ]]; then
  dry_run=false
fi

errors=0

for entry in "${MANIFEST[@]}"; do
  src="${DOTFILES_DIR}/${entry%%:*}"
  dest="${entry#*:}"

  if [[ ! -f "$src" ]]; then
    echo -e "${RED}MISSING${NC}  $src"
    errors=$((errors + 1))
    continue
  fi

  dest_dir="$(dirname "$dest")"

  if [[ -L "$dest" ]]; then
    current_target="$(readlink "$dest")"
    if [[ "$current_target" == "$src" ]]; then
      echo -e "${DIM}OK       $dest -> $src${NC}"
      continue
    else
      echo -e "${YELLOW}RELINK${NC}  $dest"
      echo -e "         ${DIM}current: $current_target${NC}"
      echo -e "         ${DIM}new:     $src${NC}"
    fi
  elif [[ -f "$dest" ]]; then
    echo -e "${YELLOW}REPLACE${NC} $dest ${DIM}(existing file will be backed up)${NC}"
  else
    echo -e "${GREEN}CREATE${NC}  $dest -> $src"
  fi

  if [[ "$dry_run" == true ]]; then
    continue
  fi

  # Ensure parent directory exists
  if [[ ! -d "$dest_dir" ]]; then
    mkdir -p "$dest_dir"
  fi

  # Back up existing non-symlink files
  if [[ -f "$dest" && ! -L "$dest" ]]; then
    backup="${dest}.backup.$(date +%Y%m%d%H%M%S)"
    cp "$dest" "$backup"
    echo -e "         ${DIM}backed up to: $backup${NC}"
  fi

  ln -sf "$src" "$dest"
done

echo

if [[ "$dry_run" == true ]]; then
  echo -e "${BOLD}Dry run complete.${NC} Run with ${BOLD}--apply${NC} to create symlinks."
else
  if [[ $errors -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}Done.${NC} All symlinks created."
  else
    echo -e "${YELLOW}${BOLD}Done with $errors error(s).${NC} Check missing source files above."
  fi
fi
