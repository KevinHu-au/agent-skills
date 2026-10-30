#!/usr/bin/env bash
# Structure and wording tests for the agentd-pr-review skill files. Reads the skill files and writes nothing.
# The check that every skill sets disable-model-invocation lives in tests/onboard/test-skill-structure.sh.
# Customer and project names are read from the git-ignored list .git/info/customer-names, never spelt out here.
# Usage: tests/pr-review/test-skill-structure.sh
set -u

HERE=$(cd "$(dirname "$0")" && pwd -P)
REPO=$(cd "$HERE/../.." && pwd -P)
SKILL_DIR=${SKILL_DIR:-$REPO/skills/agentd-pr-review}
SKILL="$SKILL_DIR/SKILL.md"
REFS="$SKILL_DIR/references"
EVAL="$REPO/tests/pr-review/EVAL.md"
NAMES=$(git -C "$REPO" rev-parse --git-path info/customer-names 2>/dev/null)
case "$NAMES" in /*) ;; ?*) NAMES="$REPO/$NAMES" ;; esac
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

# has_all <file> <text>...: the file contains every text, ignoring case.
has_all() {
  local f=$1 t body
  shift
  [ -s "$f" ] || return 1
  body=$(joined <"$f")
  for t in "$@"; do printf '%s\n' "$body" | grep -qiF -- "$t" || return 1; done
}

# joined: stdin as one line, runs of spaces squeezed, so a phrase that wraps across lines still matches.
joined() { tr '\n' ' ' | tr -s ' '; }

# FENCE: awk code shared by the fence helpers. A fence opens on a line that starts with 3 or more backticks or
# tildes, and closes only on a line of the same character, at least as long, with nothing after it. So a
# ```markdown block nested inside a ````markdown block stays inside the outer fence.
FENCE='
  function run(line,   c, i) {
    c = substr(line, 1, 1)
    if (c != "`" && c != "~") return 0
    i = 1
    while (substr(line, i, 1) == c) i++
    return (i - 1 >= 3) ? i - 1 : 0
  }
  function fence_line(line,   r) {
    r = run(line)
    if (!f && r) { f = 1; fc = substr(line, 1, 1); fn = r; return 1 }
    if (f && r && substr(line, 1, 1) == fc && r >= fn && substr(line, r + 1) ~ /^[ \t]*$/) { f = 0; return 1 }
    return 0
  }
'

# strip_fences <file>: the file without fenced code blocks, so a "## " line inside one is not read as a heading.
strip_fences() { awk "$FENCE"' { if (fence_line($0)) next } !f' "$1"; }

# strip_fences_off <file>: only the lines inside fenced blocks, without the outer fence lines.
strip_fences_off() { awk "$FENCE"' { if (fence_line($0)) next } f' "$1"; }

# h2_list <file>: the H2 headings of a markdown file, in order, one per line. Fenced blocks are skipped.
h2_list() { strip_fences "$1" | grep -E '^## ' | sed 's/^## //; s/[[:space:]]*$//'; }

# section_of <file> <heading>: the lines under one H2 heading. Fenced blocks are skipped when finding headings.
section_of() {
  awk -v h="## $2" "$FENCE"'
    { was = f; fence_line($0) }
    !was && !f && $0 == h { on = 1; next }
    !was && !f && /^## / { on = 0 }
    on
  ' "$1"
}

# section_has <file> <heading> <text>...: the section contains every text, ignoring case.
section_has() {
  local f=$1 h=$2 body t
  shift 2
  body=$(section_of "$f" "$h" 2>/dev/null | joined)
  [ -n "$body" ] || return 1
  for t in "$@"; do printf '%s\n' "$body" | grep -qiF -- "$t" || return 1; done
}

# section_in_order <file> <heading> <text>...: every text appears in the section, each on a later line.
section_in_order() {
  local f=$1 h=$2 body t n last=0
  shift 2
  body=$(section_of "$f" "$h" 2>/dev/null)
  [ -n "$body" ] || return 1
  for t in "$@"; do
    n=$(printf '%s\n' "$body" | grep -niF -- "$t" | awk -F: -v last="$last" '$1 > last { print $1; exit }')
    [ -n "$n" ] || return 1
    last=$n
  done
}

# line_has <file> <heading> <text>...: some single line in the section contains every text, ignoring case.
line_has() {
  local f=$1 h=$2
  shift 2
  section_of "$f" "$h" 2>/dev/null | awk -v n=$# '
    BEGIN { for (i = 1; i <= n; i++) t[i] = tolower(ARGV[i]); ARGC = 1 }
    { l = tolower($0); ok = 1; for (i = 1; i <= n; i++) if (index(l, t[i]) == 0) { ok = 0; break } }
    ok { found = 1; exit }
    END { exit !found }
  ' "$@"
}

# none_contains <grep option> <text>: no markdown file in the skill folder matches. Fails when there is none.
none_contains() {
  local opt=$1 text=$2 f found=0
  for f in "$SKILL_DIR"/*.md "$REFS"/*.md; do
    [ -f "$f" ] || continue
    found=1
    grep -q "$opt" -- "$text" "$f" && return 1
  done
  [ "$found" -eq 1 ]
}

# ---------------------------------------------------------------- the helpers themselves

test_fence_helpers_handle_nested_fences() {
  local doc
  doc=$'## One\n\n````markdown\n```markdown\n## Not a heading\n```\n````\n\n## Two\nend\n'
  [ "$(h2_list <(printf '%s' "$doc") | tr '\n' '|')" = "One|Two|" ] &&
    [ "$(section_of <(printf '%s' "$doc") One | grep -c 'Not a heading')" = 1 ]
}

test_line_has_needs_one_line() {
  local doc
  doc=$'## S\nalpha beta\ngamma\n'
  line_has <(printf '%s' "$doc") S alpha beta && ! line_has <(printf '%s' "$doc") S alpha gamma
}

# ---------------------------------------------------------------- SKILL.md

test_frontmatter_name_matches_folder() {
  [ "$(frontmatter_value name)" = "agentd-pr-review" ] && [ "$(basename "$SKILL_DIR")" = "agentd-pr-review" ]
}

test_description_starts_with_use_when_and_covers_the_job() {
  local d t
  d=$(frontmatter_value description)
  case "$d" in "Use when"*) ;; *) return 1 ;; esac
  for t in "PR" "approver" "work item" "Block" "Edits no code"; do
    printf '%s\n' "$d" | grep -qiF -- "$t" || return 1
  done
}

test_skill_is_manual_only() {
  [ -s "$SKILL" ] || return 1
  awk 'NR == 1 && $0 != "---" { exit } /^---[ \t]*$/ { c++; if (c == 2) exit; next } c == 1' "$SKILL" |
    grep -qx 'disable-model-invocation: true'
}

# Raised from 120 to 130 for the shared "Find the project facts" paragraph, which every skill that reads the pack
# carries word for word (see tests/test-shared-text.sh).
test_skill_is_at_most_140_lines() {
  [ -s "$SKILL" ] && [ "$(wc -l <"$SKILL")" -le 140 ]
}

test_required_h2_sections_in_order() {
  [ -s "$SKILL" ] || return 1
  [ "$(h2_list "$SKILL" | tr '\n' '|')" = "Prerequisite|Flow|Severity|Evidence|Running commands|Output|Rules|" ]
}

test_flow_has_nine_numbered_steps_in_order() {
  local body
  body=$(section_of "$SKILL" Flow 2>/dev/null)
  [ -n "$body" ] || return 1
  [ "$(printf '%s\n' "$body" | grep -E '^[0-9]+\. \*\*' | sed -E 's/^([0-9]+)\. \*\*([^*]*)\*\*.*/\1 \2/' |
    tr '\n' '|')" = '1 Read the inputs.|2 Build the requirement.|3 Read the change.|4 Check each criterion.|5 Search for siblings.|6 Check for breakage.|7 Run plan.|8 Run the tests.|9 Report.|' ]
}

