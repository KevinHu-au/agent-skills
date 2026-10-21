#!/usr/bin/env bash
# Runs install.sh against throwaway HOME folders. Never touches the real home.
# It deletes nothing: the temp folders are left for the OS to clear, and listed at the end.
# Usage: tests/test-install.sh
set -u

REPO=$(cd "$(dirname "$0")/.." && pwd -P)
PASS=0
FAIL=0
TMPS=""

check() {
  local desc=$1
  shift
  if "$@" >/dev/null 2>&1; then
    PASS=$((PASS + 1))
    printf '  pass  %s\n' "$desc"
  else
    FAIL=$((FAIL + 1))
    printf '  FAIL  %s\n' "$desc"
  fi
}

not() { ! "$@"; }
resolves_to() { [ "$(realpath "$1" 2>/dev/null)" = "$(realpath "$2")" ]; }
is_real_dir() { [ -d "$1" ] && [ ! -L "$1" ]; }
has() { printf '%s' "$1" | grep -q -- "$2"; }

# new_home [nocopilot]: a fresh fake HOME with a fake copilot on PATH.
new_home() {
  H=$(mktemp -d)
  TMPS="$TMPS $H"
  mkdir -p "$H/.claude" "$H/bin"
  [ "${1:-}" = nocopilot ] || mkdir -p "$H/.copilot"
  printf '#!/bin/sh\necho "GitHub Copilot CLI 1.0.101."\n' >"$H/bin/copilot"
  chmod +x "$H/bin/copilot"
}

run() { HOME=$H PATH="$H/bin:$PATH" "$REPO/install.sh" "$@"; }

echo "1. fresh machine"
new_home
OUT=$(run 2>&1); RC=$?
check "dry run exits 0" [ "$RC" -eq 0 ]
check "dry run creates nothing" [ ! -e "$H/.agents" ]
check "dry run has no false 'source missing' warnings" not has "$OUT" 'source missing'
check "dry run plans every link (no warnings)" has "$OUT" 'warn=0'
OUT=$(run --apply 2>&1); RC=$?
check "apply exits 0" [ "$RC" -eq 0 ]
for s in agentd-dev-rev agentd-pr-prep agentd-prompt; do
  check "agents link: $s" resolves_to "$H/.agents/skills/$s" "$REPO/skills/$s"
  check "claude link: $s" resolves_to "$H/.claude/skills/$s" "$REPO/skills/$s"
done
check "AGENTS.md linked" resolves_to "$H/.agents/AGENTS.md" "$REPO/global/AGENTS.md"
check "CLAUDE.md linked" resolves_to "$H/.claude/CLAUDE.md" "$REPO/global/claude/CLAUDE.md"
check "copilot guide resolves to AGENTS.md" resolves_to "$H/.copilot/copilot-instructions.md" "$REPO/global/AGENTS.md"
check "hook script linked" resolves_to "$H/.copilot/hooks/block-dangerous-shell.sh" "$REPO/hooks/copilot/block-dangerous-shell.sh"
check "hook script is executable" [ -x "$H/.copilot/hooks/block-dangerous-shell.sh" ]
check "git-safety.json is valid JSON" jq -e . "$H/.copilot/hooks/git-safety.json"
check "git-safety.json has the fake home path" grep -q "$H/.copilot/hooks/block-dangerous-shell.sh" "$H/.copilot/hooks/git-safety.json"
check "git-safety.json has no placeholder left" not grep -q '@HOME@' "$H/.copilot/hooks/git-safety.json"
OUT=$(run --apply 2>&1); RC=$?
check "second apply exits 0" [ "$RC" -eq 0 ]
check "second apply changes nothing" has "$OUT" 'link/write=0'
check "second apply prints no 'linked'" not has "$OUT" 'linked '

echo "2. legacy machine (real copies, today's layout)"
new_home
mkdir -p "$H/.agents/skills" "$H/.claude/skills" "$H/.copilot/hooks"
for s in agentd-dev-rev agentd-pr-prep agentd-prompt; do
  cp -R "$REPO/skills/$s" "$H/.agents/skills/$s"
  if [ "$s" = agentd-dev-rev ]; then
    cp -R "$REPO/skills/$s" "$H/.claude/skills/$s"          # real copy, like today
  else
    ln -s "../../.agents/skills/$s" "$H/.claude/skills/$s"  # relative link, like today
  fi
done
echo "local edit" >>"$H/.agents/skills/agentd-pr-prep/SKILL.md"       # a copy that differs
cp "$REPO/global/AGENTS.md" "$H/.agents/AGENTS.md"
cp "$REPO/global/claude/CLAUDE.md" "$H/.claude/CLAUDE.md"
ln -s "$H/.agents/AGENTS.md" "$H/.copilot/copilot-instructions.md"
cp "$REPO/hooks/copilot/block-dangerous-shell.sh" "$H/.copilot/hooks/block-dangerous-shell.sh"
sed "s#@HOME@#$H#g" "$REPO/hooks/copilot/git-safety.json.tmpl" >"$H/.copilot/hooks/git-safety.json"

