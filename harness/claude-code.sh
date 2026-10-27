#!/usr/bin/env bash
# Claude Code: reads personal skills from ~/.claude/skills (not ~/.agents/skills),
# and the global guide from ~/.claude/CLAUDE.md. Sourced by install.sh.
# Both live under $CLAUDE_CONFIG_DIR instead when that variable is set.

harness_claude_code() {
  say "claude-code"
  local cdir=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
  # A quoted ~ reaches us unexpanded. A relative path would depend on where the installer runs.
  case "$cdir" in
    "~") cdir=$HOME ;;
    "~/"*) cdir=$HOME/${cdir#"~/"} ;;
  esac
  case "$cdir" in
    /*) ;;
    *)
      warn "CLAUDE_CONFIG_DIR must be an absolute path, got '$cdir'. Skipped."
      return 0
      ;;
  esac
  if [ ! -d "$cdir" ]; then
    warn "$cdir not found: install and start Claude Code once, then re-run. Skipped."
    return 0
  fi

  local dir name
  for dir in "$REPO_ROOT"/skills/*/; do
    name=$(basename "$dir")
    # Same pattern as today: $cdir/skills/x -> ~/.agents/skills/x -> repo.
    # Checked against the repo, so a dry run does not depend on core having run.
    link_item "$REPO_ROOT/skills/$name" "$cdir/skills/$name" "$HOME/.agents/skills/$name"
  done

  link_item "$REPO_ROOT/global/claude/CLAUDE.md" "$cdir/CLAUDE.md"
  print_manifest claude-code
}
