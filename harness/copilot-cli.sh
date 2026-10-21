#!/usr/bin/env bash
# GitHub Copilot CLI: reads personal skills from ~/.agents/skills since v1.0.11,
# so no skills link is needed here. Sourced by install.sh.

COPILOT_MIN_VERSION=1.0.11

harness_copilot_cli() {
  say "copilot-cli"
  if [ ! -d "$HOME/.copilot" ]; then
    warn "$HOME/.copilot not found: install and start Copilot CLI once, then re-run. Skipped."
    return 0
  fi

  local version
  if command -v copilot >/dev/null 2>&1; then
    version=$(copilot --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)
    if [ -z "$version" ]; then
      warn "could not read the copilot version"
    elif ! version_ge "$version" "$COPILOT_MIN_VERSION"; then
      warn "copilot $version is older than $COPILOT_MIN_VERSION: it will not read ~/.agents/skills. Run 'copilot update'."
    fi
  else
    warn "copilot not on PATH: cannot check the version (needs >= $COPILOT_MIN_VERSION)"
  fi

  command -v jq >/dev/null 2>&1 || warn "jq not found: block-dangerous-shell.sh needs it (brew install jq)"

  # Same pattern as today: the Copilot guide points at the shared AGENTS.md.
  link_item "$REPO_ROOT/global/AGENTS.md" "$HOME/.copilot/copilot-instructions.md" "$HOME/.agents/AGENTS.md"
  link_item "$REPO_ROOT/hooks/copilot/block-dangerous-shell.sh" "$HOME/.copilot/hooks/block-dangerous-shell.sh"
  # Absolute path inside, so rendered rather than linked.
  render_item "$REPO_ROOT/hooks/copilot/git-safety.json.tmpl" "$HOME/.copilot/hooks/git-safety.json"
  print_manifest copilot-cli
}
