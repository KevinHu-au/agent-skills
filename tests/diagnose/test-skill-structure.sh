#!/usr/bin/env bash
# Structure and wording tests for the agentd-diagnose skill files. Reads the skill files and writes nothing.
# The check that every skill sets disable-model-invocation lives in tests/onboard/test-skill-structure.sh.
# Usage: tests/diagnose/test-skill-structure.sh
set -u

HERE=$(cd "$(dirname "$0")" && pwd -P)
REPO=$(cd "$HERE/../.." && pwd -P)
SKILL_DIR=${SKILL_DIR:-$REPO/skills/agentd-diagnose}
SKILL="$SKILL_DIR/SKILL.md"
REFS="$SKILL_DIR/references"
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

REFERENCES="bug.md data.md dotnet.md ios.md performance.md react.md report-template.md"

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
  local f=$1 t
  shift
  [ -s "$f" ] || return 1
  for t in "$@"; do grep -qiF -- "$t" "$f" || return 1; done
}

# h2_list <file>: the H2 headings of a markdown file, in order, one per line.
h2_list() { grep -E '^## ' "$1" | sed 's/^## //; s/[[:space:]]*$//'; }

# section_of <file> <heading>: the lines under one H2 heading.
section_of() { awk -v h="## $2" '$0 == h { on = 1; next } /^## / { on = 0 } on' "$1"; }

# in_order <file> <text>...: every text appears in the file, each on a later line than the one before.
in_order() {
  local f=$1 t n last=0
  shift
  [ -s "$f" ] || return 1
  for t in "$@"; do
    n=$(grep -niF -- "$t" "$f" | awk -F: -v last="$last" '$1 > last { print $1; exit }')
    [ -n "$n" ] || return 1
    last=$n
  done
}

test_frontmatter_name_matches_folder() {
  [ "$(frontmatter_value name)" = "agentd-diagnose" ] && [ "$(basename "$SKILL_DIR")" = "agentd-diagnose" ]
}

test_description_starts_with_use_when_and_covers_the_jobs() {
  local d
  d=$(frontmatter_value description)
  case "$d" in "Use when "*) ;; *) return 1 ;; esac
  printf '%s\n' "$d" | grep -qi 'root cause' &&
    printf '%s\n' "$d" | grep -qi 'bug' &&
    printf '%s\n' "$d" | grep -qi 'data' &&
    printf '%s\n' "$d" | grep -qi 'slow'
}

test_skill_is_manual_only() {
  [ -f "$SKILL" ] || return 1
  awk 'NR == 1 && $0 != "---" { exit } /^---[ \t]*$/ { c++; if (c == 2) exit; next } c == 1' "$SKILL" |
    grep -qx 'disable-model-invocation: true'
}

test_skill_is_at_most_160_lines() {
  [ -f "$SKILL" ] && [ "$(wc -l <"$SKILL" | tr -d ' ')" -le 160 ]
}

test_every_referenced_file_exists() {
  local f listed
  [ -f "$SKILL" ] || return 1
  listed=$(grep -oE 'references/[A-Za-z0-9._-]+\.md' "$SKILL" | sed 's|^references/||' | sort -u)
  [ "$listed" = "$(printf '%s\n' $REFERENCES | sort -u)" ] || return 1
  for f in $REFERENCES; do [ -f "$REFS/$f" ] || return 1; done
}

test_required_h2_sections_in_order() {
  [ -f "$SKILL" ] &&
    [ "$(h2_list "$SKILL" | tr '\n' '|')" = "Prerequisite|Modes|Flow|Running commands|Evidence|Output|Rules|" ]
}

test_skill_files_have_no_absolute_home_paths() {
  [ -f "$SKILL" ] || return 1
  ! grep -qE '/Users/|/home/|~/' "$SKILL" "$REFS"/*.md 2>/dev/null
}

test_flow_has_seven_numbered_steps_in_order() {
  [ -f "$SKILL" ] || return 1
  [ "$(section_of "$SKILL" Flow | grep -oE '^[0-9]+\. \*\*[A-Za-z ]+\.\*\*' | sed 's/\*//g; s/\.$//' | tr '\n' '|')" = \
    "1. Frame|2. Orient|3. Run plan|4. Reproduce|5. Narrow|6. Gate|7. Report|" ]
}

