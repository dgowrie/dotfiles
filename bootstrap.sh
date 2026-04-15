#!/usr/bin/env bash
set -euo pipefail

# bootstrap.sh — symlink dotfiles into their expected locations
#
# Run from the dotfiles repo root:
#   ./bootstrap.sh          # preview what will happen (dry run)
#   ./bootstrap.sh --apply  # create symlinks

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# --- Symlink manifest ---
# Format: "source:destination"
# Source paths are relative to this repo root.
# Destination paths use ~ (expanded at runtime).
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