test_missing_paste_asks_once() {
  has_all "$SKILL" "no work item" "ask for it once" "If none comes, stop." "Do not review against the diff alone."
}

test_screenshots_are_part_of_the_requirement() {
  has_all "$SKILL" "screenshots" "part of the requirement"
}

test_optional_inputs() {
  has_all "$SKILL" "PR description" "parent feature" "several work items"
}

test_requirement_splits_said_and_assumed() {
  section_has "$SKILL" Flow "what the work item says" "what you assumed"
}

test_gaps_do_not_stop_the_review() {
  has_all "$SKILL" "do not stop" "question for the work item creator"
}

test_base_branch_is_confirmed() {
  has_all "$SKILL" "git symbolic-ref refs/remotes/origin/HEAD" "confirms" "never guess" "<base>...HEAD"
}

test_dirty_tree_warns() {
  has_all "$SKILL" "uncommitted changes" "not part of the PR" \
    "Do not ask the engineer to stash them" 'git show HEAD:<path>' 'in a worktree at `HEAD`' \
    '`<scratch>/wt-head`' "so the changes stay as they are" "Name the branch and the commit that" \
    "If it is not the PR's branch, ask" &&
    ! has_all "$SKILL" "and run no tests" && ! has_all "$SKILL" "ask the engineer to stash them before the run plan"
}