test_modes_name_the_three_modes_and_the_mixed_ticket() {
  local s
  s=$(section_of "$SKILL" Modes)
  printf '%s\n' "$s" | grep -qi 'references/bug.md' &&
    printf '%s\n' "$s" | grep -qi 'references/data.md' &&
    printf '%s\n' "$s" | grep -qi 'references/performance.md' &&
    printf '%s\n' "$s" | grep -qi 'one line' &&
    printf '%s\n' "$s" | grep -qi 'follow-on'
}

test_running_commands_has_the_run_rules() {
  local s
  s=$(section_of "$SKILL" "Running commands")
  [ -n "$s" ] || return 1
  printf '%s\n' "$s" | grep -qF 'mktemp -d' &&
    printf '%s\n' "$s" | grep -qi 'removed after the report' &&
    printf '%s\n' "$s" | grep -qi 'only after you have shown the report' &&
    printf '%s\n' "$s" | grep -qi 'delete nothing else' &&
    printf '%s\n' "$s" | grep -qi 'one confirmation' &&
    printf '%s\n' "$s" | grep -qF 'SELECT' &&
    printf '%s\n' "$s" | grep -qF 'Data access' &&
    printf '%s\n' "$s" | grep -qi 'nobody' &&
    printf '%s\n' "$s" | grep -qi 'safe checks only'
}

test_evidence_has_four_tiers_and_three_markers() {
  local s
  s=$(section_of "$SKILL" Evidence)
  [ -n "$s" ] || return 1
  for t in 'confirmed' 'supported' 'inferred' 'unknown'; do printf '%s\n' "$s" | grep -qi "$t" || return 1; done
  for m in 'unknown:' 'inferred:' 'conflict:'; do printf '%s\n' "$s" | grep -qF "$m" || return 1; done
}

test_rules_forbid_code_edits_repo_files_installs_and_personal_data() {
  local s
  s=$(section_of "$SKILL" Rules)
  [ -n "$s" ] || return 1
  printf '%s\n' "$s" | grep -qi 'Edit no code' &&
    printf '%s\n' "$s" | grep -qi 'no file in the repository' &&
    printf '%s\n' "$s" | grep -qi 'personal data' &&
    printf '%s\n' "$s" | grep -qi 'Azure DevOps' &&
    printf '%s\n' "$s" | grep -qi 'install'
}

test_the_gate_is_in_the_skill_and_the_hand_off() {
  has_all "$SKILL" 'Not confirmed' 'hand off anyway' &&
    has_all "$REFS/report-template.md" 'Confidence: hypothesis, not confirmed'
}

test_the_skill_never_starts_the_next_skill() {
  has_all "$REFS/report-template.md" 'Run `/agentd-dev-rev`' 'paste'
}

test_bug_reference_covers_the_method() {
  has_all "$REFS/bug.md" 'legitimate' 'persisted state' 'failing test' 'same fault' 'premise'
}

test_data_reference_covers_the_four_questions_and_privacy() {
  has_all "$REFS/data.md" 'SELECT' 'wrong or the' 'still happening' 'ID' 'repair' 'personal data'
}

test_data_repair_hand_off_names_the_data_fix_skill() {
  local s; s=$(section_of "$REFS/data.md" 'Hand-off')
  for p in '/agentd-data-fix' 'with the work item' 'extra facts' 'Follow-on' 'do not write the repair'; do
    printf '%s\n' "$s" | grep -qiF -- "$p" || return 1
  done
  ! printf '%s\n' "$s" | grep -qiE 'a backup, a rollback|no skill runs it yet'
}

test_performance_reference_has_the_mantras_in_order_and_the_vetting() {
  in_order "$REFS/performance.md" "don't do it" "don't do it again" 'do it less' 'do it later' \
    "when they're not looking" 'do it concurrently' 'do it cheaper' &&
    has_all "$REFS/performance.md" '5 runs' 'median' 'limiter' 'end to end'
}

test_dotnet_reference_names_where_to_look() {
  has_all "$REFS/dotnet.md" '--filter' 'N+1' 'Release' 'dotnet-counters' 'dotnet-trace' 'zero'
}

test_report_template_has_the_headings_in_order() {
  in_order "$REFS/report-template.md" '### Problem' '### Reproduction' '### Root cause' '### Evidence' \
    '### Competing causes' '### Proposed fix' '### Not checked'
}

test_hand_off_block_has_every_field() {
  has_all "$REFS/report-template.md" 'Task:' 'Root cause:' 'Failing test first:' 'Proposed fix:' \
    'Do not change:' 'Risk areas:' 'Verification:' 'Confidence:' 'Follow-on:'
}