OUT=$(run --apply 2>&1); RC=$?
check "apply without --adopt exits 1" [ "$RC" -eq 1 ]
check "reports CONFLICT" has "$OUT" 'CONFLICT'
check "reports the differing copy" has "$OUT" 'differs from the repo'
check "reports identical copies" has "$OUT" 'identical copy'
check "nothing replaced without --adopt" is_real_dir "$H/.agents/skills/agentd-prompt"
check "local edit still in place" grep -q 'local edit' "$H/.agents/skills/agentd-pr-prep/SKILL.md"

OUT=$(run --adopt 2>&1); RC=$?
check "plan with --adopt changes nothing" is_real_dir "$H/.agents/skills/agentd-prompt"

OUT=$(run --apply --adopt 2>&1); RC=$?
check "apply --adopt exits 0" [ "$RC" -eq 0 ]
for s in agentd-dev-rev agentd-pr-prep agentd-prompt; do
  check "agents link: $s" resolves_to "$H/.agents/skills/$s" "$REPO/skills/$s"
  check "claude link: $s" resolves_to "$H/.claude/skills/$s" "$REPO/skills/$s"
done
check "copilot guide resolves to repo" resolves_to "$H/.copilot/copilot-instructions.md" "$REPO/global/AGENTS.md"
BK=$(ls -d "$H"/.agent-skills-backup/*/ 2>/dev/null | head -n 1)
check "backup folder exists" [ -n "$BK" ]
check "one run uses exactly one backup folder" [ "$(ls -d "$H"/.agent-skills-backup/*/ | wc -l | tr -d ' ')" -eq 1 ]
check "backup kept the local edit" grep -q 'local edit' "${BK}.agents/skills/agentd-pr-prep/SKILL.md"
OUT=$(run --apply 2>&1); RC=$?
check "re-run after adopt exits 0" [ "$RC" -eq 0 ]
check "re-run after adopt changes nothing" has "$OUT" 'link/write=0 adopt=0'

echo "3. missing harness folder and bad usage"
new_home nocopilot
OUT=$(run --apply 2>&1); RC=$?
check "missing ~/.copilot skips with a warning" has "$OUT" 'not found'
check "missing ~/.copilot creates nothing there" [ ! -e "$H/.copilot" ]
check "claude-code still installed" resolves_to "$H/.claude/skills/agentd-pr-prep" "$REPO/skills/agentd-pr-prep"
run --bogus >/dev/null 2>&1; RC=$?
check "bad option exits 2" [ "$RC" -eq 2 ]
run --harness nope >/dev/null 2>&1; RC=$?
check "bad harness exits 2" [ "$RC" -eq 2 ]

echo "4. dangling symlink, single harness, unadopted core"
new_home
mkdir -p "$H/.agents/skills"
ln -s "$H/nowhere" "$H/.agents/skills/agentd-pr-prep"                 # symlink to somewhere else
OUT=$(run --apply 2>&1); RC=$?
check "dangling symlink is a CONFLICT" has "$OUT" 'CONFLICT.*agentd-pr-prep'
check "dangling symlink exits 1" [ "$RC" -eq 1 ]
check "claude link not made onto a stale core link" not test -e "$H/.claude/skills/agentd-pr-prep"
check "other skills still linked" resolves_to "$H/.claude/skills/agentd-prompt" "$REPO/skills/agentd-prompt"
new_home
OUT=$(run --apply --harness copilot-cli 2>&1); RC=$?
check "--harness copilot-cli exits 0" [ "$RC" -eq 0 ]
check "--harness copilot-cli leaves Claude alone" not test -e "$H/.claude/skills"

echo "5. HOME with characters that break sed or JSON"
new_home
H="$H/w&x#y"
mkdir -p "$H/.claude" "$H/.copilot" "$H/bin"
printf '#!/bin/sh\necho "GitHub Copilot CLI 1.0.101."\n' >"$H/bin/copilot"
chmod +x "$H/bin/copilot"
OUT=$(run --apply 2>&1); RC=$?
check "apply exits 0" [ "$RC" -eq 0 ]
check "git-safety.json is valid JSON" jq -e . "$H/.copilot/hooks/git-safety.json"
check "git-safety.json holds the exact path" \
  test "$(jq -r '.hooks.preToolUse[0].bash' "$H/.copilot/hooks/git-safety.json")" = "$H/.copilot/hooks/block-dangerous-shell.sh"

echo "6. block-dangerous-shell.sh today (characterisation, not a spec)"
HOOK="$REPO/hooks/copilot/block-dangerous-shell.sh"
hook() { printf '{"toolName":"bash","toolArgs":"{\\"command\\":\\"%s\\"}"}' "$1" | "$HOOK"; }
check "git push is denied" has "$(hook 'git push')" 'deny'
check "git reset --hard is denied" has "$(hook 'git reset --hard')" 'deny'
check "rm asks" has "$(hook 'rm -f x')" 'ask'
check "ls is allowed" has "$(hook 'ls -la')" 'allow'

echo
echo "passed=$PASS failed=$FAIL"
echo "temp folders left in place:$TMPS"
[ "$FAIL" -eq 0 ]
