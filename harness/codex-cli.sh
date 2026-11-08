#!/usr/bin/env bash
# OpenAI Codex CLI: reads personal skills from ~/.agents/skills, so no skills link is needed here.
# Codex cannot attach a hook to a skill, so it gets the shell hook in ~/.codex/hooks.json. The hook stays
# dormant until an agentd skill starts in the session. Sourced by install.sh.

harness_codex_cli() {
  say "codex-cli"
  if [ ! -d "$HOME/.codex" ]; then
    warn "$HOME/.codex not found: install and start Codex once, then re-run. Skipped."
    return 0
  fi
  command -v jq >/dev/null 2>&1 || warn "jq not found: block-dangerous-shell.sh needs it (brew install jq)"
  # Codex reads one hooks.json per configuration folder. An existing, different file is a CONFLICT:
  # merge our two entries into it by hand, or use --adopt to move it aside.
  render_item "$REPO_ROOT/hooks/codex/hooks.json.tmpl" "$HOME/.codex/hooks.json"
  say "  manual    run /hooks in Codex once and trust the agentd hooks. Codex skips a hook until it is trusted."
  print_manifest codex-cli
}