test_stale_branch_warns_and_never_fetches() {
  has_all "$SKILL" "behind" 'Never run `git fetch`, `git pull`, `git checkout`, `git switch` or `git stash`.'
}

test_sibling_search_uses_code_not_work_item() {
  section_has "$SKILL" Flow "similar places" "the PR did not touch" "from the code, not the work item" "Major"
}

test_breakage_points_to_blast_radius_references() {
  has_all "$SKILL" "../agentd-blast-radius/references/surfaces.md" "dotnet.md" "react.md" "ios.md" &&
    [ -s "$SKILL_DIR/../agentd-blast-radius/references/surfaces.md" ]
}

test_missing_surfaces_file_falls_back() {
  has_all "$SKILL" "this skill's own folder, not the repository" 'If `surfaces.md` is missing, say so in one line' \
    "wire shapes" "data" "configuration" "indirection" "timing and state" "other readers of the same bytes" \
    "generated files" "libraries and the runtime" "authorisation reach" "external systems" "old behaviour"
}

test_commands_come_from_the_contract() {
  has_all "$SKILL" "AGENTS.md" "never guess a command" "a command the repository states"
}

test_automation_means_integration_suites() {
  has_all "$SKILL" "automation tests" "integration" "not UI automation"
}

test_docker_check_skips_and_says_so() {
  has_all "$SKILL" "Docker" "skip that suite" "never report it as passed"
}

test_test_count_not_exit_code() {
  has_all "$SKILL" "test count" "not only the exit code" "ran 0 tests"
}

test_base_rerun_in_scratch() {
  section_has "$SKILL" "Running commands" 'git -c core.hooksPath=/dev/null worktree add --detach <scratch>/wt-base <merge-base>' \
    '`<scratch>/wt-head` the same way at `HEAD`' 'turns off the repository' 'writes entries into `.git/config`' \
    'submodule update' 'Only if the `git worktree` command is unavailable, use `git archive`' \
    'do not fall back to `git archive` then' 'Never run `git worktree prune`' \
    'each `git worktree add`, the submodule update and each `git worktree remove --force` on `wt-head` or `wt-base`' \
    'A setup failure on both sides is not old breakage' 'never report it as passed' \
    'with paths, line numbers, timestamps and IDs removed' 'cannot compile or start on either side is `unknown:`' \
    'run `git worktree remove --force` on `<scratch>/wt-head` and `<scratch>/wt-base`, whichever you added, then remove the folder with' \
    "git archive" "mktemp -d" "the failing suites" "lock file" \
    '"$HOME/.agents/bin/rm-scratch"' 'git merge-base <base> HEAD' "never check them out in the repository" \
    "the same contract command" "or runs 0 tests, the base result is"
}

test_docker_check_is_on_the_run_plan() {
  section_has "$SKILL" "Running commands" '`docker info`'
}

test_failed_restore_is_unknown() {
  has_all "$SKILL" "If the restore, the add or the submodule update fails" "or the copy fails at setup" "unknown:" "at most Major"
}

test_new_failure_is_block_old_failure_is_listed() {
  has_all "$SKILL" "A test that fails only on the PR branch is Block." \
    "Compare the failing test names and error text on both sides" \
    "A test that fails on both for the same reason is old breakage" "is not a finding" \
    "A different or extra failure is the PR's, so it is Block" && ! has_all "$SKILL" "fails on both is Block"
}

test_lint_on_changed_lines_only() {
  has_all "$SKILL" "lines the PR changed"
}

test_one_confirmation_for_the_run_plan() {
  section_has "$SKILL" "Running commands" "one confirmation" "Read-only inspection"
}

test_ui_checks_only_when_needed() {
  has_all "$SKILL" "Check in the UI" "only when" "you do not start the app"
}

