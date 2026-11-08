#!/usr/bin/env bash
# Runs install.sh against throwaway HOME folders. Never touches the real home.
# Its temp folders are removed when every check passes, and kept when one fails.
# Usage: tests/test-install.sh
set -u

REPO=$(cd "$(dirname "$0")/.." && pwd -P)
PASS=0
FAIL=0

# Temp folders. Every mktemp in this run lands in TMP_ROOT. It is removed when every check passes. When a check
# fails it is kept and its path printed. The next run removes folders kept by earlier runs.
rm_tmp() { chmod -R u+w "$1" 2>/dev/null; rm -rf "$1"; }
TMP_NAME=agent-skills-test-install
TMP_BASE=${TMPDIR:-/tmp}
TMP_BASE=${TMP_BASE%/}
for old in "$TMP_BASE/$TMP_NAME".*; do [ -d "$old" ] && rm_tmp "$old"; done
TMP_ROOT=$(mktemp -d "$TMP_BASE/$TMP_NAME.XXXXXX") || exit 1
export TMPDIR=$TMP_ROOT TMP_ROOT
# macOS mktemp ignores TMPDIR, so a call without a template gets one inside TMP_ROOT.
mktemp() { case " $* " in *XXX*) command mktemp "$@" ;; *) command mktemp "$@" "$TMP_ROOT/tmp.XXXXXX" ;; esac; }
export -f mktemp
cleanup() { if [ "$FAIL" -eq 0 ]; then rm_tmp "$TMP_ROOT"; else echo "temp folder kept: $TMP_ROOT"; fi; }
trap cleanup EXIT

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
  mkdir -p "$H/.claude" "$H/bin"
  [ "${1:-}" = nocopilot ] || mkdir -p "$H/.copilot" "$H/.codex"
  printf '#!/bin/sh\necho "GitHub Copilot CLI 1.0.101."\n' >"$H/bin/copilot"
  chmod +x "$H/bin/copilot"
}

# env -u: a CLAUDE_CONFIG_DIR set in the caller's shell must not leak into the real config folder.
run() { env -u CLAUDE_CONFIG_DIR -u CLAUDE_CONFIG_DIRS HOME=$H PATH="$H/bin:$PATH" "$REPO/install.sh" "$@"; }

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
check "rm-scratch linked" resolves_to "$H/.agents/bin/rm-scratch" "$REPO/global/bin/rm-scratch"
check "rm-scratch runs through the link and prints usage" bash -c 'out=$("$1" 2>&1); [ $? -eq 1 ] && printf "%s" "$out" | grep -q usage' _ "$H/.agents/bin/rm-scratch"
check "onboarding-pack linked" resolves_to "$H/.agents/bin/onboarding-pack" "$REPO/global/bin/onboarding-pack"
check "onboarding-pack runs through the link and prints usage" bash -c 'out=$("$1" 2>&1); [ $? -eq 2 ] && printf "%s" "$out" | grep -q usage' _ "$H/.agents/bin/onboarding-pack"
check "CLAUDE.md linked" resolves_to "$H/.claude/CLAUDE.md" "$REPO/global/claude/CLAUDE.md"
check "copilot guide resolves to AGENTS.md" resolves_to "$H/.copilot/copilot-instructions.md" "$REPO/global/AGENTS.md"
check "hook script linked" resolves_to "$H/.agents/hooks/block-dangerous-shell.sh" "$REPO/hooks/copilot/block-dangerous-shell.sh"
check "hook script is executable" [ -x "$H/.agents/hooks/block-dangerous-shell.sh" ]
check "no hook script link in ~/.copilot/hooks" [ ! -e "$H/.copilot/hooks/block-dangerous-shell.sh" ]
check "git-safety.json is valid JSON" jq -e . "$H/.copilot/hooks/git-safety.json"
check "git-safety.json has the fake home path" grep -q "$H/.agents/hooks/block-dangerous-shell.sh" "$H/.copilot/hooks/git-safety.json"
check "git-safety.json has no placeholder left" not grep -q '@HOME@' "$H/.copilot/hooks/git-safety.json"
check "git-safety.json has the prompt and tool entries, and no session-end entry" \
  test "$(jq -r '[(.hooks.userPromptSubmitted | length), (.hooks.preToolUse | length), (.hooks | has("sessionEnd"))] | map(tostring) | join(",")' "$H/.copilot/hooks/git-safety.json")" = "1,1,false"
check "git-safety.json matches the skill tool" \
  test "$(jq -r '.hooks.preToolUse[0].matcher' "$H/.copilot/hooks/git-safety.json")" = "bash|powershell|skill"
check "codex hooks.json is valid JSON" jq -e . "$H/.codex/hooks.json"
check "codex hooks.json has no placeholder left" not grep -q '@HOME@' "$H/.codex/hooks.json"
check "codex hooks.json calls the script as codex" grep -q -- '--harness codex' "$H/.codex/hooks.json"
check "the installer writes no Claude Code settings.json" [ ! -e "$H/.claude/settings.json" ]
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
mkdir -p "$H/.claude" "$H/.copilot" "$H/.codex" "$H/bin"
printf '#!/bin/sh\necho "GitHub Copilot CLI 1.0.101."\n' >"$H/bin/copilot"
chmod +x "$H/bin/copilot"
OUT=$(run --apply 2>&1); RC=$?
check "apply exits 0" [ "$RC" -eq 0 ]
check "git-safety.json is valid JSON" jq -e . "$H/.copilot/hooks/git-safety.json"
check "git-safety.json holds the exact quoted path" \
  test "$(jq -r '.hooks.preToolUse[0].bash' "$H/.copilot/hooks/git-safety.json")" = "\"$H/.agents/hooks/block-dangerous-shell.sh\" --harness copilot --event tool"
