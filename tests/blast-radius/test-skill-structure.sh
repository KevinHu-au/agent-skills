#!/usr/bin/env bash
# Structure and wording tests for the agentd-blast-radius skill files. Reads the skill files and writes nothing.
# The check that every skill sets disable-model-invocation lives in tests/onboard/test-skill-structure.sh.
# Usage: tests/blast-radius/test-skill-structure.sh
set -u

HERE=$(cd "$(dirname "$0")" && pwd -P)
REPO=$(cd "$HERE/../.." && pwd -P)
SKILL_DIR=${SKILL_DIR:-$REPO/skills/agentd-blast-radius}
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

REFERENCES="dotnet.md report-template.md surfaces.md"

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

# section_has <file> <heading> <text>...: the section contains every text, ignoring case.
section_has() {
  local f=$1 h=$2 s t
  shift 2
  s=$(section_of "$f" "$h")
  [ -n "$s" ] || return 1
  for t in "$@"; do printf '%s\n' "$s" | grep -qiF -- "$t" || return 1; done
}

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
  [ "$(frontmatter_value name)" = "agentd-blast-radius" ] && [ "$(basename "$SKILL_DIR")" = "agentd-blast-radius" ]
}

test_description_starts_with_use_when_and_covers_the_job() {
  local d
  d=$(frontmatter_value description)
  case "$d" in "Use when "*) ;; *) return 1 ;; esac
  printf '%s\n' "$d" | grep -qi 'break' &&
    printf '%s\n' "$d" | grep -qi 'prove' &&
    printf '%s\n' "$d" | grep -qi 'safe' &&
    printf '%s\n' "$d" | grep -qi 'edits no code'
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
    [ "$(h2_list "$SKILL" | tr '\n' '|')" = "Prerequisite|Flow|Verdicts|Running commands|Evidence|Output|Rules|" ]
}

test_skill_files_have_no_absolute_home_paths() {
  [ -f "$SKILL" ] || return 1
  ! grep -qE '/Users/|/home/|~/' "$SKILL" "$REFS"/*.md 2>/dev/null
}

test_general_files_name_no_stack_command() {
  [ -f "$SKILL" ] || return 1
  ! grep -qiE 'dotnet (build|test|run|ef)|npm (test|run|install)|pytest|python3' \
    "$SKILL" "$REFS/surfaces.md" "$REFS/report-template.md" 2>/dev/null
}

test_prerequisite_takes_either_input_and_reads_the_contract() {
  section_has "$SKILL" Prerequisite 'git rev-parse --show-toplevel' 'agentd-blast-radius needs a git repository' \
    'hand-off block' 'description' 'branch diff' 'staged' 'once' \
    'AGENTS.md' 'Risk areas' 'External systems and owners' 'docs/onboarding/README.md'
}

test_flow_has_seven_numbered_steps_in_order() {
  [ -f "$SKILL" ] || return 1
  [ "$(section_of "$SKILL" Flow | grep -oE '^[0-9]+\. \*\*[A-Za-z ]+\.\*\*' | sed 's/\*//g; s/\.$//' | tr '\n' '|')" = \
    "1. Read the change|2. Find the safety fact|3. Map where search stops|4. Run plan|5. Prove|6. Gate|7. Report|" ]
}

test_the_safety_fact_is_one_claim_a_run_can_check_and_may_be_absent() {
  section_has "$SKILL" Flow 'one claim' 'true or false' 'no single safety fact' 'on its own'
}

test_search_is_the_start_and_the_surfaces_reference_is_read() {
  section_has "$SKILL" Flow 'references/surfaces.md' 'only the surfaces' 'start, not the result'
}

test_proof_runs_real_code_at_the_pinned_library_version() {
  section_has "$SKILL" Flow 'real code' 'version' 'verbatim'
}

test_dotnet_reference_is_loaded_for_dotnet_only() {
  grep -qE 'references/dotnet\.md' "$SKILL" && grep -qi '\.NET' "$SKILL"
}

test_verdicts_are_defined_and_the_gate_asks_the_question() {
  section_has "$SKILL" Verdicts 'Contained' 'Breaks' 'Unproven' 'get more evidence' 'hand off anyway' &&
    section_has "$SKILL" Flow 'Unproven' 'hand off anyway'
}

test_running_commands_has_the_run_rules() {
  section_has "$SKILL" "Running commands" 'mktemp -d' 'removed after the report' 'only after you have shown the report' \
    'delete nothing else' 'one confirmation' 'SELECT' 'Data access' 'nobody' 'safe checks only' \
    'Scratch folder: none' 'needs its own confirmation' 'configured database'
}

test_running_commands_never_writes_to_a_shared_environment_or_installs() {
  section_has "$SKILL" "Running commands" 'Never' 'shared environment' 'install' 'outside system'
}

test_a_proposed_change_runs_on_a_copy_and_a_branch_is_exported_not_checked_out() {
  section_has "$SKILL" "Running commands" 'apply the change to the copy' 'git archive' 'never check it out' &&
    section_has "$SKILL" Prerequisite 'do not switch branches'
}