test_report_template_has_the_three_verdicts() {
  has_all "$REFS/report-template.md" 'Confirmed' 'Not confirmed' 'Not reproduced'
}

# Rules added after the first agent runs (see Iterations in EVAL.md).
test_the_scratch_folder_is_optional_and_has_a_fallback() {
  local s
  s=$(section_of "$SKILL" "Running commands")
  printf '%s\n' "$s" | grep -qi 'only when you need a file' &&
    printf '%s\n' "$s" | grep -qF 'Scratch folder: none' &&
    ! printf '%s\n' "$s" | grep -qi 'run the removal first'
}

test_data_rules_cover_read_only_open_and_large_scans() {
  local s
  s=$(section_of "$SKILL" "Running commands")
  printf '%s\n' "$s" | grep -qi 'read-only' &&
    printf '%s\n' "$s" | grep -qi 'on a copy' &&
    printf '%s\n' "$s" | grep -qi 'scans a large table' &&
    printf '%s\n' "$s" | grep -qi 'not the scan'
}

test_build_output_is_covered() {
  section_of "$SKILL" "Running commands" | grep -qF 'Build output' && ! grep -qF 'python3' "$SKILL"
}

test_modes_can_switch_and_the_report_says_where_it_started() {
  section_of "$SKILL" Modes | grep -qi 'switch' && has_all "$REFS/report-template.md" 'Started as'
}

test_confirmed_means_the_tickets_own_failure() {
  has_all "$SKILL" "ticket's own failure" &&
    section_of "$SKILL" Evidence | grep -qi 'only that a cause is possible'
}

test_report_has_decisions_and_the_question_is_last() {
  has_all "$REFS/report-template.md" 'Decisions needed' 'End the report with the question'
}

test_bug_reference_covers_an_id_the_test_data_lacks() {
  has_all "$REFS/bug.md" 'does not have' 'missing data'
}

test_performance_reference_is_not_tied_to_one_stack() {
  [ -s "$REFS/performance.md" ] && ! grep -qF 'a Release build' "$REFS/performance.md"
}

# Rules added after the Round 1 review (see the review notes in EVAL.md).
test_instrumentation_never_edits_the_repository() {
  has_all "$REFS/bug.md" 'without editing the repository' &&
    section_of "$SKILL" Flow | grep -qi 'without editing the repository'
}

test_a_new_command_needs_its_own_confirmation_and_keep_investigating_restarts_the_plan() {
  section_of "$SKILL" "Running commands" | grep -qi 'needs its own confirmation' &&
    section_of "$SKILL" Flow | grep -qi 'go back to Run plan'
}

test_a_build_may_restore_declared_packages_but_nothing_else_is_installed() {
  local s
  s=$(section_of "$SKILL" "Running commands")
  printf '%s\n' "$s" | grep -qi 'restore' && printf '%s\n' "$s" | grep -qi 'declared'
}

test_build_and_test_output_is_the_one_exception_to_no_repository_files() {
  section_of "$SKILL" Rules | grep -qi 'except build and test output'
}

test_the_closing_line_depends_on_the_verdict() {
  local s
  s=$(section_of "$SKILL" Output)
  printf '%s\n' "$s" | grep -qi 'closing line' && printf '%s\n' "$s" | grep -qi 'the question'
}

test_database_copies_are_for_file_databases_only_and_select_into_is_not_select() {
  local s
  s=$(section_of "$SKILL" "Running commands")
  printf '%s\n' "$s" | grep -qi 'file database' && printf '%s\n' "$s" | grep -qF 'SELECT ... INTO'
}

test_the_hand_off_block_opens_with_the_confidence_line() {
  in_order "$REFS/report-template.md" 'Confidence: confirmed' 'Task:'
}

test_performance_verdicts_map_to_the_report_verdicts_and_the_test_guards_the_cost() {
  has_all "$REFS/performance.md" 'Not reproduced' 'Not confirmed' 'statement count'
}