# A session that started an agentd skill (its marker exists): a dangerous command is denied.
mkdir -p "$H/.agents/hook-state" && : >"$H/.agents/hook-state/s5"
check "the rendered Copilot command runs through a shell" \
  test "$(jq -cn '{sessionId:"s5",toolName:"bash",toolArgs:{command:"git push"}}' \
    | HOME=$H bash -c "$(jq -r '.hooks.preToolUse[0].bash' "$H/.copilot/hooks/git-safety.json")" | jq -r .permissionDecision)" = deny
check "codex hooks.json is valid JSON" jq -e . "$H/.codex/hooks.json"
check "codex hooks.json holds the exact quoted path" \
  test "$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$H/.codex/hooks.json")" = "\"$H/.agents/hooks/block-dangerous-shell.sh\" --harness codex --event tool"

echo "6. block-dangerous-shell.sh"
# TEST_HOOK may point at a draft copy, so a new hook is tested before it replaces the live one.
TEST_HOOK=${TEST_HOOK:-$REPO/hooks/copilot/block-dangerous-shell.sh}
HH=$(mktemp -d)
mkdir -p "$HH/.agents/hook-state" && : >"$HH/.agents/hook-state/t6"
hook() {
  jq -cn --arg c "$1" '{sessionId:"t6",toolName:"bash",toolArgs:({command:$c}|tojson)}' \
    | HOME=$HH "$TEST_HOOK" --harness copilot --event tool
}
# legacy: an older install calls the script with no flags.
legacy() { jq -cn --arg c "$1" '{toolName:"bash",toolArgs:({command:$c}|tojson)}' | HOME=$HH "$TEST_HOOK"; }
decision() { printf '%s' "$1" | jq -r '.permissionDecision' 2>/dev/null; }
is_deny() { [ "$(decision "$(hook "$1")")" = deny ]; }
is_ask() { [ "$(decision "$(hook "$1")")" = ask ]; }
is_silent() { [ -z "$(hook "$1")" ]; }
for c in 'git push' 'git reset --hard' 'git push --force origin main' 'cd repo && git push' \
  'git -C repo push' '/usr/bin/git push' '\git push' '(git push)' 'echo $(git push)' \
  'git -c core.pager=cat push' 'git --git-dir=.git push' 'git --no-pager push' \
  'git clean -f' 'git clean -fd' 'git clean -fdx' 'git clean -xdf' 'git clean --force' \
  'git reset --soft HEAD~1 && git reset --hard' 'git -C repo reset --hard HEAD' \
  'git branch -D topic' 'git branch -Dq topic' 'git checkout .' 'git checkout -- .' 'git restore .' \
  'git -C "my repo" push --force' 'git -C "my repo" reset --hard' 'git -c "a=b c" push' "git --git-dir 'x y' push" \
  "bash -c 'git push'" 'git push>out' 'git reset --hard>out' "$(printf 'git reset \\\n  --hard')" \
  "$(printf 'git \\\npush')" 'git branch --delete --force topic' 'git branch -d -f topic' 'git checkout -f main' \
  'git switch -f main' 'git switch --discard-changes main' 'git checkout -- ./' \
  'git -C $(pwd) push' 'git --git-dir=$(pwd)/.git push' 'git -C $(git rev-parse --show-toplevel) push --force' \
  'git checkout -B main origin/main' 'git switch -C main origin/main' 'git switch --force-create main' \
  'git branch -M main' 'git --config-env a=B push' 'git --super-prefix x/ push' '"git" push' "'git' push" \
  "$(printf 'git reset \\\r\n  --hard')"; do
  check "denied: $c" is_deny "$c"
done
for c in 'rm -f x' '/bin/rm x' '\rm x' '(rm x)' 'xargs rm' 'rmdir d' 'unlink f' 'trash x' \
  'find . -name x -delete' 'cd /tmp && find . -delete' 'bash -c "rm -rf x"' 'eval "rm x"' \
  'Remove-Item -Recurse x' 'remove-item x' 'ri x' 'del x' 'erase x' 'rd x'; do
  check "asks: $c" is_ask "$c"
done
# Commit, history rewrite, single-file discard, PR create or merge, and SQL writes: ask, never deny.
for c in 'git commit -m "fix login"' 'git commit --amend' 'git commit -am x' 'git -C repo commit -m x' \
  'cd repo && git commit -m x' '/usr/bin/git commit -m x' \
  'git rebase main' 'git rebase -i HEAD~3' 'git filter-branch --tree-filter x' 'git stash drop' 'git stash clear' \
  'git stash drop stash@{1}' 'git -C repo rebase main' \
  'git checkout -- src/a.cs' 'git checkout HEAD -- src/a.cs' 'git restore src/a.cs' 'git -C repo restore a.cs' \
  'gh pr create' 'gh pr create --title x --body y' 'gh pr merge 12' 'gh pr merge --squash' \
  'az repos pr create --title x' \
  'sqlcmd -S srv -Q "DELETE FROM t"' 'sqlcmd -Q "update t set a = 1"' 'sqlcmd -Q "Insert into t values (1)"' \
  'sqlcmd -Q "DROP TABLE t"' 'sqlcmd -Q "truncate table t"' 'sqlcmd -Q "ALTER TABLE t ADD c int"' \
  'Invoke-Sqlcmd -Query "DELETE FROM t"' 'invoke-sqlcmd -Query "update t set a = 1"' \
  'cd db && sqlcmd -Q "delete from t"' \
  'az repos pr update --id 1 --status completed' 'az repos pr update --id 1 --status=completed' \
  'gh api -X PUT repos/o/r/pulls/12/merge' 'sqlcmd -Q "EXEC dbo.PurgeOrders"' 'sqlcmd -Q "create table t (a int)"' \
  'Invoke-Sqlcmd -Query "exec dbo.x"' 'sqlcmd -Q "MERGE t USING s ON 1=1 WHEN MATCHED THEN UPDATE SET a=1;"' \
  'az repos pr update --id 1 --auto-complete true' 'az repos pr update --id 1 --auto-complete=true'; do
  check "asks: $c" is_ask "$c"
