#!/usr/bin/env bash
# OpenAI Codex CLI: reads personal skills from ~/.agents/skills, so no skills link is needed here.
# Codex cannot attach a hook to a skill, so it gets the shell hook in ~/.codex/hooks.json. The hook stays
# dormant until an agentd skill starts in the session. Sourced by install.sh.

# codex_has_ours DST TMPL: true when DST already holds every entry of TMPL, for example merged by hand next to
# other hooks. An entry matches a hook in the same event with the same command and the same matcher. Needs jq.
codex_has_ours() {
  [ -f "$1" ] || return 1
  # render_item refuses such a HOME, so never call a file with it ours.
  case "$HOME" in *[\"\$\`\\]*) return 1 ;; esac
  jq -e --arg home "$HOME" --slurpfile want "$2" '
    . as $have
    | [$want[0].hooks | to_entries[] | .key as $ev | .value[] | (.matcher // "") as $m | .hooks[]
        | {ev: $ev, m: $m, c: (.command | sub("@HOME@"; $home))}]
    | all(.[]; . as $w
        | any($have.hooks[$w.ev][]?; (.matcher // "") == $w.m and any(.hooks[]?; .command == $w.c)))
  ' "$1" >/dev/null 2>&1
}

# codex_has_others DST: true when DST holds any hook, so --adopt would move the engineer's own hooks aside too.
codex_has_others() {
  [ -f "$1" ] && jq -e '[.hooks[]?[]?] | length > 0' "$1" >/dev/null 2>&1
}

harness_codex_cli() {
  local dst="$HOME/.codex/hooks.json" tmpl="$REPO_ROOT/hooks/codex/hooks.json.tmpl" others=0
  say "codex-cli"
  if [ ! -d "$HOME/.codex" ]; then
    warn "$HOME/.codex not found: install and start Codex once, then re-run. Skipped."
    return 0
  fi
  command -v jq >/dev/null 2>&1 || warn "jq not found: block-dangerous-shell.sh needs it (brew install jq)"
  # Codex reads one hooks.json per configuration folder. A file that already holds our two entries is fine, even
  # with other hooks next to them. Any other existing file is a CONFLICT: merge our two entries into it by hand,
  # or use --adopt to move it aside. The script never edits the file.
  if codex_has_ours "$dst" "$tmpl"; then
    say "  ok        $dst (holds the agentd entries)"
    N_OK=$((N_OK + 1))
  else
    codex_has_others "$dst" && others=1
    render_item "$tmpl" "$dst"
    if [ "$others" = 1 ]; then
      say "  note      $dst holds other hooks. --adopt moves them to the backup folder too. To keep them in place,"
      say "            merge the two agentd entries from hooks/codex/hooks.json.tmpl into it by hand."
    fi
  fi
  say "  manual    run /hooks in Codex once and trust the agentd hooks. Codex skips a hook until it is trusted."
  print_manifest codex-cli
}