test_the_verdict_line_lists_the_three_verdicts_exactly() {
  grep -qF 'Verdict: Confirmed | Not confirmed | Not reproduced' "$REFS/report-template.md"
}
test_ios_reference_names_where_to_look() {
  has_all "$REFS/ios.md" '-only-testing' 'zero' '@MainActor' 'Instruments' 'Release' 'N+1' 'migration' 'general knowledge' 'not yet checked' \
    '## Run and count tests' 'Never run UI tests' '-derivedDataPath' &&
    grep -qF 'For an iOS (SwiftUI) project also read `references/ios.md`' "$SKILL"
}
test_react_reference_names_where_to_look() {
  has_all "$REFS/react.md" 'vitest run' 'run zero tests' 'do not run a script by name' 'CI=true' 'useEffect' 'react-dom/profiling' \
    'N+1: a request per row' 'VITE_' 'general knowledge' 'not yet checked' '## Run and count tests' 'Never run end-to-end tests' &&
    grep -qF 'For a React web project (a `package.json` that lists `react-dom` under `dependencies`, in any workspace) also read `references/react.md`' "$SKILL"
}

# Rules added after the Round 2 review.
test_rules_cover_configuration_files_and_instrumentation_without_edits() {
  section_of "$SKILL" Rules | grep -qi 'including configuration' &&
    has_all "$REFS/dotnet.md" 'environment variable' 'tracked configuration file'
}

test_data_without_a_data_access_heading_runs_no_query() {
  has_all "$REFS/data.md" 'run no query'
}

test_data_confirmation_and_a_cause_that_is_not_live_are_defined() {
  has_all "$REFS/data.md" 'bad-row shape' 'stays supported' 'not live'
}

test_the_hand_off_never_names_a_scratch_path_and_allows_no_code_fix() {
  has_all "$REFS/report-template.md" 'never name a path in the scratch folder' 'no code fix'
}

test_query_safety_rules_close_the_select_holes() {
  local s
  s=$(section_of "$SKILL" "Running commands")
  printf '%s\n' "$s" | grep -qF 'FOR UPDATE' &&
    printf '%s\n' "$s" | grep -qi 'catalog statistics' &&
    printf '%s\n' "$s" | grep -qi 'indexed key' &&
    printf '%s\n' "$s" | grep -qi 'non-personal'
}

test_read_only_inspection_needs_no_confirmation_and_tests_skip_shared_resources() {
  local s
  s=$(section_of "$SKILL" "Running commands")
  printf '%s\n' "$s" | grep -qi 'read-only inspection' &&
    printf '%s\n' "$s" | grep -qi 'configured database'
}

test_the_mode_line_and_the_gate_are_conditional_and_complete() {
  section_of "$SKILL" Modes | grep -qi 'if you switched' && section_of "$SKILL" Flow | grep -qF 'Not reproduced'
}

# Rules added after the round 3 run of scenario 2.
test_examples_use_invented_values_not_data_values() {
  section_of "$SKILL" Rules | grep -qi 'invent one'
}

test_the_closing_line_comes_after_the_hand_off_block_and_a_missing_write_date_keeps_it_supported() {
  has_all "$REFS/report-template.md" 'After the hand-off block' &&
    has_all "$REFS/data.md" 'no write date'
}