done
for c in 'ls -la' 'git status' 'git log --oneline' 'git log --grep=push' \
  'git config --get remote.origin.pushurl' 'git clean -n' 'git branch -d topic' 'git checkout main' \
  'git switch main' 'echo hello > out' 'Get-ChildItem -Recurse' \
  'git checkout -b feat' 'git switch -c feat' 'git branch -m old new' 'git -C $(pwd) status' \
  'grep -rn rmdir_helper .' 'npm run format' 'find . -name "*.md"' \
  'git commit-tree abc' 'git log --grep=commit' 'git show HEAD' 'git diff --cached' 'git add -p' \
  'git stash' 'git stash pop' 'git stash list' 'git stash push -m x' \
  'gh pr view 12' 'gh pr list' 'gh pr checkout 12' 'gh pr diff 12' 'az repos pr list' \
  'sqlcmd -Q "SELECT * FROM users"' 'sqlcmd -Q "select updated_at, deleted_flag from t"' \
  'Invoke-Sqlcmd -Query "SELECT 1"' 'echo "update the docs"' \
  'az repos pr update --id 1 --title x' 'gh api repos/o/r/pulls/12' 'az repos pr update --id 1 --auto-complete false' \
  'sqlcmd -Q "select created_at, executed_by from t"'; do
  check "no output: $c" is_silent "$c"
done
check "a tool that is not a shell gets no output" \
  test -z "$(printf '{"toolName":"view","toolArgs":"{}"}' | "$TEST_HOOK")"
check "input that is not JSON is denied" \
  test "$(decision "$(printf 'not json' | "$TEST_HOOK")")" = deny
check "a shell call whose command cannot be read is denied" \
  test "$(decision "$(printf '{"toolName":"bash","toolArgs":"not json"}' | "$TEST_HOOK")")" = deny
check "a missing jq is denied with a message" \
  has "$(printf '{"toolName":"bash","toolArgs":"{}"}' | PATH=/nonexistent "$TEST_HOOK")" '"permissionDecision":"deny".*jq'

# Claude Code sends tool_name and tool_input, and reads the decision from hookSpecificOutput.
chook() {
  jq -cn --arg t "${2:-Bash}" --arg c "$1" '{hook_event_name:"PreToolUse",tool_name:$t,tool_input:{command:$c}}' \
    | "$TEST_HOOK" --harness claude --event tool
}
cdecision() { printf '%s' "$1" | jq -r '.hookSpecificOutput.permissionDecision' 2>/dev/null; }
check "claude: a dangerous git command is denied" test "$(cdecision "$(chook 'git push')")" = deny
check "claude: a removal asks" test "$(cdecision "$(chook 'rm -f x')")" = ask
check "claude: a commit asks" test "$(cdecision "$(chook 'git commit -m x')")" = ask
check "claude: the PowerShell tool is checked too" test "$(cdecision "$(chook 'Remove-Item x' PowerShell)")" = ask
check "claude: an ordinary command gets no output" test -z "$(chook 'ls -la')"
check "claude: a tool that is not a shell gets no output" test -z "$(chook 'git push' Read)"
check "claude: the decision names the event" \
  test "$(printf '%s' "$(chook 'git push')" | jq -r '.hookSpecificOutput.hookEventName')" = PreToolUse
check "claude: the decision carries a reason" \
  test -n "$(printf '%s' "$(chook 'git push')" | jq -r '.hookSpecificOutput.permissionDecisionReason // empty')"
check "claude: the output has no top-level decision" \
  jq -e 'has("permissionDecision") | not' <<<"$(chook 'git push')"
check "claude: a command that cannot be read is denied" \
  test "$(cdecision "$(printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{}}' | "$TEST_HOOK")")" = deny
check "claude: a missing jq is denied in the claude shape" \
  has "$(printf '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls"}}' | PATH=/nonexistent "$TEST_HOOK")" '"hookSpecificOutput".*"permissionDecision":"deny".*jq'
check "copilot: the output has no hookSpecificOutput" \
  not has "$(hook 'git push')" 'hookSpecificOutput'
# An older install (no flags) keeps the older rules only, so a git pull adds nothing to its sessions.
check "legacy: a dangerous git command is still denied" test "$(decision "$(legacy 'git push')")" = deny
check "legacy: a removal still asks" test "$(decision "$(legacy 'rm -f x')")" = ask
for c in 'git commit -m x' 'git rebase main' 'git restore a.cs' 'gh pr create' 'sqlcmd -Q "delete from t"' \
  'az repos pr update --id 1 --status completed'; do
  check "legacy: no newer rule: $c" test -z "$(legacy "$c")"
