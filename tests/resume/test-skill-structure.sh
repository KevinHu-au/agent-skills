#!/usr/bin/env bash
# Structure and wording tests for the agentd-resume skill file. Reads the skill file and writes nothing.
# Usage: tests/resume/test-skill-structure.sh
set -u

HERE=$(cd "$(dirname "$0")" && pwd -P)
REPO=$(cd "$HERE/../.." && pwd -P)
SKILL="${SKILL:-$REPO/skills/agentd-resume/SKILL.md}"
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

# frontmatter_value <key>: the value of a key in the first frontmatter block of SKILL.md.
frontmatter_value() {
  awk -v k="$1" '
    NR == 1 && $0 != "---" { exit 1 }
    /^---[ \t]*$/ { c++; if (c == 2) exit; next }
    c == 1 && index($0, k ": ") == 1 { print substr($0, length(k) + 3); exit }
  ' "$SKILL"
}

# h2_list: the H2 headings of SKILL.md, in order, one per line. A heading inside a fenced block does not count.
h2_list() {
  awk '
    /^[ ]*(```|~~~)/ { f = !f; next }
    !f && /^## / { sub(/^## /, ""); sub(/[ \t]+$/, ""); print }
  ' "$SKILL"
}

# section_of <heading>: the lines under one H2 heading of SKILL.md. A heading inside a fenced block does not end it.
section_of() {
  awk -v h="## $1" '
    /^[ ]*(```|~~~)/ { f = !f; if (on) print; next }
    !f && $0 == h { on = 1; next }
    !f && /^## / { on = 0 }
    on
  ' "$SKILL"
}

# section_has <heading> <text>...: the section contains every text, ignoring case and line breaks.
section_has() {
  local body t
  body=$(section_of "$1" | tr '\n' ' ' | tr -s ' ')
  [ -n "$body" ] || return 1
  shift
  for t in "$@"; do printf '%s\n' "$body" | grep -qiF -- "$t" || return 1; done
}

# one_line: SKILL.md on one line, so a phrase may wrap across lines.
one_line() { tr '\n' ' ' <"$SKILL" | tr -s ' '; }

# has_all <text>...: SKILL.md contains every text, ignoring case and line breaks.
has_all() {
  local body t
  body=$(one_line)
  for t in "$@"; do printf '%s\n' "$body" | grep -qiF -- "$t" || return 1; done
}

test_frontmatter_name_matches_folder() {
  [ "$(frontmatter_value name)" = "agentd-resume" ] && [ "$(basename "$(dirname "$SKILL")")" = "agentd-resume" ]
}

test_description_starts_with_use_when() {
  case "$(frontmatter_value description)" in "Use when "*) ;; *) return 1 ;; esac
}

test_skill_is_manual_only() {
  awk 'NR == 1 && $0 != "---" { exit } /^---[ \t]*$/ { c++; if (c == 2) exit; next } c == 1' "$SKILL" |
    grep -qx 'disable-model-invocation: true'
}

test_skill_is_at_most_140_lines() {
  [ "$(wc -l <"$SKILL" | tr -d ' ')" -le 140 ]
}

test_required_h2_sections_in_order() {
  [ "$(h2_list | tr '\n' '|')" = \
    "Step 1: Find the hand-off file|Step 2: Check the current state|Step 3: Report and confirm|Step 4: Carry on|Rules|" ]
}

test_no_absolute_home_paths() {
  ! grep -qE '/Users/|/home/' "$SKILL"
}

test_it_never_commits_or_pushes() {
  has_all 'never commits, never pushes, and never changes git state to make the check pass' &&
    ! grep -qE 'git (commit|push|add) ' "$SKILL"
}

test_the_hand_off_file_is_found_and_never_guessed() {
  section_has "Step 1: Find the hand-off file" 'docs/handoff/' 'onboarding-pack' 'find' 'newest date first' \
    'Never guess between files' 'is not a hand-off file' 'how long ago' 'starts at the repository root' 'in both places' 'exit status 1 means no pack' \
    'ask for the path'
}

test_the_check_is_read_only_and_covers_each_header_line() {
  section_has "Step 2: Check the current state" 'only read-only commands' '`pwd`' '`Folder:`' '`Repository:`' '`Branch:`' \
    '`Commit:`' '`Working tree:`' 'git merge-base --is-ancestor' 'ignoring the hand-off file itself' \
    'test -e' 'cannot tell' 'blocker' 'detached at <sha>' 'git cat-file -e' 'diverged' 'behind' \
    'starts with `unknown:`' 'non-zero' 'full hashes' 'is not 0 or 1' '--is-shallow-repository' 'checked for absence' 'does not show that the change is still in the file'
}

test_the_report_has_a_verdict_and_never_repairs_state() {
  section_has "Step 3: Report and confirm" '`matches`, `differs` or `cannot tell`' '**Matches:**' '**Differs:**' \
    '**Cannot tell:**' 'It wins over Cannot tell' 'Never run `git checkout`' '`git reset`' 'let the engineer run it' \
    'carry on with the steps as written, change them first, or stop' 'Start no step' 'open blocker' \
    'depends on an open blocker'
}

test_carrying_on_respects_the_file() {
  section_has "Step 4: Carry on" '`Do not touch`' 'do not do its work here' 'paste the block' \
    'Stop condition' 'The code wins' 'Do not change the hand-off file' '/agentd-handoff'
}

test_no_secrets_or_personal_data() {
  section_has "Rules" 'No secrets, tokens, connection strings or personal data' '[removed]'
}

test_plain_writing_has_no_dash_asides_or_filler() {
  ! grep -q '—' "$SKILL" && ! grep -qi 'keep it tight' "$SKILL"
}

# The headers this skill reads must still be written by agentd-handoff.
test_every_header_it_reads_is_written_by_handoff() {
  local h="$REPO/skills/agentd-handoff/SKILL.md" t
  local d="$REPO/skills/agentd-diagnose/references/report-template.md"
  grep -qF 'Stop condition' "$d" && grep -qF '`**Confidence:** hypothesis, not confirmed`' "$d" || return 1
  for t in '`Stopped:`' 'Do not touch' '`Folder:`' '`Repository:`' '`Branch:`' '`Commit:`' '`Working tree:`' '## Next steps' \
    '## For the agent' '## Status so far'; do
    tr '\n' ' ' <"$h" | tr -s ' ' | grep -qF -- "$t" || return 1
  done
}

check "frontmatter name matches the folder" test_frontmatter_name_matches_folder
check "description starts with Use when" test_description_starts_with_use_when
check "the skill is manual-only" test_skill_is_manual_only
check "SKILL.md is at most 140 lines" test_skill_is_at_most_140_lines
check "H2 sections in order" test_required_h2_sections_in_order
check "no absolute home paths" test_no_absolute_home_paths
check "it never commits or pushes" test_it_never_commits_or_pushes
check "the hand-off file is found and never guessed" test_the_hand_off_file_is_found_and_never_guessed
check "the check is read only and covers each header line" test_the_check_is_read_only_and_covers_each_header_line
check "the report has a verdict and never repairs state" test_the_report_has_a_verdict_and_never_repairs_state
check "carrying on respects the file" test_carrying_on_respects_the_file
check "no secrets or personal data" test_no_secrets_or_personal_data
check "plain writing: no dash asides, no filler" test_plain_writing_has_no_dash_asides_or_filler
check "every header it reads is written by agentd-handoff" test_every_header_it_reads_is_written_by_handoff

echo
echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