# Phrases that the Round 1 review found copied from the pstack originals. They must not come back.
test_no_phrase_is_copied_from_pstack() {
  local p
  [ -s "$SKILL" ] || return 1
  for p in 'caches as warm or cold as production sees them' 'what it times, counts and ignores' \
    'a guess from reading the code is not a limiter' 'if the system may be in that state' \
    'guards, retries, swallowed errors' 'not a consequence of an earlier one' \
    'errors, skipped or cached work' 'you do not know what you measured' 'at most about 11% faster'; do
    if grep -qiF -- "$p" "$SKILL" "$REFS"/*.md; then return 1; fi
  done
}

# Rules added after the reruns of scenarios 2 and 4.
test_unit_tests_that_use_their_own_temp_folder_are_safe_and_a_read_only_connection_is_the_fallback() {
  local s
  s=$(section_of "$SKILL" "Running commands")
  printf '%s\n' "$s" | grep -qi 'its own temp folder' &&
    printf '%s\n' "$s" | grep -qi 'read-only connection'
}

test_the_ticket_may_name_a_person_and_mixed_tickets_keep_the_code_fix_in_the_hand_off() {
  section_of "$SKILL" Rules | grep -qi 'the ticket itself gives' &&
    section_of "$SKILL" Modes | grep -qi 'the repair is the follow-on'
}

test_data_dates_and_the_two_not_verdicts_are_defined() {
  has_all "$REFS/data.md" 'when the row was written' &&
    has_all "$REFS/report-template.md" 'Not reproduced: you tried' 'Not confirmed: '
}

# Rules added after the review of the ideas borrowed from a debugging skill.
test_the_skill_files_name_no_outside_skill() {
  [ -f "$SKILL" ] || return 1
  ! grep -qiE 'superpowers|systematic-debugging|test-driven-development|verification-before-completion' "$SKILL" "$REFS"/*.md
}

test_the_borrowed_debugging_ideas_are_in_the_references() {
  has_all "$REFS/bug.md" 'whole error' 'working case' 'backward' 'fixed sleep' 'git archive' 'git stash' &&
    has_all "$REFS/data.md" 'good rows' 'stages' 'cannot read' &&
    has_all "$REFS/performance.md" 'Time each layer' 'fast case' 'git archive'
}

test_narrow_has_the_working_case_the_boundary_check_and_the_design_concern() {
  local n
  n=$(section_of "$SKILL" Flow | grep -E '^5\. \*\*Narrow')
  printf '%s\n' "$n" | grep -qi 'working case' && printf '%s\n' "$n" | grep -qF 'enters and leaves' &&
    printf '%s\n' "$n" | grep -qF 'Design concern' && printf '%s\n' "$n" | grep -qi 'same fault elsewhere'
}

test_the_six_stop_signs_sit_in_flow() {
  section_of "$SKILL" Flow | grep -qF 'Stop signs' && [ "$(section_of "$SKILL" Flow | grep -c '^- ')" = 6 ]
}

test_the_new_rules_have_their_text() {
  has_all "$REFS/bug.md" 'enters and leaves' 'several times (step 5)' 'Do not copy local settings' 'latch' &&
    has_all "$REFS/performance.md" 'Do not change a dependency' &&
    has_all "$REFS/data.md" 'Print only IDs and counts' &&
    has_all "$REFS/report-template.md" 'Keep the Decisions needed' 'smallest fix' &&
    section_of "$SKILL" Rules | grep -qF 'quote no name or address'
}

test_the_design_concern_is_in_the_report_and_not_in_the_hand_off_block() {
  [ "$(grep -c 'Design concern:' "$REFS/report-template.md")" = 1 ] &&
    in_order "$REFS/report-template.md" 'Design concern:' '## Hand-off block'
}

test_example_values_do_not_follow_the_data_pattern() {
  section_of "$SKILL" Rules | grep -qF 'a.person@example.invalid' && section_of "$SKILL" Rules | grep -qi 'naming scheme'
}

echo "agentd-diagnose skill structure"
check "frontmatter name matches the folder" test_frontmatter_name_matches_folder
check "description starts with 'Use when' and covers root cause, bug, data and slow" test_description_starts_with_use_when_and_covers_the_jobs
check "the skill sets disable-model-invocation: true" test_skill_is_manual_only
check "SKILL.md is at most 160 lines" test_skill_is_at_most_160_lines
check "SKILL.md names the five reference files and each exists" test_every_referenced_file_exists
check "the seven H2 sections appear in order" test_required_h2_sections_in_order
check "no skill file has an absolute home path" test_skill_files_have_no_absolute_home_paths
check "Flow has seven numbered steps, in order" test_flow_has_seven_numbered_steps_in_order
check "Modes name the three references, the one-line pick and the follow-on item" test_modes_name_the_three_modes_and_the_mixed_ticket
check "Running commands has the scratch folder, confirmation, SELECT and headless rules" test_running_commands_has_the_run_rules
check "Evidence has four tiers and three markers" test_evidence_has_four_tiers_and_three_markers
check "Rules forbid code edits, repository files, installs and personal data" test_rules_forbid_code_edits_repo_files_installs_and_personal_data
check "the gate is in the skill and in the hand-off" test_the_gate_is_in_the_skill_and_the_hand_off
check "the hand-off tells the engineer to run the next skill" test_the_skill_never_starts_the_next_skill
check "bug.md covers the method" test_bug_reference_covers_the_method
check "data.md covers the four questions and privacy" test_data_reference_covers_the_four_questions_and_privacy
check "data.md hands a repair to /agentd-data-fix and keeps the stale backup wording out" test_data_repair_hand_off_names_the_data_fix_skill
check "performance.md has the seven mantras in order and the vetting" test_performance_reference_has_the_mantras_in_order_and_the_vetting
check "dotnet.md names where to look" test_dotnet_reference_names_where_to_look
check "ios.md names where to look" test_ios_reference_names_where_to_look
check "react.md names where to look" test_react_reference_names_where_to_look
check "report-template.md has the report headings in order" test_report_template_has_the_headings_in_order
check "the hand-off block has every field" test_hand_off_block_has_every_field
check "report-template.md has the three verdicts" test_report_template_has_the_three_verdicts
check "the scratch folder is optional and has a fallback for a harness that returns one message" test_the_scratch_folder_is_optional_and_has_a_fallback
check "data rules cover a read-only open, a copy, and large scans" test_data_rules_cover_read_only_open_and_large_scans
check "build output is covered, with no stack command in SKILL.md" test_build_output_is_covered
check "Modes allow a switch and the report says where it started" test_modes_can_switch_and_the_report_says_where_it_started
check "confirmed means the ticket's own failure" test_confirmed_means_the_tickets_own_failure
check "the report has Decisions needed and ends with the question when not confirmed" test_report_has_decisions_and_the_question_is_last
check "bug.md covers an ID the test data lacks" test_bug_reference_covers_an_id_the_test_data_lacks
check "performance.md is not tied to one stack's build name" test_performance_reference_is_not_tied_to_one_stack
check "the three verdicts are listed exactly on the Verdict line" test_the_verdict_line_lists_the_three_verdicts_exactly
check "instrumentation never edits the repository" test_instrumentation_never_edits_the_repository
check "a new command needs its own confirmation, and keep investigating restarts the plan" test_a_new_command_needs_its_own_confirmation_and_keep_investigating_restarts_the_plan
check "a build may restore declared packages and nothing else is installed" test_a_build_may_restore_declared_packages_but_nothing_else_is_installed
check "build and test output is the one exception to no repository files" test_build_and_test_output_is_the_one_exception_to_no_repository_files
check "the closing line depends on the verdict" test_the_closing_line_depends_on_the_verdict
check "database copies are for file databases only, and SELECT ... INTO is not SELECT" test_database_copies_are_for_file_databases_only_and_select_into_is_not_select
check "the hand-off block opens with the confidence line" test_the_hand_off_block_opens_with_the_confidence_line
check "performance verdicts map to the report verdicts and the test guards the cost" test_performance_verdicts_map_to_the_report_verdicts_and_the_test_guards_the_cost
check "no phrase is copied from the pstack originals" test_no_phrase_is_copied_from_pstack
check "no tracked file is changed, including configuration, and instrumentation uses an environment variable" test_rules_cover_configuration_files_and_instrumentation_without_edits
check "data mode runs no query without a Data access heading" test_data_without_a_data_access_heading_runs_no_query
check "data confirmation and a cause that is not live are defined" test_data_confirmation_and_a_cause_that_is_not_live_are_defined
check "the hand-off never names a scratch path and allows no code fix" test_the_hand_off_never_names_a_scratch_path_and_allows_no_code_fix
check "query safety closes the SELECT holes" test_query_safety_rules_close_the_select_holes
check "read-only inspection needs no confirmation, and tests skip shared resources" test_read_only_inspection_needs_no_confirmation_and_tests_skip_shared_resources
check "the Mode line is conditional and the gate names both verdicts" test_the_mode_line_and_the_gate_are_conditional_and_complete
check "an example value is invented, not taken from the data" test_examples_use_invented_values_not_data_values
check "the closing line follows the hand-off block, and a missing write date keeps a cause supported" test_the_closing_line_comes_after_the_hand_off_block_and_a_missing_write_date_keeps_it_supported
check "a unit test with its own temp folder is safe, and a read-only connection is the fallback" test_unit_tests_that_use_their_own_temp_folder_are_safe_and_a_read_only_connection_is_the_fallback
check "the ticket may name a person, and a mixed ticket keeps the code fix in the hand-off" test_the_ticket_may_name_a_person_and_mixed_tickets_keep_the_code_fix_in_the_hand_off
check "data.md says which date to use, and the two Not verdicts are defined" test_data_dates_and_the_two_not_verdicts_are_defined
check "no skill file names an outside skill" test_the_skill_files_name_no_outside_skill
check "the references hold the borrowed debugging ideas" test_the_borrowed_debugging_ideas_are_in_the_references
check "Narrow has the working case, the boundary check, the same-fault search and the Design concern" test_narrow_has_the_working_case_the_boundary_check_and_the_design_concern
check "the six stop signs sit in Flow" test_the_six_stop_signs_sit_in_flow
check "the round 2 rules have their text" test_the_new_rules_have_their_text
check "the Design concern is in the report and not in the hand-off block" test_the_design_concern_is_in_the_report_and_not_in_the_hand_off_block
check "an example value does not follow the data's pattern" test_example_values_do_not_follow_the_data_pattern

echo
echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