done

echo "7. CLAUDE_CONFIG_DIR"
new_home
CD="$H/.claude-work"
mkdir -p "$CD"
runc() { env -u CLAUDE_CONFIG_DIRS HOME=$H PATH="$H/bin:$PATH" CLAUDE_CONFIG_DIR=$CD "$REPO/install.sh" "$@"; }
OUT=$(runc --harness claude-code 2>&1); RC=$?
check "dry run exits 0" [ "$RC" -eq 0 ]
check "dry run plans links in the custom folder" has "$OUT" "$CD/skills/agentd-pr-prep"
check "dry run creates nothing in the custom folder" [ ! -e "$CD/skills" ]
OUT=$(runc --apply --harness claude-code 2>&1); RC=$?
check "apply exits 0" [ "$RC" -eq 0 ]
for s in agentd-dev-rev agentd-pr-prep agentd-prompt; do
  check "custom claude link: $s" resolves_to "$CD/skills/$s" "$REPO/skills/$s"
done
check "custom CLAUDE.md linked" resolves_to "$CD/CLAUDE.md" "$REPO/global/claude/CLAUDE.md"
check "default ~/.claude left alone" not test -e "$H/.claude/skills"
check "default ~/.claude has no CLAUDE.md" not test -e "$H/.claude/CLAUDE.md"
OUT=$(runc --apply --harness claude-code 2>&1)
check "second apply changes nothing" has "$OUT" 'link/write=0'
CD="$H/does-not-exist"
OUT=$(runc --apply --harness claude-code 2>&1); RC=$?
check "missing custom folder skips with a warning" has "$OUT" "$CD not found"
check "missing custom folder is not created" [ ! -e "$CD" ]
check "missing custom folder exits 0" [ "$RC" -eq 0 ]
CD=""
OUT=$(runc --apply --harness claude-code 2>&1)
check "empty CLAUDE_CONFIG_DIR falls back to ~/.claude" resolves_to "$H/.claude/skills/agentd-pr-prep" "$REPO/skills/agentd-pr-prep"
new_home
mkdir -p "$H/.claude-work"
CD='~/.claude-work'
OUT=$(runc --apply --harness claude-code 2>&1); RC=$?
check "a quoted leading ~ is expanded to HOME" resolves_to "$H/.claude-work/skills/agentd-pr-prep" "$REPO/skills/agentd-pr-prep"
CD='.claude-work'
OUT=$(cd "$H" && runc --apply --harness claude-code 2>&1); RC=$?
check "a relative CLAUDE_CONFIG_DIR is refused with a warning" has "$OUT" 'must be an absolute path'
check "a relative CLAUDE_CONFIG_DIR exits 0" [ "$RC" -eq 0 ]
check "a relative CLAUDE_CONFIG_DIR links nothing in the default folder" not test -e "$H/.claude/skills"

echo "8. Several Claude Code config folders in one run"
new_home
mkdir -p "$H/.claude-work" "$H/.claude-other" "$H/.agents"
printf '# my Claude Code folders\n\n%s\n~/.claude-work\n%s' "$H/.claude" "$H/.claude-other" >"$H/.agents/claude-config-dirs"
runl() { env -u CLAUDE_CONFIG_DIR -u CLAUDE_CONFIG_DIRS HOME=$H PATH="$H/bin:$PATH" "$REPO/install.sh" "$@"; }
OUT=$(runl --harness claude-code 2>&1); RC=$?
check "dry run plans the folders in the list file" has "$OUT" "$H/.claude-work/skills/agentd-pr-prep"
check "dry run creates nothing in a listed folder" [ ! -e "$H/.claude-work/skills" ]
OUT=$(runl --apply --harness claude-code 2>&1); RC=$?
check "list file: apply exits 0" [ "$RC" -eq 0 ]
for d in .claude .claude-work .claude-other; do
  check "list file links skills in $d" resolves_to "$H/$d/skills/agentd-pr-prep" "$REPO/skills/agentd-pr-prep"
  check "list file links CLAUDE.md in $d" resolves_to "$H/$d/CLAUDE.md" "$REPO/global/claude/CLAUDE.md"
done
OUT=$(runl --apply --harness claude-code 2>&1)
check "list file: second apply changes nothing" has "$OUT" 'link/write=0'
# The variable adds to the list, and a folder named twice is linked once.
OUT=$(env HOME=$H PATH="$H/bin:$PATH" CLAUDE_CONFIG_DIR="$H/.claude-work" "$REPO/install.sh" --harness claude-code 2>&1)
check "CLAUDE_CONFIG_DIR plus the list: nothing to change" has "$OUT" 'link/write=0'
check "a folder named twice is planned once" test "$(printf '%s\n' "$OUT" | grep -c "$H/.claude-work/CLAUDE.md")" -le 1
new_home
mkdir -p "$H/.claude-a" "$H/.claude-b"
OUT=$(env -u CLAUDE_CONFIG_DIR HOME=$H PATH="$H/bin:$PATH" CLAUDE_CONFIG_DIRS="$H/.claude-a:$H/.claude-b" "$REPO/install.sh" --apply --harness claude-code 2>&1)
check "CLAUDE_CONFIG_DIRS links the first folder" resolves_to "$H/.claude-a/skills/agentd-pr-prep" "$REPO/skills/agentd-pr-prep"
check "CLAUDE_CONFIG_DIRS links the second folder" resolves_to "$H/.claude-b/skills/agentd-pr-prep" "$REPO/skills/agentd-pr-prep"
check "CLAUDE_CONFIG_DIRS leaves ~/.claude alone" not test -e "$H/.claude/skills"
new_home
mkdir -p "$H/.agents"
printf '%s\n%s\n' "$H/missing" "$H/.claude" >"$H/.agents/claude-config-dirs"
OUT=$(runl --apply --harness claude-code 2>&1); RC=$?
check "a missing listed folder warns" has "$OUT" "$H/missing not found"
check "a missing listed folder does not stop the others" resolves_to "$H/.claude/skills/agentd-pr-prep" "$REPO/skills/agentd-pr-prep"
check "a missing listed folder exits 0" [ "$RC" -eq 0 ]
check "a missing listed folder is not created" [ ! -e "$H/missing" ]

