#!/usr/bin/env bash
# Cross-skill check: the four skills that use a git worktree carry the same rules, so their copies do not drift.
# diagnose, blast-radius, dev-rev and pr-review each add a worktree in a scratch folder instead of using git archive.
# Each skill words the rules its own way, so this checks key phrases, not identical paragraphs. Writes nothing.
# Usage: tests/test-worktree-rules.sh
set -u

HERE=$(cd "$(dirname "$0")" && pwd -P)
REPO=$(cd "$HERE/.." && pwd -P)
SKILLS="agentd-diagnose agentd-blast-radius agentd-dev-rev agentd-pr-review"
PASS=0
FAIL=0

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

# text_of <skill>: the SKILL.md of a skill on one line, so a phrase may wrap across lines.
text_of() { tr '\n' ' ' <"$REPO/skills/$1/SKILL.md" | tr -s ' '; }

# every_skill_has <phrase>: all four skills hold the phrase, ignoring case.
every_skill_has() {
  local s
  for s in $SKILLS; do
    text_of "$s" | grep -qiF -- "$1" || { echo "missing in $s: $1"; return 1; }
  done
}

# no_skill_has <phrase>: none of the four skills holds the phrase.
no_skill_has() {
  local s
  for s in $SKILLS; do
    ! text_of "$s" | grep -qiF -- "$1" || { echo "found in $s: $1"; return 1; }
  done
}

test_hooks_are_turned_off_for_every_add() {
  local s
  every_skill_has 'core.hooksPath=/dev/null' || return 1
  for s in $SKILLS; do
    # Every worktree add command with a path sits behind the option. The bare name in a list of commands is exempt.
    ! text_of "$s" | grep -oE 'git (-c [^ ]+ )?worktree add --detach <' | grep -qv 'core.hooksPath=/dev/null' ||
      { echo "an add without the option in $s"; return 1; }
  done
}

test_prune_is_only_ever_forbidden() {
  local s f
  for s in $SKILLS; do
    f="$REPO/skills/$s"
    [ "$(cat "$f/SKILL.md" "$f"/references/*.md 2>/dev/null | grep -o 'git worktree prune' | wc -l | tr -d ' ')" -eq \
      "$(cat "$f/SKILL.md" "$f"/references/*.md 2>/dev/null | grep -o 'Never run `git worktree prune`' | wc -l | tr -d ' ')" ] ||
      { echo "prune is not only forbidden in $s"; return 1; }
  done
  every_skill_has 'Never run `git worktree prune`'
}

test_each_worktree_is_removed_by_the_skill() {
  # diagnose and blast-radius do not name rm-scratch: they say to remove the scratch folder, and the user's global rule
  # says how. dev-rev and pr-review name it.
  every_skill_has 'git worktree remove --force' && every_skill_has 'scratch folder'
}

test_git_archive_is_only_a_fallback_when_the_command_is_unavailable() {
  every_skill_has 'Only if the `git worktree` command is unavailable' &&
    every_skill_has 'fall back to `git archive` then' &&
    every_skill_has 'no submodules'
}

test_a_failed_add_or_setup_is_unknown() {
  every_skill_has 'fails at setup' && every_skill_has '`unknown:`'
}

test_submodule_update_and_lfs_are_disclosed() {
  every_skill_has 'submodule update --init' && every_skill_has '.git/config' && every_skill_has 'git-lfs'
}

test_no_skill_runs_repository_hooks_or_prunes() {
  no_skill_has 'post-checkout' && no_skill_has 'then run `git worktree prune`' && no_skill_has 'run `git worktree prune` in the run plan'
}

echo "worktree rules across diagnose, blast-radius, dev-rev and pr-review"
check "every add turns the repository's hooks off" test_hooks_are_turned_off_for_every_add
check "git worktree prune is only ever forbidden" test_prune_is_only_ever_forbidden
check "each skill removes the worktree it added, then the scratch folder" test_each_worktree_is_removed_by_the_skill
check "git archive is only a fallback when the worktree command is unavailable" test_git_archive_is_only_a_fallback_when_the_command_is_unavailable
check "a failed add, update or setup gives unknown" test_a_failed_add_or_setup_is_unknown
check "the submodule update, its .git/config write and LFS are disclosed" test_submodule_update_and_lfs_are_disclosed
check "no skill runs repository hooks or prunes" test_no_skill_runs_repository_hooks_or_prunes

echo
echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
