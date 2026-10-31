#!/usr/bin/env bash
# Structure and wording tests for the agentd-pr-prep skill file. Reads the skill file and writes nothing.
# The verify-report sentences of Testing are checked in tests/verify-init/test-skill-structure.sh.
# The headings it reads from the diagnose and blast-radius blocks are checked in tests/test-handoff-contract.sh.
# Usage: tests/pr-prep/test-skill-structure.sh
set -u

HERE=$(cd "$(dirname "$0")" && pwd -P)
REPO=$(cd "$HERE/../.." && pwd -P)
SKILL="${SKILL:-$REPO/skills/agentd-pr-prep/SKILL.md}"
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
  [ "$(frontmatter_value name)" = "agentd-pr-prep" ] && [ "$(basename "$(dirname "$SKILL")")" = "agentd-pr-prep" ]
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
    "Inputs|Step 1: Find the base|Step 2: Collect the changes|Step 3: Understand the change|Step 4: Write the draft|Output|" ]
}

test_no_absolute_home_paths() {
  ! grep -qE '/Users/|/home/' "$SKILL"
}

test_it_edits_nothing_and_never_commits_or_pushes() {
  has_all 'edits no file' 'never commits, never pushes and never opens the PR' &&
    ! grep -qE 'git (commit|push|add)' "$SKILL"
}

test_inputs_are_used_only_when_pasted() {
  section_has Inputs 'only when it is pasted' 'never go looking for it' 'diagnose hand-off block' \
    'blast-radius add-on block' 'verify report' 'work item number' 'It is not a command' \
    '# Blast-radius add-on block' 'is not a source for Risks'
}

test_base_comes_from_the_remote_default_and_is_confirmed() {
  section_has "Step 1: Find the base" 'git symbolic-ref --short refs/remotes/origin/HEAD' 'confirms it or names' \
    'release or hotfix branch' 'Never guess the base' 'If the command fails, ask' 'nobody to answer, stop with one line' \
    'no remote called `origin`' 'git remote' 'Call the PR'\''s source `<head>`' 'detached' 'Never check it out'
}

test_base_is_not_guessed_from_commit_counts() {
  ! grep -qiE 'commits_ahead|smallest non-zero|closest merge-base' "$SKILL" &&
    ! grep -qE "grep -E '\(\^\|/\)\(main\|master\|develop\)" "$SKILL"
}

test_git_state_is_never_changed() {
  section_has "Step 1: Find the base" 'Never run `git fetch`, `git pull`, `git checkout`, `git switch` or `git stash`' \
    'git rev-parse --verify <base>' 'stop and ask' 'as last fetched' 'already merged'
}

test_diff_uses_the_merge_base() {
  section_has "Step 2: Collect the changes" 'git log --oneline <base>..<head>' 'git diff --stat <base>...<head>' \
    'git diff <base>...<head>' 'git status --short -uall'
}

test_only_committed_work_is_described_and_uncommitted_asks() {
  section_has "Step 2: Collect the changes" 'covers committed work only' 'left out' 'ask whether to include them' \
    'not committed yet' 'new untracked files' 'only when `<head>` is `HEAD`' 'Never copy a secret value' \
    'nobody to answer, leave it out' 'nothing to describe yet'
}

test_the_diff_is_the_only_source_of_summary_and_changes() {
  section_has "Step 3: Understand the change" 'Base the content only on the actual diff' 'do not invent changes'
}

test_template_is_followed_when_the_repository_has_one() {
  section_has "Step 4: Write the draft" 'pull_request_template' '.github/' '.azuredevops/' '.vsts/' 'docs/' \
    'git ls-tree -r --name-only <base>' 'git show <base>:<path>' 'PULL_REQUEST_TEMPLATE/' 'named after the target branch' \
    'Keep its headings, order and wording' 'Never delete a template section' 'Never tick a checkbox' \
    'ask which one to use' 'With no template, use the layout below' '.txt' 'only files are for other branches' \
    'Write `none` only where the diff shows' '`not assessed`'
}