echo "9. Warning about an unlisted Claude Code folder"
new_home
mkdir -p "$H/.claude-work/skills" "$H/.claude-empty"
OUT=$(runl --apply --harness claude-code 2>&1); RC=$?
check "an unlisted folder with skills gets a warning" has "$OUT" "$H/.claude-work holds skills or a CLAUDE.md but is not linked"
check "an unlisted folder with skills is not linked" [ ! -e "$H/.claude-work/skills/agentd-pr-prep" ]
check "an unlisted empty folder gets no warning" not has "$OUT" "$H/.claude-empty holds"
check "the warning does not change the exit status" [ "$RC" -eq 0 ]
check "a listed folder gets no warning" not has "$OUT" "$H/.claude holds"
mkdir -p "$H/.agents"
printf '%s\n' "$H/.claude" "$H/.claude-work" >"$H/.agents/claude-config-dirs"
OUT=$(runl --apply --harness claude-code 2>&1)
check "listing the folder removes the warning" not has "$OUT" "holds skills or a CLAUDE.md"
check "listing the folder links it" resolves_to "$H/.claude-work/skills/agentd-pr-prep" "$REPO/skills/agentd-pr-prep"

echo "10. the skill gate (Copilot and Codex)"
PV=0
GH=$(mktemp -d)
mkdir -p "$GH/.agents"
ln -s "$REPO/skills" "$GH/.agents/skills"
# Another kit's skill with an agentd- name, without this repository's hook line.
mkdir -p "$GH/other/agentd-tasks"
printf -- '---\nname: agentd-tasks\ndescription: x\n---\nbody\n' >"$GH/other/agentd-tasks/SKILL.md"
# gate HARNESS EVENT JSON: run the hook as that harness, with a throwaway HOME for the markers.
gate() { printf '%s' "$3" | HOME=$GH "$TEST_HOOK" --harness "$1" --event "$2"; }
cp_tool() { jq -cn --arg s "$1" --arg c "$2" '{sessionId:$s,toolName:"bash",toolArgs:{command:$c}}'; }
cp_prompt() { jq -cn --arg s "$1" --arg p "$2" '{sessionId:$s,prompt:$p}'; }
cx_tool() { jq -cn --arg s "$1" --arg c "$2" '{session_id:$s,hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}'; }
cx_prompt() { jq -cn --arg s "$1" --arg p "$2" '{session_id:$s,hook_event_name:"UserPromptSubmit",prompt:$p}'; }

check "copilot: no agentd skill yet, a dangerous command passes through" test -z "$(gate copilot tool "$(cp_tool s1 'git push')")"
check "copilot: an ordinary prompt does not wake the gate" test -z "$(gate copilot prompt "$(cp_prompt s1 'fix the login bug')")"
check "copilot: still dormant after an ordinary prompt" test -z "$(gate copilot tool "$(cp_tool s1 'git push')")"
check "copilot: the prompt hook prints nothing" test -z "$(gate copilot prompt "$(cp_prompt s1 '/agentd-diagnose login fails')")"
check "copilot: /agentd-<name> writes a marker" [ -e "$GH/.agents/hook-state/s1" ]
check "copilot: the marker folder is private" test "$(stat -f %Lp "$GH/.agents/hook-state" 2>/dev/null || stat -c %a "$GH/.agents/hook-state")" = 700
check "copilot: after /agentd-, a dangerous command is denied" \
  test "$(gate copilot tool "$(cp_tool s1 'git push')" | jq -r .permissionDecision)" = deny
check "copilot: after /agentd-, a removal asks" \
  test "$(gate copilot tool "$(cp_tool s1 'rm -f x')" | jq -r .permissionDecision)" = ask
check "copilot: the flat shape, no hookSpecificOutput" not has "$(gate copilot tool "$(cp_tool s1 'git push')")" hookSpecificOutput
check "copilot: another session stays dormant" test -z "$(gate copilot tool "$(cp_tool s2 'git push')")"
check "copilot: session end prints nothing and keeps the marker" bash -c '[ -z "$1" ] && [ -e "$2" ]' _ \
  "$(gate copilot end '{"sessionId":"s1","reason":"complete"}')" "$GH/.agents/hook-state/s1"
check "copilot: a resumed session (same ID) is still checked" \
  test "$(gate copilot tool "$(cp_tool s1 'git push')" | jq -r .permissionDecision)" = deny
check "copilot: the skill tool for agentd-<name> writes a marker and prints nothing" bash -c '[ -z "$1" ] && [ -e "$2" ]' _ \
  "$(gate copilot tool '{"sessionId":"s3","toolName":"skill","toolArgs":{"skill":"agentd-dev-rev"}}')" "$GH/.agents/hook-state/s3"
