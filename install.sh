#!/usr/bin/env bash
# Symlinks this repo's skills and rules into ~/.claude.
# A file or directory already at a link path is moved to ~/.claude-backup/<timestamp>/ first.
set -euo pipefail

repo="$(cd "$(dirname "$0")" && pwd)"
skill="$repo/skills/claude-dev-pipeline"
backup="$HOME/.claude-backup/$(date +%Y%m%d-%H%M%S)"

link() {
  local target="$1" path="$2"
  mkdir -p "$(dirname "$path")"
  if [[ -e "$path" && ! -L "$path" ]]; then
    mkdir -p "$backup"
    mv "$path" "$backup/"
    echo "moved $path to $backup/"
  fi
  ln -sfn "$target" "$path"
  echo "$path -> $target"
}

link "$skill" "$HOME/.claude/skills/claude-dev-pipeline"
link "$skill/prime-directives.md" "$HOME/.claude/rules/prime-directives.md"
link "$skill/lean-plans-delegation-pipeline.md" "$HOME/.claude/rules/lean-plans-delegation-pipeline.md"
