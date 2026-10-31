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

REFERENCES="bug.md data.md dotnet.md generic.md ios.md performance.md react.md report-template.md"

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

# section_of <file> <heading>: the lines under one H2 heading. A heading inside a fenced block does not start or end a
# section. A fence closes only on a run of the same character, at least as long as the one that opened it.
section_of() {
  awk -v h="## $2" '
    /^[ ]*(```|~~~)/ {
      s = $0; sub(/^[ ]*/, "", s); c = substr(s, 1, 1); n = 0
      while (substr(s, n + 1, 1) == c) n++
      if (fl == 0) { fc = c; fl = n } else if (c == fc && n >= fl && substr(s, n + 1) ~ /^[ ]*$/) { fl = 0 }
      if (on) print
      next
    }
    fl == 0 && $0 == h { on = 1; next }
    fl == 0 && /^## / { on = 0 }
    on
  ' "$1"
}

# hand_off_block: the lines inside the four-backtick markdown fence of the report template, without the fence lines.
hand_off_block() { awk '$0 == "````" { on = 0 } on; $0 == "````markdown" { on = 1 }' "$REFS/report-template.md"; }

# hand_off_section <heading>: the lines under one H2 heading of the hand-off block.
hand_off_section() { hand_off_block | section_of - "$1"; }

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
    has_all "$REFS/report-template.md" '**Confidence:** hypothesis, not confirmed'
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
  for p in '/agentd-data-fix' 'with the work item' 'and the hand-off block as extra facts' 'Follow-on' 'do not write the repair'; do
    printf '%s\n' "$s" | grep -qiF -- "$p" || return 1
  done
  ! printf '%s\n' "$s" | grep -qiE 'a backup, a rollback|no skill runs it yet'
}

test_report_template_hands_a_data_repair_to_the_data_fix_skill() {
  local t="$REFS/report-template.md" hb nc
  hb=$(section_of "$t" 'Hand-off block')
  nc=$(section_of "$t" 'When the cause is not confirmed')
  hand_off_section 'Follow-on' | grep -qF 'with the work item' &&
    hand_off_section 'Follow-on' | grep -qF '/agentd-data-fix' &&
    hand_off_section 'Follow-on' | grep -qF '| none' &&
    printf '%s\n' "$hb" | grep -qE 'Proposed fix is .none:., first name any other Follow-on problem' &&
    printf '%s\n' "$hb" | grep -qE 'instead of .?/agentd-dev-rev' &&
    ! printf '%s\n' "$hb" | grep -qiE 'both lines|as well as|also end' &&
    printf '%s\n' "$hb" | grep -qF 'with the work item, and paste this report and the hand-off block as extra facts (it writes T-SQL only)' &&
    printf '%s\n' "$nc" | grep -qF 'Do not write a closing line (`/agentd-dev-rev`, `/agentd-blast-radius` or `/agentd-data-fix`) until the engineer says to hand off' &&
    printf '%s\n' "$nc" | grep -qF 'When Proposed fix is `none:`, leave out' &&
    printf '%s\n' "$nc" | grep -qF 'Otherwise end with the `/agentd-dev-rev` line' &&
    section_of "$SKILL" Output | grep -qF 'when Proposed fix is `none:`, `/agentd-data-fix` with the work item, and paste the report and the hand-off block as extra facts'
}

test_performance_reference_has_the_mantras_in_order_and_the_vetting() {
  in_order "$REFS/performance.md" "don't do it" "don't do it again" 'do it less' 'do it later' \
    "when they're not looking" 'do it concurrently' 'do it cheaper' &&
    has_all "$REFS/performance.md" '5 runs' 'median' 'limiter' 'end to end'
}

# dotnet_section_has <heading> <text>...: the section of dotnet.md holds every text, ignoring case.
dotnet_section_has() {
  local h=$1 body t
  shift
  body=$(section_of "$REFS/dotnet.md" "$h")
  [ -n "$body" ] || return 1
  for t in "$@"; do printf '%s\n' "$body" | grep -qiF -- "$t" || return 1; done
}

# dotnet_line_has <section> <text> <text>...: the first line of that section of dotnet.md that holds the first text also
# holds every other text.
dotnet_line_has() {
  local sec=$1 first=$2 t line
  shift 2
  line=$(section_of "$REFS/dotnet.md" "$sec" | grep -F -- "$first" | head -n 1)
  [ -n "$line" ] || return 1
  for t in "$@"; do printf '%s\n' "$line" | grep -qF -- "$t" || return 1; done
}

test_dotnet_reference_separates_framework_and_core() {
  grep -qF 'it says how to tell .NET Framework from .NET Core' "$SKILL" &&
    dotnet_section_has "Which kind of project" 'TargetFrameworkVersion' 'net48' 'netcoreapp3.1' 'net8.0-windows' \
      'TargetFrameworks' 'netstandard2.0' 'Windows service' &&
    dotnet_section_has "Run and count tests" 'vstest.console.exe' '/ListTests' 'NUnit' '--filter' &&
    dotnet_section_has "Bug candidates" 'Global.asax.cs' 'Autofac' 'lazy loading' 'deadlock' 'HttpContext.Current' 'web.config' &&
    dotnet_section_has "Production dumps" 'dotnet-dump analyze' 'WinDbg' 'SOS' '!clrstack' 'procdump' 'Install nothing' &&
    dotnet_section_has "Performance candidates" 'EF6' 'Database.Log' 'Extended Events' 'Performance Monitor' 'PerfView' \
      'dotnet-counters' 'dotnet-trace' &&
    # Each kind's tools sit on the line for that kind, and not on the other kind's line.
    dotnet_line_has "Production dumps" 'dotnet-dump analyze' '.NET Core' &&
    ! dotnet_line_has "Production dumps" 'dotnet-dump analyze' 'WinDbg' &&
    ! dotnet_line_has "Production dumps" 'dotnet-dump analyze' '!clrstack ' &&
    dotnet_line_has "Production dumps" 'WinDbg' '.NET Framework' 'procdump' '!clrstack' 'SOS' &&
    dotnet_line_has "Performance candidates" 'Database.Log' 'EF6' 'scratch folder' 'parameter values' &&
    dotnet_line_has "Performance candidates" 'dotnet-counters' '.NET Core' &&
    ! dotnet_line_has "Performance candidates" 'dotnet-counters' 'PerfView' &&
    dotnet_line_has "Performance candidates" 'PerfView' '.NET Framework' 'Performance Monitor' &&
    dotnet_line_has "Bug candidates" 'Lazy loading' 'EF6' 'EF Core' 'virtual' &&
    dotnet_line_has "Bug candidates" 'HttpContext.Current' '.NET Framework' &&
    dotnet_line_has "Bug candidates" 'deadlock' 'ASP.NET Core' 'thread pool' 'WPF' 'ConfigureAwait(false)'
}

test_dotnet_reference_names_where_to_look() {
  has_all "$REFS/dotnet.md" '--filter' 'N+1' 'Release' 'dotnet-counters' 'dotnet-trace' 'zero'
}

test_report_template_has_the_headings_in_order() {
  in_order "$REFS/report-template.md" '### Problem' '### Reproduction' '### Root cause' '### Evidence' \
    '### Competing causes' '### Proposed fix' '### Not checked'
}

test_hand_off_block_has_every_field() {
  [ "$(hand_off_block | grep -E '^## ' | sed 's/^## //' | tr '\n' '|')" = \
    "Task|Root cause|Failing test first|Proposed fix|Do not change|Risk areas|Blast radius|Verification|Follow-on|" ] &&
    hand_off_block | grep -qxF '**Confidence:** confirmed' &&
    hand_off_section 'Task' | grep -qF '**Fixed means:**' &&
    hand_off_section 'Root cause' | grep -qF '**Evidence:**' &&
    hand_off_section 'Failing test first' | grep -qF '**Location:**' &&
    hand_off_section 'Failing test first' | grep -qF -- '- **Before the fix:**'
}

test_the_hand_off_block_is_markdown_in_a_four_backtick_fence() {
  [ "$(grep -c '^````markdown$' "$REFS/report-template.md")" = 1 ] &&
    [ "$(hand_off_block | head -1)" = '# Hand-off block' ] &&
    [ "$(hand_off_block | awk 'NF' | sed -n 2p)" = '**Confidence:** confirmed' ] &&
    hand_off_section 'Verification' | grep -qF '1. Run the reproduction command:' &&
    has_all "$REFS/report-template.md" 'It stays the first line after the `# Hand-off block` title' \
      'One more section at the end of the block, after Follow-on: `## Stop condition`' \
      'With no stop line, leave the section out' &&
    [ "$(hand_off_section 'Verification' | grep -c '^   ```$')" = 2 ] &&
    section_of "$REFS/report-template.md" 'Hand-off block' | grep -qF 'fence of four backticks with the `markdown` tag'
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
  in_order "$REFS/report-template.md" '**Confidence:** confirmed' '## Task'
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
    grep -qF 'For a React web project also read `references/react.md`' "$SKILL"
}

test_generic_reference_covers_an_unknown_stack() {
  [ "$(h2_list "$REFS/generic.md" | tr '\n' '|')" = 'Run and count tests|Configuration layers|Wiring and dependency injection|Migrations and the database|Bug candidates|Data candidates|Performance candidates|' ] &&
    has_all "$REFS/generic.md" 'inferred:' 'confirmed:' 'general knowledge' 'not yet checked' 'matches no test' 'exit 0' 'the total' \
      'composition root' 'migration tool' 'ask the engineer' &&
    grep -qF 'For a stack with no reference, read `references/generic.md`. Its facts stay `inferred:` until a run, a query or a measurement shows them.' "$SKILL"
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
  has_all "$REFS/bug.md" 'whole error' 'working case' 'backward' 'fixed sleep' 'worktree' 'git stash' &&
    has_all "$REFS/data.md" 'good rows' 'stages' 'cannot read' &&
    has_all "$REFS/performance.md" 'Time each layer' 'fast case' 'worktree'
}

# Old commits run in a worktree in the scratch folder. Bisect runs only there, with a script that exits 0, 1 or 125 and
# fails for the ticket's own reason, and it ends with a reset that takes no options. git archive is the fallback.
test_old_commits_use_a_worktree_and_bisect_runs_only_there() {
  local r b
  r=$(section_of "$SKILL" 'Running commands' | grep -F -- '- **Old commits:**')
  for t in 'git -c core.hooksPath=/dev/null worktree add --detach <scratch>/wt-<name> <ref>' 'turns off the repository' \
    'submodule update --init' 'it needs the network' 'Without `git-lfs`, large files stay pointers' '.git/worktrees/' \
    "writes the submodule entries into the repository's \`.git/config\`" \
    'list each `git worktree add`, the submodule update, any `git bisect` and each `git worktree remove --force <scratch>/wt-<name>`' \
    'fails at setup' 'Do not fall back to `git archive` then' 'Never remove any other worktree' \
    'Never run `git worktree prune`' 'Never check out, stash or bisect in the repository itself' \
    'With no scratch folder, read old files with `git show <ref>:<path>`' \
    'Only if the `git worktree` command is unavailable or unsupported' 'no submodules, no LFS content and no `.git`'; do
    printf '%s\n' "$r" | grep -qiF -- "$t" || return 1
  done
  # Each worktree is removed before the scratch folder, and prune is never an instruction to run.
  [[ "${r%%remove the scratch folder*}" == *'run `git worktree remove --force` on each worktree you added'* ]] || return 1
  local f
  for f in "$SKILL" "$REFS/bug.md" "$REFS/performance.md"; do
    [ "$(grep -o 'git worktree prune' "$f" | wc -l)" -eq "$(grep -o 'Never run `git worktree prune`' "$f" | wc -l)" ] || return 1
  done
  section_of "$SKILL" 'Running commands' | grep -qF 'Delete nothing else, except the worktrees that Old commits adds and removes' || return 1
  b=$(grep -F 'bisect in a worktree of its own' "$REFS/bug.md")
  for t in 'git -c core.hooksPath=/dev/null -C <scratch>/wt-bisect bisect start <bad> <good>' 'bisect run <script>' \
    'with the `git archive` fallback or no scratch folder, do not bisect' 'exits 125 if that fails' 'exits 0 for good, 1 for bad, and 125' \
    "must fail for the ticket's own reason" 'on its parent' '<scratch>/wt-bisect bisect reset`, with no options' 'not why' \
    'every remaining commit is skipped' 'do not name the nearest commit' 'means the first parent'; do
    printf '%s\n' "$b" | grep -qF -- "$t" || return 1
  done
  has_all "$REFS/bug.md" 'Never run `git checkout`, `git stash` or `git bisect` in the repository itself' &&
    ! grep -qF 'git bisect` in the repository.' "$REFS/bug.md"
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

# Blast-radius step (plan change 2): only when the fix touches a contract, schema, shared code or an external system.
test_blast_radius_only_for_contract_schema_shared_code_or_external() {
  local t="$REFS/report-template.md"
  section_of "$SKILL" Output | grep -F '/agentd-blast-radius' | grep -i 'contract' | grep -i 'schema' |
    grep -i 'shared code' | grep -qi 'external system' &&
    section_of "$SKILL" Rules | grep -F '/agentd-blast-radius' | grep -qi 'shared code' &&
    hand_off_section 'Blast radius' | grep -qE '^needed:' &&
    hand_off_section 'Blast radius' | grep -qF 'not needed:' &&
    section_of "$t" 'Hand-off block' | grep -qF 'When Blast radius is `needed:`, end with this line instead: Run `/agentd-blast-radius` and paste the hand-off block. Then run `/agentd-dev-rev` and paste the hand-off block and the blast-radius add-on block.' &&
    section_of "$t" 'When the cause is not confirmed' | grep -qF 'or the `/agentd-blast-radius` line when Blast radius is `needed:`'
}

test_a_data_repair_needs_no_blast_radius() {
  section_of "$REFS/report-template.md" 'Hand-off block' | grep -qF 'write `not needed: no code fix` under Blast radius'
}

# Diagnose reuses a pasted intake comment in Frame.
test_frame_reuses_an_intake_comment() {
  local f
  f=$(section_of "$SKILL" Flow | grep -E '^1\. \*\*Frame')
  printf '%s\n' "$f" | grep -qF 'intake comment and its engineer block' &&
    printf '%s\n' "$f" | grep -qi 'ask only for what they leave open' &&
    printf '%s\n' "$f" | grep -qi 'leads to check, not findings' &&
    printf '%s\n' "$f" | grep -qF 'Requirement: unconfirmed' &&
    printf '%s\n' "$f" | grep -qi 'Stop condition into the hand-off block' &&
    section_of "$SKILL" Prerequisite | grep -qi 'intake comment'
}

test_example_values_do_not_follow_the_data_pattern() {
  section_of "$SKILL" Rules | grep -qF 'a.person@example.invalid' && section_of "$SKILL" Rules | grep -qi 'naming scheme'
}

# Production evidence: a person runs the query and pastes the result. The skill runs nothing against production.
test_production_evidence_is_run_by_a_person() {
  section_of "$SKILL" 'Running commands' | grep -qF 'never runs anything against production' &&
    section_of "$SKILL" 'Running commands' | grep -qi 'DBA' &&
    has_all "$REFS/bug.md" '## Production evidence' 'KQL' 'DBA' 'correlation ID' 'Redaction' 'crash report or dump'
}

test_production_evidence_alone_is_supported() {
  local ev
  ev=$(section_of "$SKILL" Evidence)
  # The `confirmed:` bullet holds the one definition, with both exceptions and their conditions.
  local c s
  c=$(printf '%s\n' "$ev" | grep -F -- '- **confirmed:**')
  s=$(printf '%s\n' "$ev" | grep -F -- '- **supported:**')
  for t in 'counts for the fact it shows' 'A root cause is confirmed by a run that shows the ticket' \
    'Two cases need no local run' 'that state is on the path of the failing call' \
    "the first failure in the log fits it" 'actual row counts' 'account for the reported slowness' \
    '`references/data.md`, Confirmation'; do
    printf '%s\n' "$c" | grep -qF -- "$t" || return 1
  done
  printf '%s\n' "$s" | grep -qF 'is `supported` at most for the root cause' &&
    printf '%s\n' "$s" | grep -qF 'a pasted SQL result that shows only a symptom' &&
    # Gate and Reproduce point to Evidence, so the wording lives in one place.
    section_of "$SKILL" Flow | grep -qF 'see Evidence for what confirms' &&
    section_of "$SKILL" Flow | grep -qF 'or a case under `confirmed` in Evidence' &&
    section_of "$SKILL" Flow | grep -qF 'give the verdict Not confirmed and stop' &&
    has_all "$REFS/bug.md" 'Production evidence alone is `supported` for the root cause' \
      'A code cause is `confirmed` only when a local run' 'under the conditions in SKILL.md, Evidence' &&
    has_all "$REFS/performance.md" 'plan-level claim' 'is `confirmed` when the actual plan comes from the same environment' \
      'account for the reported slowness' 'Never copy a production database' 'names the limiter'
}

# Every mode reaches the production evidence and environment sections, and production is never queried by the skill.
test_every_mode_reaches_production_evidence_and_never_queries_production() {
  section_of "$SKILL" Modes | grep -qF 'In every mode' &&
    section_of "$SKILL" Modes | grep -qF 'Environment differences' &&
    section_of "$SKILL" 'Running commands' | grep -qF 'includes a read replica' &&
    section_of "$SKILL" 'Running commands' | grep -qF 'Never production' &&
    has_all "$REFS/data.md" 'Never run a query on production, including a read replica' '`references/bug.md`, Production evidence'
}

test_environment_differences_are_candidates() {
  local s
  s=$(section_of "$REFS/bug.md" 'Environment differences')
  for t in '- Certificates:' '- DNS, proxy, firewall or TLS version.' '- Permissions:' '- Versions:' 'feature flag' \
    'server time zone' '- Resources:' '- Data: a row or a volume that only production has.'; do
    printf '%s\n' "$s" | grep -qF -- "$t" || return 1
  done
}

test_performance_accepts_a_pasted_plan() {
  local s
  s=$(section_of "$REFS/performance.md" 'Production evidence')
  for t in 'actual execution plan' 'estimated plan is not enough' 'Query Store' 'DBA' '**Redaction:**' \
    'ParameterRuntimeValue'; do
    printf '%s\n' "$s" | grep -qF -- "$t" || return 1
  done
}

test_dump_and_ips_steps_exist() {
  has_all "$REFS/dotnet.md" '## Production dumps' 'dotnet-dump analyze' 'Install nothing' \
    'only after you remove names, emails, IDs and user paths' &&
    has_all "$REFS/ios.md" 'two JSON documents' 'usedImages[imageIndex]' 'is not an `.ips` file' 'dwarfdump --uuid' \
      'atos' 'Install nothing'
}

# Escape is a report line (it feeds the failing test and the log-line suggestion), not a hand-off block line.
# It is filled in every mode, and a report that is not Confirmed says why it has no reason.
test_escape_line_is_in_the_report_only() {
  grep -qF 'Escape:' "$REFS/report-template.md" &&
    ! hand_off_block | grep -qF 'Escape:' &&
    has_all "$REFS/bug.md" '`Escape:` line' 'feeds the failing test' &&
    has_all "$REFS/report-template.md" 'Fill `Escape:` in every mode' 'Data: why the bad rows were not noticed' \
      'Performance: why no test' 'Escape: none: cause not confirmed' 'The last two carry no tier' 'never guess a reason'
}

# A confirmed environment cause has no code fix: the template says so and routes the engineer to the owner.
test_environment_cause_has_a_no_code_fix_hand_off() {
  has_all "$REFS/report-template.md" 'none: environment change' 'name the change and its owner under Follow-on' \
    'give the change to the owner' &&
    section_of "$SKILL" Output | grep -qF 'For an environment change, it tells the engineer to give the change to its owner'
}

# A fix in a second repository gets its own block, and the closing line names the repository.
test_second_repository_hand_off() {
  has_all "$REFS/report-template.md" 'If the cause or the fix sits in a second repository' 'name the repository under Task' \
    'Run /agentd-dev-rev in <repository>' 'One block for each repository'
}

# The React and iOS references offer the second-repository path where the server code is elsewhere.
test_stack_references_offer_the_second_repository_path() {
  local f
  for f in react.md ios.md; do
    has_all "$REFS/$f" 'ask the engineer for its path and read it as SKILL.md, Rules, says' || return 1
  done
}

# The SQL written for a DBA keeps the no-lock, no-write and no-full-count rules.
test_dba_sql_keeps_the_safe_query_rules() {
  has_all "$REFS/bug.md" 'SKILL.md, Running commands, Data apply to the text of the query' 'SELECT ... INTO' 'FOR UPDATE' \
    'no full count of a large table'
}

test_second_repository_is_read_only() {
  local r
  r=$(section_of "$SKILL" Rules)
  printf '%s\n' "$r" | grep -qF 'One repository per run' &&
    printf '%s\n' "$r" | grep -qi 'path of a second repository' &&
    printf '%s\n' "$r" | grep -qF 'read it too, read only, and put its name before each `path:line`' &&
    printf '%s\n' "$r" | grep -qF 'Run no code, build or test there' &&
    printf '%s\n' "$r" | grep -qF 'Read-only `git log` and `git blame` are allowed' &&
    printf '%s\n' "$r" | grep -qF 'run `/agentd-dev-rev` in that repository'
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
check "the report template hands a data repair to /agentd-data-fix, and the closing line follows" test_report_template_hands_a_data_repair_to_the_data_fix_skill
check "performance.md has the seven mantras in order and the vetting" test_performance_reference_has_the_mantras_in_order_and_the_vetting
check "generic.md covers an unknown stack and the SKILL.md points to it" test_generic_reference_covers_an_unknown_stack
check "dotnet.md names where to look" test_dotnet_reference_names_where_to_look
check "dotnet.md separates .NET Framework from .NET Core" test_dotnet_reference_separates_framework_and_core
check "ios.md names where to look" test_ios_reference_names_where_to_look
check "react.md names where to look" test_react_reference_names_where_to_look
check "report-template.md has the report headings in order" test_report_template_has_the_headings_in_order
check "the hand-off block has every field" test_hand_off_block_has_every_field
check "the hand-off block is Markdown in a four-backtick fence" test_the_hand_off_block_is_markdown_in_a_four_backtick_fence
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
check "blast-radius only for a contract, schema, shared code or external system" test_blast_radius_only_for_contract_schema_shared_code_or_external
check "a data repair needs no blast radius" test_a_data_repair_needs_no_blast_radius
check "Frame reuses a pasted intake comment" test_frame_reuses_an_intake_comment
check "production evidence: the engineer or a DBA runs the query and nothing runs against production" test_production_evidence_is_run_by_a_person
check "production evidence alone is supported and confirmed needs a local reproduction" test_production_evidence_alone_is_supported
check "every mode reaches production evidence, and the skill never queries production" test_every_mode_reaches_production_evidence_and_never_queries_production
check "environment differences are standard candidates" test_environment_differences_are_candidates
check "performance accepts a pasted plan and says what to ask the DBA for" test_performance_accepts_a_pasted_plan
check "the .NET dump and the iOS .ips steps are in the references" test_dump_and_ips_steps_exist
check "the Escape line is in the report and not in the hand-off block" test_escape_line_is_in_the_report_only
check "a second repository is read only with its name before each path" test_second_repository_is_read_only
check "a confirmed environment cause has a no-code-fix hand-off" test_environment_cause_has_a_no_code_fix_hand_off
check "a fix in a second repository gets its own block" test_second_repository_hand_off
check "the SQL written for a DBA keeps the safe query rules" test_dba_sql_keeps_the_safe_query_rules
check "the React and iOS references offer the second-repository path" test_stack_references_offer_the_second_repository_path
check "old commits use a worktree, and bisect runs only there" test_old_commits_use_a_worktree_and_bisect_runs_only_there

echo
echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