check "copilot: after the skill tool, a dangerous command is denied" \
  test "$(gate copilot tool "$(cp_tool s3 'git push')" | jq -r .permissionDecision)" = deny
check "copilot: another skill does not wake the gate" bash -c '[ -z "$1" ] && [ ! -e "$2" ]' _ \
  "$(gate copilot tool '{"sessionId":"s4","toolName":"skill","toolArgs":{"skill":"brainstorming"}}')" "$GH/.agents/hook-state/s4"
gate copilot prompt "$(cp_prompt '../../evil' '/agentd-intake')" >/dev/null
check "copilot: a session ID cannot leave the marker folder" \
  bash -c '[ -e "$1/.agents/hook-state/evil" ] && [ ! -e "$1/evil" ] && [ ! -e "$1/.agents/evil" ]' _ "$GH"
check "copilot: a missing session ID runs the rules while any marker exists" \
  test "$(gate copilot tool '{"toolName":"bash","toolArgs":{"command":"git push"}}' 2>/dev/null | jq -r .permissionDecision)" = deny
check "copilot: a missing session ID prints a warning" \
  has "$(gate copilot tool '{"toolName":"bash","toolArgs":{"command":"ls"}}' 2>&1 >/dev/null)" 'could not read the session ID'
check "codex: a missing session ID prints a warning" \
  has "$(gate codex tool '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"ls"}}' 2>&1 >/dev/null)" \
  'could not read the session ID'
check "copilot: a readable session ID prints no warning" \
  test -z "$(gate copilot tool "$(cp_tool s1 'ls')" 2>&1 >/dev/null)"
EH=$(mktemp -d)
check "copilot: a missing session ID is dormant while no marker exists" \
  test -z "$(printf '{"toolName":"bash","toolArgs":{"command":"git push"}}' | HOME=$EH "$TEST_HOOK" --harness copilot --event tool 2>/dev/null)"
check "copilot: input that is not JSON is dormant while no marker exists" \
  test -z "$(printf 'not json' | HOME=$EH "$TEST_HOOK" --harness copilot --event tool 2>/dev/null)"
# A PATH with the usual tools but no jq.
NJ=$(mktemp -d)
for t in cat find grep head ls mkdir sed tr; do ln -s "$(command -v "$t")" "$NJ/$t"; done
nojq() { printf '%s' "$2" | HOME=$GH PATH=$NJ /bin/bash "$TEST_HOOK" --harness copilot --event "$1"; }
check "copilot: missing jq on a prompt prints nothing" test -z "$(nojq prompt '{"sessionId":"j1","prompt":"/agentd-intake"}')"
check "copilot: missing jq still writes the marker from the prompt" [ -e "$GH/.agents/hook-state/j1" ]
check "copilot: missing jq in a session without a marker prints nothing" \
  test -z "$(nojq tool '{"sessionId":"j2","toolName":"bash","toolArgs":{"command":"ls"}}')"
check "copilot: missing jq in a session with a marker is denied" \
  has "$(nojq tool '{"sessionId":"j1","toolName":"bash","toolArgs":{"command":"ls"}}')" '"permissionDecision":"deny".*jq'
check "copilot: unreadable input in a session without a marker prints nothing" \
  test -z "$(gate copilot tool '{"sessionId":"u1","toolName":"bash","toolArgs":{"command":["ls"]}}')"
check "copilot: unreadable input in a session with a marker is denied" \
  test "$(gate copilot tool '{"sessionId":"s1","toolName":"bash","toolArgs":{"command":["ls"]}}' | jq -r .permissionDecision)" = deny
for p in '`/agentd-intake`' '"/agentd-intake please"' '(/agentd-intake)' '[/agentd-intake](x)' $'first line\n/agentd-intake'; do
  sid=pv$((++PV))
  gate copilot prompt "$(cp_prompt "$sid" "$p")" >/dev/null
  check "copilot: the prompt [$p] writes a marker" [ -e "$GH/.agents/hook-state/$sid" ]
done
for p in 'use the agentd-intake skill' 'see ~/.agents/skills/agentd-intake/SKILL.md' 'x/agentd-intake'; do
  sid=pv$((++PV))
  gate copilot prompt "$(cp_prompt "$sid" "$p")" >/dev/null
  check "copilot: the prompt [$p] writes no marker" [ ! -e "$GH/.agents/hook-state/$sid" ]
done
check "copilot: the view tool does not wake the gate" bash -c '[ -z "$1" ] && [ ! -e "$2" ]' _ \
  "$(gate copilot tool '{"sessionId":"v1","toolName":"view","toolArgs":{"path":"/Users/x/.agents/skills/agentd-intake/SKILL.md"}}')" \
  "$GH/.agents/hook-state/v1"
check "copilot: the skill tool with toolArgs as a JSON string writes a marker" bash -c '[ -e "$1" ]' _ \
  "$GH/.agents/hook-state/v2" "$(gate copilot tool '{"sessionId":"v2","toolName":"skill","toolArgs":"{\"skill\":\"agentd-intake\"}"}')"
RO=$(mktemp -d)
mkdir -p "$RO/.agents"
ln -s "$REPO/skills" "$RO/.agents/skills"
chmod 500 "$RO/.agents"
check "copilot: a marker that cannot be written prints a warning" \
  has "$(printf '{"sessionId":"r1","prompt":"/agentd-intake"}' | HOME=$RO "$TEST_HOOK" --harness copilot --event prompt 2>&1)" 'could not write'