test_severity_definitions() {
  section_has "$SKILL" Severity "Block" "Major" "Minor" "at most Major" "assumed requirement" "style nits"
}

test_scope_creep_is_major_with_a_question() {
  section_has "$SKILL" Severity "does more than the work item asks" "Major" "question for the work item creator" \
    "not Block"
}

test_silent_or_vague_work_item_wins_over_block() {
  section_has "$SKILL" Severity "When the work item is silent or vague on the point" \
    "a finding about the requirement" "is at most Major" \
    "Failing tests, build failures, security problems, data loss and contract breaks stay Block." \
    "a change of shape" "not a change in which rows come back" &&
    ! has_all "$SKILL" "even where a Block rule fits"
}

# ---------------------------------------------------------------- exact rules (review round 2: no deletion or reversal)

test_block_list_is_complete() {
  section_has "$SKILL" Severity "A stated acceptance criterion is clearly not met." \
    "A test fails only on the PR branch." "The build fails." \
    "A security problem: a secret, injection, or an authorisation bypass." "A risk of data loss or corruption." \
    "Changed behaviour with no test."
}

test_exact_running_rules() {
  has_all "$SKILL" 'A command that ran 0 tests is reported as "ran 0 tests", never as a pass.' \
    "Report pass, fail and skip counts per suite." \
    "If Docker is not running, skip that suite, say so, and never report it as passed." \
    "and the finding is at most Major; do not fall back to" "Never invent a path, a caller or an API." \
    "**Never:** write to a shared environment, change data, call an outside system, or install or upgrade a package." \
    "Then remove the worktrees and the scratch folder (see Scratch folder)."
}

test_running_commands_never_switch_branches() {
  ! section_of "$SKILL" "Running commands" | grep -qE 'git (switch|checkout)'
}

test_dirty_tree_asks_to_stash_not_commit() {
  has_all "$SKILL" "Do not ask the engineer to stash them" 'Never run `git fetch`' '`git stash`' &&
    ! has_all "$SKILL" "stash or commit" && ! has_all "$SKILL" '`git stash -u`'
}

test_vote_line_is_outside_the_paste() {
  has_all "$OUT" "on one line just above the paste block, outside it" &&
    ! has_all "$OUT" "and the suggested vote" && ! has_all "$OUT" "inside it"
}

test_finding_order_is_exact() {
  has_all "$OUT" "every Block, then every Major, then every Minor"
}

test_no_minor_finding_asks_to_wait() {
  ! section_of "$OUT" "Summary comment" | grep -i "minor" | grep -qi "wait for author"
}

test_evidence_tiers() {
  section_has "$SKILL" Evidence "confirmed" "supported" "inferred:" "unknown:" "path:line"
}

test_vote_is_suggested_never_cast() {
  has_all "$SKILL" "Approve with suggestions" "Wait for author" "the engineer picks the vote"
}

# three_backtick_fence_named <file>: the file names a ```markdown fence, three backticks and not four, anywhere.
three_backtick_fence_named() { grep -qE '(^|[^`])```markdown' "$1"; }

test_output_is_markdown_in_fences() {
  section_has "$SKILL" Output "four backticks" '````markdown' "raw" "references/report-template.md" &&
    ! three_backtick_fence_named "$SKILL"
}

test_never_writes_or_posts() {
  section_has "$SKILL" Rules "edit no code" "nothing in the repository" "Post nothing and never vote."
}

test_no_azure_devops() {
  section_has "$SKILL" Rules "Do not read Azure DevOps"
}

test_privacy() {
  has_all "$SKILL" "name a key, never its value" "personal data"
}

test_does_not_start_another_skill() {
  section_has "$SKILL" Rules "do not start another skill"
}

