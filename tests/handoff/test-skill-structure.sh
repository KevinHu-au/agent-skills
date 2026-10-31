#!/usr/bin/env bash
# Structure and wording tests for the agentd-handoff skill file. Reads the skill file and writes nothing.
# Usage: tests/handoff/test-skill-structure.sh
set -u

HERE=$(cd "$(dirname "$0")" && pwd -P)
REPO=$(cd "$HERE/../.." && pwd -P)
SKILL="${SKILL:-$REPO/skills/agentd-handoff/SKILL.md}"
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
  [ "$(frontmatter_value name)" = "agentd-handoff" ] && [ "$(basename "$(dirname "$SKILL")")" = "agentd-handoff" ]
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
    "Step 1: Collect the state|Step 2: Find the session|Step 3: Show the next steps|Step 4: Choose the folder and write|The file|Rules|" ]
}

test_no_absolute_home_paths() {
  ! grep -qE '/Users/|/home/' "$SKILL"
}

test_it_edits_no_code_and_never_commits_or_pushes() {
  has_all 'edits no code, never commits, never pushes, and runs no build or test' &&
    ! grep -qE 'git (commit|push|add|checkout|stash)' "$SKILL"
}

test_state_comes_from_read_only_commands_and_the_session() {
  section_has "Step 1: Collect the state" 'only read-only commands' "date '+%Y-%m-%d %H:%M %Z'" \
    'git status --short -uall' 'clean or dirty' 'word for word' '`[removed]`' '`pwd`' 'Never invent a change, a result or a step' 'when a git command fails' \
    'unknown:'
}

test_claude_session_id_comes_from_the_environment() {
  section_has "Step 2: Find the session" 'CLAUDE_CODE_SESSION_ID' 'claude --resume <session-id>'
}

test_copilot_session_id_comes_from_workspace_yaml() {
  section_has "Step 2: Find the session" '~/.copilot/session-state/<session-id>/' 'workspace.yaml' \
    'whose `cwd` is this folder' 'exactly one folder matches' 'cannot pick between two' 'more than one matches' \
    'copilot --resume=<session-id>'
}

test_an_unknown_session_id_is_never_guessed() {
  section_has "Step 2: Find the session" 'Never guess an ID' 'only the fresh-start prompt'
}

test_next_steps_are_shown_and_corrected_before_writing() {
  section_has "Step 3: Show the next steps" 'Before you write the file' 'numbered next steps' \
    'how to tell it is done' 'Do not change' 'wait' 'did not check them'
}

test_folder_follows_the_repo_policy() {
  section_has "Step 4: Choose the folder and write" 'Repo policy:' '`docs/handoff/` at the repository root' \
    'git rev-parse --git-path info/exclude' 'Do not edit `.gitignore`' 'handoff/` inside the pack folder' \
    'not even `.git/info/exclude`' 'ask the engineer once' 'the pack inside the repository' \
    'Exit status 1 means no pack is recorded' 'stays on this machine' 'git ls-files docs/handoff' \
    '| committed |' '| local only |' '| none |'
}

test_file_name_is_date_and_slug_with_a_counter() {
  section_has "Step 4: Choose the folder and write" '<date>-<task-slug>.md' 'YYYY-MM-DD' 'not from the branch name' \
    '`-2`, then `-3`' 'Never change or overwrite an earlier hand-off'
}

test_file_has_the_header_and_the_three_parts() {
  [ "$(section_of "The file" | grep -c '^[0-9]\. `')" -eq 4 ] &&
    section_has "The file" 'Stopped:' 'timezone' 'Session:' '`name` from `workspace.yaml`' 'Folder:' 'detached at <sha>' 'Branch:' 'Commit:' 'Working tree:' 'Repo policy:' \
      '## Status so far' '## Next steps' '## For the agent' 'Blockers and questions' 'Do not touch'
}

test_fresh_start_prompt_checks_the_branch_and_does_not_redo_work() {
  section_has "The file" 'fresh-start prompt' 'by its path' 'Read the file at that path first' 'git rev-parse --abbrev-ref HEAD' \
    'git status --short -uall' 'ignoring the hand-off file itself' 'say what differs' 'Not redo the finished work' 'Start at next step 1' 'Stop and ask when something does not match'
}

test_no_secrets_or_personal_data_in_the_file() {
  section_has "Rules" 'No secrets, tokens, connection strings or personal data' 'Name a configuration key, never its value'
}

test_plain_writing_has_no_dash_asides_or_filler() {
  ! grep -q '—' "$SKILL" && ! grep -qi 'keep it tight' "$SKILL"
}

check "frontmatter name matches the folder" test_frontmatter_name_matches_folder
check "description starts with Use when" test_description_starts_with_use_when
check "the skill is manual-only" test_skill_is_manual_only
check "SKILL.md is at most 140 lines" test_skill_is_at_most_140_lines
check "H2 sections in order" test_required_h2_sections_in_order
check "no absolute home paths" test_no_absolute_home_paths
check "it edits no code and never commits or pushes" test_it_edits_no_code_and_never_commits_or_pushes
check "state comes from read-only commands and the session" test_state_comes_from_read_only_commands_and_the_session
check "the Claude session ID comes from the environment" test_claude_session_id_comes_from_the_environment
check "the Copilot session ID comes from workspace.yaml" test_copilot_session_id_comes_from_workspace_yaml
check "an unknown session ID is never guessed" test_an_unknown_session_id_is_never_guessed
check "next steps are shown and corrected before writing" test_next_steps_are_shown_and_corrected_before_writing
check "the folder follows the repo policy" test_folder_follows_the_repo_policy
check "the file name is date and slug with a counter" test_file_name_is_date_and_slug_with_a_counter
check "the file has the header and the three parts" test_file_has_the_header_and_the_three_parts
check "the fresh-start prompt checks the branch and does not redo work" test_fresh_start_prompt_checks_the_branch_and_does_not_redo_work
check "no secrets or personal data in the file" test_no_secrets_or_personal_data_in_the_file
check "plain writing: no dash asides, no filler" test_plain_writing_has_no_dash_asides_or_filler

echo
echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