chmod 700 "$RO/.agents"
mkdir -p "$GH/.agents/hook-state" && : >"$GH/.agents/hook-state/old1" && touch -t 202001010000 "$GH/.agents/hook-state/old1"
gate copilot prompt "$(cp_prompt s7 '/agentd-intake')" >/dev/null
check "copilot: a marker older than 30 days is removed when a skill starts" [ ! -e "$GH/.agents/hook-state/old1" ]
check "copilot: the new marker is kept" [ -e "$GH/.agents/hook-state/s7" ]
touch -t 202001010000 "$GH/.agents/hook-state/s7"
gate copilot tool "$(cp_tool s7 'ls')" >/dev/null
check "copilot: a checked command refreshes the marker's time" test -z "$(find "$GH/.agents/hook-state/s7" -mtime +30)"
check "copilot: an unknown agentd-<name> does not wake the gate" bash -c '[ ! -e "$1" ]' _ "$GH/.agents/hook-state/w1" \
  "$(gate copilot prompt "$(cp_prompt w1 '/agentd-repo is my folder')")"
TH=$(mktemp -d)
mkdir -p "$TH/.agents/skills"
ln -s "$GH/other/agentd-tasks" "$TH/.agents/skills/agentd-tasks"
ln -s "$REPO/skills/agentd-intake" "$TH/.agents/skills/agentd-intake"
tgate() { printf '%s' "$3" | HOME=$TH "$TEST_HOOK" --harness "$1" --event "$2"; }
tgate copilot prompt "$(cp_prompt w2 '/agentd-tasks list')" >/dev/null
check "copilot: another kit's agentd-tasks skill does not wake the gate" [ ! -e "$TH/.agents/hook-state/w2" ]
tgate copilot tool '{"sessionId":"w3","toolName":"skill","toolArgs":{"skill":"agentd-tasks"}}' >/dev/null
check "copilot: the skill tool for another kit's agentd-tasks does not wake the gate" [ ! -e "$TH/.agents/hook-state/w3" ]
tgate codex tool "$(cx_tool w4 'grep -rn TODO skills/agentd-intake/SKILL.md')" >/dev/null
check "codex: grep on an agentd SKILL.md does not wake the gate" [ ! -e "$TH/.agents/hook-state/w4" ]
tgate codex tool "$(cx_tool w5 'git add skills/agentd-intake/SKILL.md')" >/dev/null
check "codex: git add of an agentd SKILL.md does not wake the gate" [ ! -e "$TH/.agents/hook-state/w5" ]
tgate codex tool "$(cx_tool w6 'sed -n 1,40p ~/.agents/skills/agentd-intake/SKILL.md')" >/dev/null
check "codex: sed reading an agentd SKILL.md wakes the gate" [ -e "$TH/.agents/hook-state/w6" ]
tgate codex tool "$(cx_tool w7 'cat ~/.agents/skills/agentd-tasks/SKILL.md')" >/dev/null
check "codex: reading another kit's agentd-tasks SKILL.md does not wake the gate" [ ! -e "$TH/.agents/hook-state/w7" ]
nojqt() { printf '%s' "$2" | HOME=$TH PATH=$NJ /bin/bash "$TEST_HOOK" --harness copilot --event "$1"; }
check "copilot: missing jq, the skill tool still wakes the gate" bash -c '[ -z "$1" ] && [ -e "$2" ]' _ \
  "$(nojqt tool '{"sessionId":"n1","toolName":"skill","toolArgs":{"skill":"agentd-intake"}}')" "$TH/.agents/hook-state/n1"
nojqt prompt "$(cp_prompt n2 $'please look\n/agentd-intake now')" >/dev/null
check "copilot: missing jq, /agentd-<name> on a later prompt line still wakes the gate" [ -e "$TH/.agents/hook-state/n2" ]
check "copilot: missing jq, the first session ID is used, not a later one" \
  test -z "$(nojqt tool '{"sessionId":"n3","toolName":"bash","toolArgs":{"command":"ls","session_id":"n1"}}')"

check "codex: no agentd skill yet, a dangerous command passes through" test -z "$(gate codex tool "$(cx_tool c1 'git push')")"
gate codex prompt "$(cx_prompt c1 'please run $agentd-diagnose on the login bug')" >/dev/null
check "codex: \$agentd-<name> in the prompt writes a marker" [ -e "$GH/.agents/hook-state/c1" ]
check "codex: after \$agentd-, a dangerous command is denied" \
  test "$(gate codex tool "$(cx_tool c1 'git push')" | jq -r .hookSpecificOutput.permissionDecision)" = deny
check "codex: an ask becomes a deny" \
  test "$(gate codex tool "$(cx_tool c1 'git commit -m x')" | jq -r .hookSpecificOutput.permissionDecision)" = deny
check "codex: the deny says Codex cannot ask" \
  has "$(gate codex tool "$(cx_tool c1 'rm -f x')" | jq -r .hookSpecificOutput.permissionDecisionReason)" 'Codex hooks cannot ask'
check "codex: an ordinary command gets no output" test -z "$(gate codex tool "$(cx_tool c1 'ls -la')")"
gate codex end '{"session_id":"c1","hook_event_name":"SessionEnd"}' >/dev/null
check "codex: session end keeps the marker" [ -e "$GH/.agents/hook-state/c1" ]
for p in '`$agentd-intake`' '"$agentd-intake"' '($agentd-intake)' '[$agentd-intake](/x/SKILL.md)'; do
  sid=cv$((++PV))
  gate codex prompt "$(cx_prompt "$sid" "$p")" >/dev/null
  check "codex: the prompt [$p] writes a marker" [ -e "$GH/.agents/hook-state/$sid" ]
