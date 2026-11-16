#!/usr/bin/env bash
# Set up personal agent skills, global guide and hooks on this machine.
# Dry run by default: nothing changes until you pass --apply.
set -u

REPO_ROOT=$(cd "$(dirname "$0")" && pwd -P)

usage() {
  cat <<'EOF'
Usage: ./install.sh [--apply] [--adopt] [--harness LIST] [--always-on-guard]

  (no flags)       Show what would change. Changes nothing.
  --apply          Create the missing links and files.
  --adopt          Move an existing, different item to
                   ~/.agent-skills-backup/<time>/ and link ours in its place.
                   Needs --apply to take effect. Without --adopt, such items
                   are reported as CONFLICT and left alone.
  --harness LIST   Comma list: claude-code,copilot-cli,codex-cli (default: all three).
  --always-on-guard
                   Opt in: deny dangerous git commands in every session, not
                   only in agentd skills. Writes the empty file
                   ~/.agents/always-on-guard and prints a snippet for Claude
                   Code's settings.json. Delete that file to turn it off.

Environment:
  CLAUDE_CONFIG_DIR  Link Claude Code skills and CLAUDE.md into this folder
                     too. Without any folder setting, ~/.claude is used.
  CLAUDE_CONFIG_DIRS More folders, separated by colons.
  ~/.agents/claude-config-dirs
                     One folder per line (# starts a comment). Use it to link
                     every Claude Code folder in each run.

Nothing is ever deleted. Plugins are listed, never installed.
Exit status: 0 = clean, 1 = conflicts or failed links remain,
             2 = bad usage or a missing prerequisite.
EOF
}

HARNESSES="claude-code copilot-cli codex-cli"
ALWAYS_ON_GUARD=0

# shellcheck source=lib/common.sh
. "$REPO_ROOT/lib/common.sh"

if ! command -v realpath >/dev/null 2>&1; then
  say "realpath not found (macOS 13 or later, or GNU coreutils, is required)."
  exit 2
fi

while [ $# -gt 0 ]; do
  case "$1" in
    --apply) MODE=apply ;;
    --adopt) ADOPT=1 ;;
    --always-on-guard) ALWAYS_ON_GUARD=1 ;;
    --harness)
      shift
      [ $# -gt 0 ] || { usage; exit 2; }
      HARNESSES=$(printf '%s' "$1" | tr ',' ' ')
      ;;
    -h|--help) usage; exit 0 ;;
    *) say "unknown option: $1"; usage; exit 2 ;;
  esac
  shift
done

for h in $HARNESSES; do
  case "$h" in
    claude-code|copilot-cli|codex-cli) ;;
    *) say "unknown harness: $h"; exit 2 ;;
  esac
done

# Git Bash on Windows: a plain ln -s copies instead of linking. nativestrict makes it create a real Windows symlink
# or fail, never copy. Real symlinks need Developer Mode (or admin rights). Always append: the last winsymlinks wins.
case "$(uname -s)" in
  MINGW*|MSYS*)
    export MSYS="${MSYS:+$MSYS }winsymlinks:nativestrict"
    if ! links_work; then
      say "Windows did not create a symlink. Turn on Developer Mode (Settings > System > For developers), then re-run."
      exit 2
    fi
    ;;
esac

if is_apply; then say "APPLY mode. Repo: $REPO_ROOT"; else say "DRY RUN (nothing changes). Repo: $REPO_ROOT"; fi

# Core: ~/.agents is the shared home that every harness reads.
say "core"
for dir in "$REPO_ROOT"/skills/*/; do
  name=$(basename "$dir")
  link_item "${dir%/}" "$HOME/.agents/skills/$name"
done
link_item "$REPO_ROOT/global/AGENTS.md" "$HOME/.agents/AGENTS.md"
for f in "$REPO_ROOT"/global/bin/*; do
  link_item "$f" "$HOME/.agents/bin/$(basename "$f")"
done
# The shell safety hook. Every tool calls it from this one path: the agentd skills (Claude Code),
# ~/.copilot/hooks/git-safety.json and ~/.codex/hooks.json.
link_item "$REPO_ROOT/hooks/copilot/block-dangerous-shell.sh" "$HOME/.agents/hooks/block-dangerous-shell.sh"
# The opt-in always-on guard: an empty file that the hook reads. The installer never deletes it, so the engineer
# turns the guard off by deleting the file.
GUARD_FILE="$HOME/.agents/always-on-guard"
if [ "$ALWAYS_ON_GUARD" = 1 ]; then
  write_marker "$GUARD_FILE"
elif [ -e "$GUARD_FILE" ]; then
  say "  note      the always-on guard is on. Delete $GUARD_FILE to turn it off."
fi
# One jq check for every tool: the hook needs jq. Outside an agentd skill the always-on guard stays silent without
# it, so it would check nothing.
if ! command -v jq >/dev/null 2>&1; then
  if [ "$ALWAYS_ON_GUARD" = 1 ] || [ -e "$GUARD_FILE" ]; then
    warn "jq not found: the shell hook needs it, and the always-on guard checks nothing without it (brew install jq, or winget install jqlang.jq on Windows)"
  else
    warn "jq not found: the shell hook needs it (brew install jq, or winget install jqlang.jq on Windows)"
  fi
fi

for h in $HARNESSES; do
  # shellcheck disable=SC1090
  . "$REPO_ROOT/harness/$h.sh"
  case "$h" in
    claude-code) harness_claude_code ;;
    copilot-cli) harness_copilot_cli ;;
    codex-cli) harness_codex_cli ;;
  esac
done

say ""
say "summary: ok=$N_OK link/write=$N_LINK adopt=$N_ADOPT conflict=$N_CONFLICT failed=$N_FAIL warn=$N_WARN"
if ! is_apply; then say "dry run only. Re-run with --apply to make these changes."; fi
[ "$N_CONFLICT" -eq 0 ] && [ "$N_FAIL" -eq 0 ] || exit 1
exit 0