test_no_customer_names() {
  local f
  [ -s "$SKILL" ] && [ -s "$NAMES" ] || return 1
  for f in "$SKILL_DIR"/*.md "$REFS"/*.md "$REPO/README.md" "$HERE"/*; do
    [ -f "$f" ] || continue
    # Entries of 3 letters or fewer match whole words only, so a short name inside a longer word is fine.
    # Longer entries match anywhere, so a name inside a CamelCase type name is caught.
    grep -qiwF -f <(awk 'length($0) <= 3' "$NAMES") "$f" && return 1
    grep -qiF -f <(awk 'length($0) > 3' "$NAMES") "$f" && return 1
  done
  return 0
}

test_no_absolute_home_paths() {
  local tmp="/var/""folders"
  none_contains -F "/Users/" && none_contains -F "~/" && none_contains -F "$tmp" || return 1
  [ -f "$EVAL" ] || return 0
  ! grep -qF -e "/Users/" -e "~/" -e "$tmp" "$EVAL"
}

test_no_phrase_is_copied_from_pstack() {
  local p
  [ -s "$SKILL" ] || return 1
  for p in "pstack" "poteto"; do
    none_contains -iF "$p" || return 1
  done
}

# ---------------------------------------------------------------- report template

OUT="$REFS/report-template.md"

test_every_referenced_file_exists() {
  has_all "$SKILL" "references/report-template.md" && [ -s "$OUT" ]
}

test_template_h2s_exact() {
  [ -s "$OUT" ] && [ "$(h2_list "$OUT" | tr '\n' '|')" = "Summary comment|Finding comment|For you only|Check in the UI|" ]
}

test_summary_comment_parts() {
  section_has "$OUT" "Summary comment" "compared with the work item" "per suite" "new compared with the base" \
    "by severity" "Suggested vote"
}

test_vote_mapping() {
  line_has "$OUT" "Summary comment" "Any Block" "Wait for author" &&
    line_has "$OUT" "Summary comment" "No Block, at least one Major" "Wait for author" "Approve with suggestions" \
      "the engineer chooses" &&
    line_has "$OUT" "Summary comment" "Minor findings only" "Approve with suggestions" &&
    line_has "$OUT" "Summary comment" "No findings" "Approve" &&
    ! section_of "$OUT" "Summary comment" | grep -i "minor findings only" | grep -qiv "with suggestions"
}

test_finding_comment_shape() {
  line_has "$OUT" "Finding comment" "**[Major]**" '`src/path/File.cs:42`' &&
    section_in_order "$OUT" "Finding comment" "**[Major]**" "**Scenario:**" "**Suggestion:**" "_Evidence:"
}

test_finding_order_and_snippet_limit() {
  has_all "$OUT" "most severe first" "about 10 lines"
}

test_for_you_only_parts() {
  section_has "$OUT" "For you only" "Questions for the work item creator" "every sibling gap" "Requirement" \
    "Assumptions" "Not run or not checked" "Old failures"
}

test_ui_check_shape() {
  section_has "$OUT" "Check in the UI" "page" "action" "what to look for" "settles" "no list"
}

test_every_paste_block_is_a_markdown_fence() {
  local h
  for h in "Summary comment" "Finding comment"; do
    section_of "$OUT" "$h" | grep -qE '^````markdown$' || return 1
  done
}

# A comment that holds its own ``` code block must not close the paste fence, so every fence is four backticks.
test_template_says_four_backtick_fences() {
  has_all "$OUT" "four backticks" '````markdown' && ! three_backtick_fence_named "$OUT"
}

test_major_only_vote_line_may_name_both() {
  has_all "$OUT" "Suggested vote:" "name both votes"
}

test_summary_does_not_claim_questions_were_sent() {
  has_all "$OUT" "open questions" && ! has_all "$OUT" "are with the work item creator"
}

test_evidence_line_covers_every_tier() {
  line_has "$OUT" "Finding comment" "_Evidence:" "confirmed" "supported" "inferred: from reading the code" \
    "unknown:" "seen in the UI"
}

test_for_you_only_has_the_criteria() {
  section_has "$OUT" "For you only" "**Criteria:**" "covered, partly covered or not covered"
}

test_template_tone() {
  has_all "$OUT" "written to the teammate" "plain" "polite"
}

# ---------------------------------------------------------------- README

test_readme_lists_the_skill_and_its_tests() {
  local readme="$REPO/README.md"
  section_has "$readme" Skills '`agentd-pr-review`' &&
    has_all "$readme" "tests/pr-review/test-skill-structure.sh" "tests/pr-review/test-make-fixture.sh" \
      "tests/pr-review/EVAL.md"
}

# ---------------------------------------------------------------- run

check "fence helpers handle nested fences" test_fence_helpers_handle_nested_fences
check "line_has needs every text on one line" test_line_has_needs_one_line
check "frontmatter name matches the folder" test_frontmatter_name_matches_folder
check "description starts with Use when and covers the job" test_description_starts_with_use_when_and_covers_the_job
check "the skill is manual-only" test_skill_is_manual_only
check "SKILL.md is at most 140 lines" test_skill_is_at_most_140_lines
check "H2 sections in order" test_required_h2_sections_in_order
check "Flow has nine numbered steps in order" test_flow_has_nine_numbered_steps_in_order
check "a missing paste asks once" test_missing_paste_asks_once
check "screenshots are part of the requirement" test_screenshots_are_part_of_the_requirement
check "optional inputs" test_optional_inputs
check "the requirement splits what was said from what was assumed" test_requirement_splits_said_and_assumed
check "gaps do not stop the review" test_gaps_do_not_stop_the_review
check "the base branch is confirmed" test_base_branch_is_confirmed
check "a dirty tree warns" test_dirty_tree_warns
check "a stale branch warns and the skill never fetches" test_stale_branch_warns_and_never_fetches
check "the sibling search uses the code, not the work item" test_sibling_search_uses_code_not_work_item
check "breakage points to the blast-radius references" test_breakage_points_to_blast_radius_references
check "a missing surfaces file falls back" test_missing_surfaces_file_falls_back
check "commands come from the contract" test_commands_come_from_the_contract
check "automation tests means the integration suites" test_automation_means_integration_suites
check "the Docker check skips and says so" test_docker_check_skips_and_says_so
check "the test count, not the exit code" test_test_count_not_exit_code
check "the base re-run is in a scratch folder" test_base_rerun_in_scratch
check "a failed restore is unknown" test_failed_restore_is_unknown
check "a new failure is Block, an old failure is listed" test_new_failure_is_block_old_failure_is_listed
check "lint on changed lines only" test_lint_on_changed_lines_only
check "one confirmation for the run plan" test_one_confirmation_for_the_run_plan
check "UI checks only when needed" test_ui_checks_only_when_needed
check "severity definitions" test_severity_definitions
check "scope creep is Major with a question" test_scope_creep_is_major_with_a_question
check "evidence tiers" test_evidence_tiers
check "the vote is suggested, never cast" test_vote_is_suggested_never_cast
check "output is markdown in fences" test_output_is_markdown_in_fences
check "it never writes or posts" test_never_writes_or_posts
check "it does not read Azure DevOps" test_no_azure_devops
check "privacy" test_privacy
check "it does not start another skill" test_does_not_start_another_skill
if [ -s "$NAMES" ]; then
  check "no customer or project names in tracked files" test_no_customer_names
else
  printf '  skip  no customer-names list\n'
fi
check "no absolute home paths" test_no_absolute_home_paths
check "no phrase is copied from the source skills" test_no_phrase_is_copied_from_pstack
check "every referenced file exists" test_every_referenced_file_exists
check "the template has exactly four H2s" test_template_h2s_exact
check "summary comment parts" test_summary_comment_parts
check "vote mapping" test_vote_mapping
check "finding comment shape" test_finding_comment_shape
check "finding order and snippet limit" test_finding_order_and_snippet_limit
check "for-you-only parts" test_for_you_only_parts
check "Check in the UI shape" test_ui_check_shape
check "every paste block is a markdown fence" test_every_paste_block_is_a_markdown_fence
check "the template says four-backtick fences" test_template_says_four_backtick_fences
check "template tone" test_template_tone
check "the Major-only vote line may name both votes" test_major_only_vote_line_may_name_both
check "the summary does not claim questions were sent" test_summary_does_not_claim_questions_were_sent
check "the evidence line covers every tier" test_evidence_line_covers_every_tier
check "for-you-only has the criteria" test_for_you_only_has_the_criteria
check "the Docker check is on the run plan" test_docker_check_is_on_the_run_plan
check "a silent or vague work item caps requirement findings only" test_silent_or_vague_work_item_wins_over_block
check "the Block list is complete" test_block_list_is_complete
check "exact running rules" test_exact_running_rules
check "Running commands never switch branches" test_running_commands_never_switch_branches
check "a dirty tree asks to stash, not commit" test_dirty_tree_asks_to_stash_not_commit
check "the vote line is outside the paste" test_vote_line_is_outside_the_paste
check "the finding order is exact" test_finding_order_is_exact
check "no Minor finding asks to wait" test_no_minor_finding_asks_to_wait
check "the README lists the skill and its tests" test_readme_lists_the_skill_and_its_tests

echo
echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