done
check "codex: reading an agentd SKILL.md in a shell command writes a marker" bash -c '[ -z "$1" ] && [ -e "$2" ]' _ \
  "$(gate codex tool "$(cx_tool q1 'cat ~/.agents/skills/agentd-intake/SKILL.md')")" "$GH/.agents/hook-state/q1"
check "codex: after reading the skill file, a dangerous command is denied" \
  test "$(gate codex tool "$(cx_tool q1 'git push')" | jq -r .hookSpecificOutput.permissionDecision)" = deny

check "claude: never gated, a dangerous command is denied" \
  test "$(gate claude tool "$(cx_tool k1 'git push')" | jq -r .hookSpecificOutput.permissionDecision)" = deny
check "claude: an ask stays an ask" \
  test "$(gate claude tool "$(cx_tool k1 'git commit -m x')" | jq -r .hookSpecificOutput.permissionDecision)" = ask
check "claude: writes no marker" [ ! -e "$GH/.agents/hook-state/k1" ]

echo "11. Codex harness"
new_home
OUT=$(run --harness codex-cli 2>&1); RC=$?
check "dry run plans hooks.json" has "$OUT" "$H/.codex/hooks.json"
check "dry run writes nothing" [ ! -e "$H/.codex/hooks.json" ]
OUT=$(run --apply --harness codex-cli 2>&1); RC=$?
check "apply exits 0" [ "$RC" -eq 0 ]
check "hooks.json written" jq -e . "$H/.codex/hooks.json"
check "hooks.json has the prompt and tool entries, and no session-end entry" \
  test "$(jq -r '[(.hooks.UserPromptSubmit | length), (.hooks.PreToolUse | length), (.hooks | has("SessionEnd"))] | map(tostring) | join(",")' "$H/.codex/hooks.json")" = "1,1,false"
check "the plan reminds the engineer to trust the hook" has "$OUT" '/hooks'
check "--harness codex-cli leaves Claude and Copilot alone" \
  bash -c '[ ! -e "$1/.claude/skills" ] && [ ! -e "$1/.copilot/hooks" ]' _ "$H"
OUT=$(run --apply --harness codex-cli 2>&1)
check "second apply changes nothing" has "$OUT" 'link/write=0'
new_home
printf '{"hooks":{}}\n' >"$H/.codex/hooks.json"
OUT=$(run --apply --harness codex-cli 2>&1); RC=$?
check "an existing different hooks.json is a CONFLICT" has "$OUT" 'CONFLICT.*hooks.json'
check "the existing hooks.json is left alone" test "$(cat "$H/.codex/hooks.json")" = '{"hooks":{}}'
new_home nocopilot
OUT=$(run --apply --harness codex-cli 2>&1)
check "missing ~/.codex skips with a warning" has "$OUT" '.codex not found'

echo "12. Upgrade from the older ungated Copilot hook"
new_home
mkdir -p "$H/.copilot/hooks"
ln -s "$REPO/hooks/copilot/block-dangerous-shell.sh" "$H/.copilot/hooks/block-dangerous-shell.sh"
# The git-safety.json that older installs wrote: no flags, every Copilot session checked.
printf '{\n  "version": 1,\n  "hooks": {\n    "preToolUse": [\n      {\n        "type": "command",\n        "matcher": "bash|powershell",\n        "bash": "%s/.copilot/hooks/block-dangerous-shell.sh",\n        "timeoutSec": 5\n      }\n    ]\n  }\n}\n' "$H" \
  >"$H/.copilot/hooks/git-safety.json"
OUT=$(run --apply --harness copilot-cli 2>&1); RC=$?
check "the older git-safety.json is a CONFLICT" has "$OUT" 'CONFLICT.*git-safety.json'
check "without --adopt it exits 1" [ "$RC" -eq 1 ]
OUT=$(run --apply --adopt --harness copilot-cli 2>&1); RC=$?
check "--adopt replaces it and exits 0" [ "$RC" -eq 0 ]
check "the new git-safety.json is gated" grep -q -- '--harness copilot' "$H/.copilot/hooks/git-safety.json"
BK=$(ls -d "$H"/.agent-skills-backup/*/ 2>/dev/null | head -n 1)
check "the older git-safety.json is in the backup folder" grep -q 'copilot/hooks/block-dangerous-shell.sh"' "${BK}.copilot/hooks/git-safety.json"
check "the older script link is left in place" [ -L "$H/.copilot/hooks/block-dangerous-shell.sh" ]

echo "13. HOME that the hook command cannot quote"
new_home
H="$H/q\"x"
mkdir -p "$H/.claude" "$H/.copilot" "$H/.codex" "$H/bin"
printf '#!/bin/sh\necho "GitHub Copilot CLI 1.0.101."\n' >"$H/bin/copilot"
chmod +x "$H/bin/copilot"
OUT=$(run --apply --harness copilot-cli,codex-cli 2>&1); RC=$?
check "a HOME with a double quote: apply exits 0" [ "$RC" -eq 0 ]
check "a HOME with a double quote: warns" has "$OUT" 'cannot quote'
check "a HOME with a double quote: no git-safety.json" [ ! -e "$H/.copilot/hooks/git-safety.json" ]
check "a HOME with a double quote: no codex hooks.json" [ ! -e "$H/.codex/hooks.json" ]

echo
echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