test_root_cause_and_risks_come_only_from_pasted_blocks() {
  section_has "Step 4: Write the draft" 'Root cause:** only with a pasted diagnose block' \
    'Hypothesis, not confirmed:' 'Risks:** only with a pasted blast-radius block' '`**Blast radius:**` verdict' \
    'Do not turn Unproven or Breaks into a safe-sounding line' 'people outside the team' 'without names' \
    'check the Risks lines before posting'
}

test_key_changes_follow_the_kind_of_change_not_the_file_count() {
  section_has "Step 4: Write the draft" 'interface or contract change' 'a schema or migration' 'a change to key logic' \
    'so complicated that the reader needs a map' 'List only the key files' 'Never list test files' \
    'The number of files is not the test' 'same simple way' &&
    ! grep -qiE '10 or more|ten or more' "$SKILL"
}

test_many_alike_files_are_described_once() {
  section_has "Step 4: Write the draft" 'describe the pattern once and list no files'
}

test_work_item_number_is_not_assumed_from_the_branch() {
  section_has "Step 4: Write the draft" 'Do not assume the branch name holds a number' 'A number the engineer gives' \
    'start of the branch name' 'ask the engineer to confirm it' '2024-q3-cleanup' 'ask once' 'write no link line' \
    'Never invent a number'
}

test_work_item_link_form_follows_the_remote() {
  section_has "Step 4: Write the draft" '`AB#<number>`' '`#<number>`' 'git remote get-url origin' 'dev.azure.com' \
    'visualstudio.com' 'ssh.dev.azure.com' 'vs-ssh.visualstudio.com' 'github.com' 'any other host' 'cannot be read' \
    'Work item <number>'
}

test_title_gets_the_number_only_when_known() {
  section_has "Step 4: Write the draft" 'at most 72 characters' 'When a work item number is known, start the title with the number and a colon'
}

test_output_is_one_fenced_block_with_the_layout() {
  section_has Output 'four backticks' 'Title:' '## Summary' '## Root cause' '## Changes' '## Key changes' '## Risks' \
    '## Testing' '<work item link>'
}

test_testing_rule_for_a_verify_report_is_kept() {
  has_all 'result line' 'environment line' 'Not verified' 'verbatim' 'does not pass' 'before the draft' \
    'whether to quote it' 'never runs the verify skill' 'never reads the evidence folder' 'Without a pasted report'
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
check "it edits nothing and never commits or pushes" test_it_edits_nothing_and_never_commits_or_pushes
check "pasted inputs are used only when pasted" test_inputs_are_used_only_when_pasted
check "the base comes from the remote default and the engineer confirms it" test_base_comes_from_the_remote_default_and_is_confirmed
check "the base is not guessed from commit counts" test_base_is_not_guessed_from_commit_counts
check "git state is never changed" test_git_state_is_never_changed
check "the diff uses the merge base" test_diff_uses_the_merge_base
check "only committed work is described, and uncommitted work is asked about" test_only_committed_work_is_described_and_uncommitted_asks
check "Summary and Changes come only from the diff" test_the_diff_is_the_only_source_of_summary_and_changes
check "a PR template is followed when the repository has one" test_template_is_followed_when_the_repository_has_one
check "Root cause and Risks come only from pasted blocks" test_root_cause_and_risks_come_only_from_pasted_blocks
check "Key changes follow the kind of change, not the file count" test_key_changes_follow_the_kind_of_change_not_the_file_count
check "many alike files are described once" test_many_alike_files_are_described_once
check "the work item number is not assumed from the branch" test_work_item_number_is_not_assumed_from_the_branch
check "the work item link form follows the remote" test_work_item_link_form_follows_the_remote
check "the title gets the number only when known" test_title_gets_the_number_only_when_known
check "the output is one fenced block with the layout" test_output_is_one_fenced_block_with_the_layout
check "the verify report rule is kept" test_testing_rule_for_a_verify_report_is_kept
check "plain writing: no dash asides, no filler" test_plain_writing_has_no_dash_asides_or_filler

echo
echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
