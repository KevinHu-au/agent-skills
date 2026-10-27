#!/usr/bin/env bash
# Set up personal agent skills, global guide and hooks on this machine.
# Dry run by default: nothing changes until you pass --apply.
set -u

REPO_ROOT=$(cd "$(dirname "$0")" && pwd -P)

usage() {
  cat <<'EOF'
Usage: ./install.sh [--apply] [--adopt] [--harness LIST]

  (no flags)       Show what would change. Changes nothing.
  --apply          Create the missing links and files.
  --adopt          Move an existing, different item to
                   ~/.agent-skills-backup/<time>/ and link ours in its place.
                   Needs --apply to take effect. Without --adopt, such items
                   are reported as CONFLICT and left alone.
  --harness LIST   Comma list: claude-code,copilot-cli (default: both).

Environment:
  CLAUDE_CONFIG_DIR  Link Claude Code skills and CLAUDE.md into this folder
                     instead of ~/.claude. One folder per run.

Nothing is ever deleted. Plugins are listed, never installed.
Exit status: 0 = clean, 1 = conflicts remain, 2 = bad usage.
EOF
}

HARNESSES="claude-code copilot-cli"

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
    claude-code|copilot-cli) ;;
    *) say "unknown harness: $h"; exit 2 ;;
  esac
done

if is_apply; then say "APPLY mode. Repo: $REPO_ROOT"; else say "DRY RUN (nothing changes). Repo: $REPO_ROOT"; fi

# Core: ~/.agents is the shared home that both harnesses read.
say "core"
for dir in "$REPO_ROOT"/skills/*/; do
  name=$(basename "$dir")
  link_item "${dir%/}" "$HOME/.agents/skills/$name"
done
link_item "$REPO_ROOT/global/AGENTS.md" "$HOME/.agents/AGENTS.md"
for f in "$REPO_ROOT"/global/bin/*; do
  link_item "$f" "$HOME/.agents/bin/$(basename "$f")"
done

for h in $HARNESSES; do
  # shellcheck disable=SC1090
  . "$REPO_ROOT/harness/$h.sh"
  case "$h" in
    claude-code) harness_claude_code ;;
    copilot-cli) harness_copilot_cli ;;
  esac
done

say ""
say "summary: ok=$N_OK link/write=$N_LINK adopt=$N_ADOPT conflict=$N_CONFLICT warn=$N_WARN"
if ! is_apply; then say "dry run only. Re-run with --apply to make these changes."; fi
[ "$N_CONFLICT" -eq 0 ] || exit 1
exit 0