test_evidence_has_four_tiers_and_three_markers() {
  local s t m
  s=$(section_of "$SKILL" Evidence)
  [ -n "$s" ] || return 1
  for t in 'confirmed' 'supported' 'inferred' 'unknown'; do printf '%s\n' "$s" | grep -qi "$t" || return 1; done
  for m in 'unknown:' 'inferred:' 'conflict:'; do printf '%s\n' "$s" | grep -qF "$m" || return 1; done
}

test_confirmed_needs_a_run_and_a_search_that_finds_nothing_is_still_an_answer() {
  section_has "$SKILL" Evidence 'needs a run' 'finds nothing' 'path:line'
}

test_output_closing_line_depends_on_the_verdict_and_the_skill_never_starts_the_next() {
  section_has "$SKILL" Output 'closing line' 'the question' '/agentd-dev-rev' 'cannot start'
}

test_rules_forbid_code_edits_repo_files_installs_personal_data_and_invented_callers() {
  section_has "$SKILL" Rules 'Edit no code' 'no file in the repository' 'personal data' 'Azure DevOps' 'install' \
    'One repository per run' 'Never invent a caller'
}

test_rules_say_a_list_of_callers_is_not_the_finding() {
  section_has "$SKILL" Rules 'list of callers'
}

test_report_template_has_the_headings_in_order() {
  in_order "$REFS/report-template.md" '### What changes' '### The safety fact' '### Risks' '### Cleared' \
    '### Not checked' '### Before you merge'
}

test_report_template_has_the_three_verdicts_on_one_line() {
  grep -qF 'Verdict: Contained | Breaks | Unproven' "$REFS/report-template.md"
}

test_the_risk_table_has_how_where_likelihood_cost_tier_and_check() {
  has_all "$REFS/report-template.md" '| How it breaks | Where (path:line) | Likelihood | Cost | Tier | How to check |'
}

test_add_on_block_has_every_field_in_order() {
  in_order "$REFS/report-template.md" 'Blast radius:' 'Safety fact:' 'Risks to cover:' 'Tests to write first:' \
    'Do not change:' 'Warn or coordinate:' 'Stop condition:'
}

test_add_on_block_is_self_contained_and_names_no_scratch_path() {
  has_all "$REFS/report-template.md" 'never name a path in the scratch folder' 'Inline' 'next to the diagnose block'
}

test_unproven_hand_off_anyway_changes_the_block() {
  has_all "$REFS/report-template.md" 'Blast radius: Unproven' 'prove the fact' 'stop' 'Do not write the `/agentd-dev-rev` line'
}

# Rules added after the first agent runs (EVAL.md will record the iterations).
test_the_add_on_block_waits_for_the_answer_when_unproven() {
  has_all "$REFS/report-template.md" 'Write it when the verdict is Contained or Breaks' 'only after the engineer says to hand off anyway' &&
    ! grep -qiF 'Write it for every verdict' "$REFS/report-template.md" &&
    section_has "$SKILL" Output 'no add-on block until the engineer says to hand off anyway'
}

test_staged_runs_the_no_fact_case_and_the_unproven_tier_rules_are_written() {
  section_has "$SKILL" "Running commands" 'Staged changes' 'git checkout-index' 'not in the working tree' &&
    section_has "$SKILL" Verdicts 'Cleared means' 'With no safety fact' &&
    has_all "$REFS/report-template.md" 'Safety fact: none: <why>' 'never `confirmed`' 'most severe open risk' '<base>...<head>'
}

test_with_no_scratch_folder_the_change_runs_in_memory() {
  section_has "$SKILL" "Running commands" 'in memory' 'memory database' 'git show'
}

test_risks_hold_open_and_confirmed_risks_and_a_test_of_the_old_behaviour_is_a_planned_cost() {
  has_all "$REFS/report-template.md" 'any tier' 'ruled out' 'encodes the old behaviour' 'cost to plan for'
}

test_a_clean_run_on_our_side_is_not_contained_when_the_fact_is_outside() {
  section_has "$SKILL" Verdicts 'a side you cannot run'
}

test_a_search_that_finds_no_caller_is_supported_and_never_confirmed() {
  section_has "$SKILL" Evidence 'finds no caller' 'never confirms'
}

test_surfaces_reference_covers_every_surface() {
  has_all "$REFS/surfaces.md" 'wire shape' 'mobile' 'old version' 'enum' 'time zone' 'stored procedure' 'view' 'trigger' \
    'export' 'feature flag' 'configuration key' 'dependency injection' 'reflection' 'queue' 'transaction' 'cache' \
    'idempot' 'same bytes' 'generated' 'library' 'local patch' 'authorisation' 'External systems and owners' \
    'unknown: ask' 'encode the old behaviour'
}

test_dotnet_reference_names_where_to_look_and_says_it_is_unchecked() {
  has_all "$REFS/dotnet.md" 'JsonPropertyName' 'Program.cs' 'model snapshot' 'sys.sql_modules' 'general knowledge' \
    'not yet checked'
}

