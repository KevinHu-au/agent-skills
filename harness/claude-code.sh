#!/usr/bin/env bash
# Claude Code: reads personal skills from ~/.claude/skills (not ~/.agents/skills),
# and the global guide from ~/.claude/CLAUDE.md. Sourced by install.sh.

harness_claude_code() {
  say "claude-code"
  if [ ! -d "$HOME/.claude" ]; then
    warn "$HOME/.claude not found: install and start Claude Code once, then re-run. Skipped."
    return 0
  fi

  local dir name
  for dir in "$REPO_ROOT"/skills/*/; do
    name=$(basename "$dir")
    # Same pattern as today: ~/.claude/skills/x -> ~/.agents/skills/x -> repo.
    # Checked against the repo, so a dry run does not depend on core having run.
    link_item "$REPO_ROOT/skills/$name" "$HOME/.claude/skills/$name" "$HOME/.agents/skills/$name"
  done

  link_item "$REPO_ROOT/global/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
  print_manifest claude-code
}