# Phrases from the pstack original that must not come back. Our wording is our own.
test_no_phrase_is_copied_from_pstack() {
  local p
  [ -s "$SKILL" ] || return 1
  for p in "don't trust your own writeup" 'listing the callers is not the job' 'the agent can grep those in a second' \
    'reads as convincing whether or not' 'looks risky are safe because of a single fact' \
    'a search that finds nothing is still an answer' 'different models catch different real bugs' \
    "fails loud if you're wrong" 'the breakage grep won'; do
    if grep -qiF -- "$p" "$SKILL" "$REFS"/*.md; then return 1; fi
  done
}

echo "agentd-blast-radius skill structure"
check "frontmatter name matches the folder" test_frontmatter_name_matches_folder
check "description starts with 'Use when' and covers break, prove, safe and edits no code" test_description_starts_with_use_when_and_covers_the_job
check "the skill sets disable-model-invocation: true" test_skill_is_manual_only
check "SKILL.md is at most 160 lines" test_skill_is_at_most_160_lines
check "SKILL.md names the three reference files and each exists" test_every_referenced_file_exists
check "the seven H2 sections appear in order" test_required_h2_sections_in_order
check "no skill file has an absolute home path" test_skill_files_have_no_absolute_home_paths
check "general files name no stack command" test_general_files_name_no_stack_command
check "Prerequisite takes either input and reads the contract and the onboarding pack" test_prerequisite_takes_either_input_and_reads_the_contract
check "Flow has seven numbered steps, in order" test_flow_has_seven_numbered_steps_in_order
check "the safety fact is one claim a run can check, and may be absent" test_the_safety_fact_is_one_claim_a_run_can_check_and_may_be_absent
check "search is the start and the surfaces reference is read" test_search_is_the_start_and_the_surfaces_reference_is_read
check "the proof runs real code at the shipped library version and is pasted verbatim" test_proof_runs_real_code_at_the_pinned_library_version
check "the .NET reference is loaded for a .NET project" test_dotnet_reference_is_loaded_for_dotnet_only
check "the verdicts are defined and the gate asks the question" test_verdicts_are_defined_and_the_gate_asks_the_question
check "Running commands has the scratch folder, confirmation, SELECT and headless rules" test_running_commands_has_the_run_rules
check "Running commands never writes to a shared environment, calls an outside system or installs" test_running_commands_never_writes_to_a_shared_environment_or_installs
check "a proposed change runs on a copy, and a branch is exported and never checked out" test_a_proposed_change_runs_on_a_copy_and_a_branch_is_exported_not_checked_out
check "Evidence has four tiers and three markers" test_evidence_has_four_tiers_and_three_markers
check "confirmed needs a run, and a search that finds nothing is still an answer" test_confirmed_needs_a_run_and_a_search_that_finds_nothing_is_still_an_answer
check "the closing line depends on the verdict and the skill never starts the next skill" test_output_closing_line_depends_on_the_verdict_and_the_skill_never_starts_the_next
check "Rules forbid code edits, repository files, installs, personal data and invented callers" test_rules_forbid_code_edits_repo_files_installs_personal_data_and_invented_callers
check "Rules say a list of callers is not the finding" test_rules_say_a_list_of_callers_is_not_the_finding
check "report-template.md has the report headings in order" test_report_template_has_the_headings_in_order
check "the Verdict line lists the three verdicts exactly" test_report_template_has_the_three_verdicts_on_one_line
check "the risk table has the six columns" test_the_risk_table_has_how_where_likelihood_cost_tier_and_check
check "the add-on block has every field, in order" test_add_on_block_has_every_field_in_order
check "the add-on block is self-contained and names no scratch path" test_add_on_block_is_self_contained_and_names_no_scratch_path
check "hand off anyway on Unproven changes the block" test_unproven_hand_off_anyway_changes_the_block
check "the add-on block waits for the answer when the verdict is Unproven" test_the_add_on_block_waits_for_the_answer_when_unproven
check "with no scratch folder the change runs in memory" test_with_no_scratch_folder_the_change_runs_in_memory
check "Risks hold open and confirmed risks, and a test of the old behaviour is a planned cost" test_risks_hold_open_and_confirmed_risks_and_a_test_of_the_old_behaviour_is_a_planned_cost
check "a clean run on our side is not Contained when the fact is outside" test_a_clean_run_on_our_side_is_not_contained_when_the_fact_is_outside
check "a search that finds no caller is supported and never confirmed" test_a_search_that_finds_no_caller_is_supported_and_never_confirmed
check "staged runs, the no-fact case and the Unproven tier rules are written" test_staged_runs_the_no_fact_case_and_the_unproven_tier_rules_are_written
check "surfaces.md covers every surface" test_surfaces_reference_covers_every_surface
check "dotnet.md names where to look and says it is unchecked" test_dotnet_reference_names_where_to_look_and_says_it_is_unchecked
check "no phrase is copied from the pstack original" test_no_phrase_is_copied_from_pstack

echo
echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
