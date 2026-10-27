#!/usr/bin/env bash
# Structure and wording tests for the agentd-intake skill files. Reads the skill files and writes nothing.
# The check that every skill sets disable-model-invocation lives in tests/onboard/test-skill-structure.sh.
# Usage: tests/intake/test-skill-structure.sh
set -u

HERE=$(cd "$(dirname "$0")" && pwd -P)
REPO=$(cd "$HERE/../.." && pwd -P)
SKILL_DIR=${SKILL_DIR:-$REPO/skills/agentd-intake}
SKILL="$SKILL_DIR/SKILL.md"
REFS="$SKILL_DIR/references"
TPL="$REFS/comment-template.md"
CHK="$REFS/question-checklist.md"
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
  local f=$1 t
  shift
  [ -s "$f" ] || return 1
  for t in "$@"; do grep -qiF -- "$t" "$f" || return 1; done
}

# has_all_cs <file> <text>...: the file contains every text, case-sensitive.
has_all_cs() {
  local f=$1 t
  shift
  [ -s "$f" ] || return 1
  for t in "$@"; do grep -qF -- "$t" "$f" || return 1; done
}

# h2_list <file>: the H2 headings of a markdown file, in order, one per line.
h2_list() { grep -E '^## ' "$1" | sed 's/^## //; s/[[:space:]]*$//'; }

# section_of <file> <heading>: the lines under one H2 heading.
section_of() { awk -v h="## $2" '$0 == h { on = 1; next } /^## / { on = 0 } on' "$1"; }

# section_has <file> <heading> <text>...: the section contains every text, ignoring case.
section_has() {
  local f=$1 h=$2 body t
  shift 2
  body=$(section_of "$f" "$h" 2>/dev/null)
  [ -n "$body" ] || return 1
  for t in "$@"; do printf '%s\n' "$body" | grep -qiF -- "$t" || return 1; done
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

# ---------------------------------------------------------------- SKILL.md

test_frontmatter_name_matches_folder() {
  [ "$(frontmatter_value name)" = "agentd-intake" ] && [ "$(basename "$SKILL_DIR")" = "agentd-intake" ]
}

test_description_starts_with_use_when_and_covers_the_job() {
  local d t
  d=$(frontmatter_value description)
  case "$d" in "Use when"*) ;; *) return 1 ;; esac
  for t in "work item" "actionable" "questions" "Edits no code"; do
    printf '%s\n' "$d" | grep -qiF -- "$t" || return 1
  done
}

test_skill_is_manual_only() {
  [ -s "$SKILL" ] || return 1
  awk 'NR == 1 && $0 != "---" { exit } /^---[ \t]*$/ { c++; if (c == 2) exit; next } c == 1' "$SKILL" |
    grep -qx 'disable-model-invocation: true'
}

test_skill_is_at_most_120_lines() {
  [ -s "$SKILL" ] && [ "$(wc -l <"$SKILL")" -le 120 ]
}

test_required_h2_sections_in_order() {
  [ -s "$SKILL" ] || return 1
  [ "$(h2_list "$SKILL" | tr '\n' '|')" = "Prerequisite|Flow|Verdicts|Output|Rules|" ]
}

test_flow_has_six_numbered_steps_in_order() {
  local body
  body=$(section_of "$SKILL" Flow 2>/dev/null)
  [ -n "$body" ] || return 1
  [ "$(printf '%s\n' "$body" | grep -E '^[0-9]+\. \*\*' | sed -E 's/^([0-9]+)\. \*\*([^*]*)\*\*.*/\1 \2/' |
    tr '\n' '|')" = '1 Read and classify.|2 Restate.|3 Check against the code.|4 Sharpen into questions.|5 Verdict and questions.|6 Gate.|' ]
}

test_the_two_verdicts_are_exact() {
  local body
  body=$(section_of "$SKILL" Verdicts 2>/dev/null)
  printf '%s\n' "$body" | grep -qF -- '**Actionable**' && printf '%s\n' "$body" | grep -qF -- '**Not actionable yet**'
}

test_an_unknown_cause_does_not_block_a_bug() { section_has "$SKILL" Verdicts "root cause" "/agentd-diagnose"; }

test_a_gap_blocks_only_without_a_safe_default() { section_has "$SKILL" Verdicts "safe default" "blocks"; }

test_types_are_listed() {
  has_all "$SKILL" "bug, enhancement, data, performance, support question, or mixed"
}

test_running_is_read_only() {
  section_has "$SKILL" Rules "read-only" "no build" "no tests" "database" "Azure DevOps"
}

test_the_gate_has_three_answers_and_both_requirement_states() {
  has_all "$SKILL" "confirm" "correct" "send the questions" "stop condition" &&
    has_all_cs "$SKILL" "Requirement: confirmed" "Requirement: unconfirmed"
}

test_never_asks_what_the_code_can_answer() { has_all "$SKILL" "the code can answer"; }

test_support_question_stops_at_code_facts() { has_all "$SKILL" "support question" "no comment" "drafts no answer"; }

test_second_run_uses_prior_state() { has_all "$SKILL" "earlier intake comment" "answered"; }

test_markers_and_no_tiers() {
  has_all "$SKILL" "unknown:" "inferred:" "conflict:" "path:line" &&
    none_contains -F "Tier:" && none_contains -iw "supported"
}

test_never_names_another_skill_outside_the_allowed_targets() {
  none_contains -F "agentd-explain" && none_contains -F "agentd-prompt"
}

test_blast_radius_only_for_contract_schema_shared_code_or_external() {
  [ -s "$SKILL" ] || return 1
  grep -iF -- "/agentd-blast-radius" "$SKILL" | grep -i "contract" | grep -i "schema" | grep -i "shared code" |
    grep -qi "external system"
}

test_missing_onboarding_pack_or_contract_says_so_once() {
  has_all "$SKILL" "docs/onboarding/README.md" "External systems" "say so once"
}

test_empty_or_non_ticket_paste_asks_once() { has_all "$SKILL" "ask for the work item once"; }

test_comment_language_follows_the_ticket() { has_all "$SKILL" "language of the work item"; }

test_branch_number_is_recorded() { has_all "$SKILL" "git branch --show-current" "Work item <number>"; }

test_no_absolute_home_paths() { none_contains -F "/Users/" && none_contains -F "~/"; }

test_no_phrase_is_copied_from_pstack() {
  local p
  for p in "in your own words" "deeper version of this task" "rawest material" "Proceed, then present" \
    "other than you or me" "other than us" "top professional" "bolt it onto" "pstack" "poteto"; do
    none_contains -i "$p" || return 1
  done
}

# ---------------------------------------------------------------- references

test_every_referenced_file_exists() {
  has_all "$SKILL" "references/comment-template.md" "references/question-checklist.md" && [ -s "$TPL" ] && [ -s "$CHK" ]
}

test_template_verdict_line_is_exact() { has_all_cs "$TPL" "Verdict: Actionable | Not actionable yet"; }

test_actionable_comment_headings_in_order() {
  in_order "$TPL" "### Our understanding" "### Today" "### Change" "### Acceptance checks" "### Out of scope" \
    "### Assumptions" "### Technical notes"
}

test_not_actionable_comment_headings_in_order() {
  in_order "$TPL" "### Technical notes" "### Our understanding" "### Questions" "### Next"
}

test_no_customer_questions_says_we_are_investigating() {
  has_all "$TPL" "we are investigating" "Not actionable yet" "no Questions section"
}

test_bug_today_and_change() { has_all "$TPL" "how to reproduce" "expected behaviour" "not a fix"; }

test_customer_text_has_no_paths_above_technical_notes() { has_all "$TPL" "no file paths" "Technical notes"; }

test_technical_notes_layer_order() {
  [ -s "$TPL" ] || return 1
  grep -qiE 'frontend.*endpoint.*command.*handler.*repository.*stored procedure' "$TPL" &&
    has_all "$TPL" "none" "unknown:"
}

test_engineer_block_has_every_field_in_order() {
  in_order "$TPL" "Type:" "Verdict:" "Requirement:" "Assumptions:" "Stop condition:" "Questions for the engineer:" \
    "Conflicts:" "Investigation:" "Design concern:" "Next:"
}

test_mixed_ticket_type_line() { has_all_cs "$TPL" "Type: <main type>, also <other type>"; }

test_the_closing_line_depends_on_the_gate() {
  has_all "$TPL" "Stop condition: none" 'Run `/' "Post the comment" 'run `/agentd-intake` again'
}

test_comment_size_limit() { has_all "$TPL" "250 words" "five questions"; }

test_comment_adds_no_personal_data() { has_all "$TPL" "personal data" "the work item gives"; }

test_each_question_has_four_parts() { has_all "$CHK" "what is missing" "what changes" "who to ask" "default"; }

test_checklist_has_exactly_one_section_per_type() {
  [ -s "$CHK" ] || return 1
  [ "$(h2_list "$CHK" | tr '\n' '|')" = "Bug|Enhancement|Data|Performance|Support question|" ]
}

test_checklist_defines_a_safe_default() { has_all "$CHK" "safe default" "contract" "external system" "existing data"; }

test_checklist_routes_questions() { has_all "$CHK" "engineer block" "reads the work item"; }

test_checklist_never_grows_scope() { has_all "$CHK" "never grows"; }

# ---------------------------------------------------------------- iteration 1 (from the evaluation runs)

test_an_unanswered_question_keeps_its_default() { has_all "$SKILL" "keeps its default as an assumption"; }

test_the_gate_step_points_to_the_headless_rule() { section_has "$SKILL" Flow "If nobody can answer"; }

test_requirement_holds_only_the_status() { has_all "$SKILL" "holds only the status"; }

test_diagnose_comes_first_when_the_cause_is_unknown() { has_all "$SKILL" "diagnose comes first" "inferred:"; }

test_no_name_from_code_or_data_even_in_chat() { section_has "$SKILL" Rules "Quote no name" "even in chat"; }

test_the_work_item_line_is_conditional() { has_all "$TPL" "Leave it out when there is no number"; }

test_the_two_step_run_line_is_shown() { has_all "$TPL" 'Run `/agentd-blast-radius`, then `/agentd-dev-rev`'; }

test_a_support_question_overrides_the_headless_rule() {
  section_has "$TPL" "Support question" "Requirement: none (support question)" "Stop condition: none" "takes the place of"
}

test_not_actionable_may_end_with_technical_notes() { in_order "$TPL" "## Not actionable yet" "### Next" "### Technical notes"; }

test_checklist_covers_text_sorting() { section_has "$CHK" Enhancement "capital letters"; }

test_a_support_question_skips_the_gate() { has_all "$SKILL" "skips the gate question" "Stop condition: none"; }

# ---------------------------------------------------------------- iteration 2 (from the round 2 runs)

test_a_change_to_what_an_external_system_reads_always_blocks() {
  has_all "$CHK" "always blocks until its owner agrees"
}

test_comment_assumptions_are_only_ones_the_customer_would_notice() { has_all "$TPL" "the customer would notice"; }

test_conflict_covers_a_proposed_fix_the_code_rules_out() { has_all "$SKILL" "a proposed fix that the code shows will not work"; }

test_not_actionable_stop_condition_is_do_not_build() { has_all "$TPL" "do not build until"; }

# ---------------------------------------------------------------- review round 1

test_confirming_not_actionable_posts_the_questions() {
  section_has "$TPL" "Closing lines" "Confirming a Not actionable yet" 'stays `unconfirmed`'
}

test_investigation_only_has_its_own_closing_line() {
  section_has "$TPL" "Closing lines" 'Do the Investigation steps, then run `/agentd-intake` again'
}

test_an_unclear_support_question_gets_the_not_actionable_comment() {
  has_all "$SKILL" "An unclear support question uses the Not actionable yet comment" &&
    section_has "$TPL" "Support question" "a support question the code answers"
}

test_today_holds_what_the_customer_reported() { has_all "$TPL" "Today states what the customer reported"; }

test_a_request_from_the_owners_business_side_is_not_agreement() {
  has_all "$CHK" "does not show that the system reading it accepts the change"
}

test_an_id_in_the_paste_wins_over_the_branch() {
  has_all "$SKILL" "A record ID is never the work item number" "leave the line out and say so in chat"
}

# ---------------------------------------------------------------- review round 2

test_a_cause_the_customer_names_is_a_candidate() { has_all "$SKILL" "A cause the customer names is a candidate"; }

test_an_owner_who_reads_the_work_item_is_asked_in_the_comment() {
  has_all "$CHK" "Their explicit answer counts as the owner's agreement"
}

test_skill_has_one_source_for_closing_lines() {
  has_all "$SKILL" "The gate question is the last line until the engineer answers" &&
    ! grep -qiF "for every Not actionable yet" "$SKILL"
}

test_confirming_investigation_only_uses_the_investigation_line() {
  has_all "$TPL" "or the investigation line when the comment has no customer questions" "Show the block once"
}

test_the_comment_never_states_the_code_reading_as_fact() {
  section_has "$TPL" "Rules for the comment" "never states the code's reading as fact"
}

test_a_not_actionable_question_with_a_default_stays_a_question() { has_all "$TPL" 'stays a question, with `Our default:`'; }

test_the_engineer_block_keeps_its_language_and_field_names() { has_all "$SKILL" "its field names never change"; }

test_a_bug_outranks_an_enhancement_in_a_mixed_work_item() { has_all "$SKILL" "over an enhancement or a support question"; }

test_the_skill_files_say_work_item_not_ticket() { none_contains -iw "ticket"; }

test_the_gate_step_says_a_support_question_skips_it() { section_has "$SKILL" Flow "A support question the code answers skips this step"; }

test_no_contract_means_no_safe_default_for_outputs() {
  has_all "$TPL" "unknown: no project contract" && has_all "$CHK" "leaves the system"
}

test_investigation_examples_are_engineer_side() { has_all "$TPL" "a log search"; }

test_the_other_part_of_a_mixed_ticket_is_raised_separately() { has_all "$TPL" "raise it as a separate work item"; }

test_headings_are_translated() { has_all "$TPL" "Translate the headings"; }

# ---------------------------------------------------------------- data-fix hand-off

test_a_data_change_with_no_code_change_goes_to_data_fix() {
  section_has "$SKILL" Output '`/agentd-data-fix` for a data work item that needs only a data change' \
    'Bad rows with an unknown cause go to `/agentd-diagnose` first'
}

test_the_data_fix_closing_line_pastes_the_work_item() {
  section_has "$TPL" "Closing lines" 'Run `/agentd-data-fix` and paste the work item, the comment and the engineer block'
}

test_the_data_checklist_names_data_fix() {
  section_has "$CHK" Data '`/agentd-data-fix`' '`/agentd-diagnose`'
}

check "name matches the folder" test_frontmatter_name_matches_folder
check "description starts with Use when and covers the job" test_description_starts_with_use_when_and_covers_the_job
check "the skill is manual-only" test_skill_is_manual_only
check "SKILL.md has at most 120 lines" test_skill_is_at_most_120_lines
check "H2 sections are Prerequisite, Flow, Verdicts, Output, Rules" test_required_h2_sections_in_order
check "Flow has the six numbered steps in order" test_flow_has_six_numbered_steps_in_order
check "the two verdicts are exact" test_the_two_verdicts_are_exact
check "an unknown root cause does not block a bug" test_an_unknown_cause_does_not_block_a_bug
check "a gap blocks only without a safe default" test_a_gap_blocks_only_without_a_safe_default
check "the ticket types are listed" test_types_are_listed
check "running is read-only" test_running_is_read_only
check "the gate has three answers and both Requirement states" test_the_gate_has_three_answers_and_both_requirement_states
check "intake never asks what the code can answer" test_never_asks_what_the_code_can_answer
check "a support question stops at code facts" test_support_question_stops_at_code_facts
check "a second run uses the prior state" test_second_run_uses_prior_state
check "markers, and no evidence tiers" test_markers_and_no_tiers
check "no skill outside the allowed Next targets is named" test_never_names_another_skill_outside_the_allowed_targets
check "blast-radius only for a contract, schema, shared code or external system" test_blast_radius_only_for_contract_schema_shared_code_or_external
check "a missing onboarding pack or contract is said once" test_missing_onboarding_pack_or_contract_says_so_once
check "an empty or non-ticket paste asks once" test_empty_or_non_ticket_paste_asks_once
check "the comment uses the language of the ticket" test_comment_language_follows_the_ticket
check "the branch number is recorded" test_branch_number_is_recorded
check "no absolute home paths" test_no_absolute_home_paths
check "no phrase is copied from pstack" test_no_phrase_is_copied_from_pstack
check "both references are named and exist" test_every_referenced_file_exists
check "the template's verdict line is exact" test_template_verdict_line_is_exact
check "the Actionable comment headings are in order" test_actionable_comment_headings_in_order
check "the Not actionable comment headings follow, in order" test_not_actionable_comment_headings_in_order
check "no customer questions: we are investigating, no Questions section" test_no_customer_questions_says_we_are_investigating
check "a bug's Today and Change" test_bug_today_and_change
check "no file paths above Technical notes" test_customer_text_has_no_paths_above_technical_notes
check "Technical notes use the layer order, with none and unknown:" test_technical_notes_layer_order
check "the engineer block has every field in order" test_engineer_block_has_every_field_in_order
check "a mixed work item's Type line" test_mixed_ticket_type_line
check "the closing line depends on the gate" test_the_closing_line_depends_on_the_gate
check "the comment has a size limit" test_comment_size_limit
check "the comment adds no personal data" test_comment_adds_no_personal_data
check "each question has four parts" test_each_question_has_four_parts
check "the checklist has exactly one section per type" test_checklist_has_exactly_one_section_per_type
check "the checklist defines a safe default" test_checklist_defines_a_safe_default
check "the checklist routes questions" test_checklist_routes_questions
check "the checklist never grows scope" test_checklist_never_grows_scope
check "an unanswered question keeps its default as an assumption" test_an_unanswered_question_keeps_its_default
check "the gate step points to the rule for nobody to answer" test_the_gate_step_points_to_the_headless_rule
check "Requirement holds only the status" test_requirement_holds_only_the_status
check "diagnose comes first when the cause is unknown" test_diagnose_comes_first_when_the_cause_is_unknown
check "no name from the code or data, even in chat" test_no_name_from_code_or_data_even_in_chat
check "the Work item line is conditional" test_the_work_item_line_is_conditional
check "the two-step run line is shown" test_the_two_step_run_line_is_shown
check "a support question overrides the rule for nobody to answer" test_a_support_question_overrides_the_headless_rule
check "Not actionable yet may end with Technical notes" test_not_actionable_may_end_with_technical_notes
check "the checklist covers text sorting" test_checklist_covers_text_sorting
check "a support question skips the gate" test_a_support_question_skips_the_gate
check "a change to what an external system reads always blocks" test_a_change_to_what_an_external_system_reads_always_blocks
check "comment assumptions are only ones the customer would notice" test_comment_assumptions_are_only_ones_the_customer_would_notice
check "conflict: covers a proposed fix the code rules out" test_conflict_covers_a_proposed_fix_the_code_rules_out
check "Not actionable yet: the stop condition is do not build" test_not_actionable_stop_condition_is_do_not_build
check "confirming Not actionable yet posts the questions" test_confirming_not_actionable_posts_the_questions
check "an investigation-only Not actionable yet has its own closing line" test_investigation_only_has_its_own_closing_line
check "an unclear support question gets the Not actionable comment" test_an_unclear_support_question_gets_the_not_actionable_comment
check "Today holds what the customer reported" test_today_holds_what_the_customer_reported
check "a request from the owner's business side is not agreement" test_a_request_from_the_owners_business_side_is_not_agreement
check "a record ID is never the work item number" test_an_id_in_the_paste_wins_over_the_branch
check "a cause the customer names is a candidate" test_a_cause_the_customer_names_is_a_candidate
check "an owner who reads the work item is asked in the comment" test_an_owner_who_reads_the_work_item_is_asked_in_the_comment
check "SKILL.md has one source for closing lines" test_skill_has_one_source_for_closing_lines
check "confirming investigation-only uses the investigation line" test_confirming_investigation_only_uses_the_investigation_line
check "the comment never states the code's reading as fact" test_the_comment_never_states_the_code_reading_as_fact
check "a Not actionable question with a default stays a question" test_a_not_actionable_question_with_a_default_stays_a_question
check "the engineer block keeps its language and field names" test_the_engineer_block_keeps_its_language_and_field_names
check "a bug outranks an enhancement in a mixed work item" test_a_bug_outranks_an_enhancement_in_a_mixed_work_item
check "the skill files say work item, not ticket" test_the_skill_files_say_work_item_not_ticket
check "the gate step says a support question skips it" test_the_gate_step_says_a_support_question_skips_it
check "no contract means no safe default for outputs" test_no_contract_means_no_safe_default_for_outputs
check "investigation examples are engineer-side" test_investigation_examples_are_engineer_side
check "the other part of a mixed ticket is raised separately" test_the_other_part_of_a_mixed_ticket_is_raised_separately
check "comment headings are translated" test_headings_are_translated
check "a data change with no code change goes to /agentd-data-fix" test_a_data_change_with_no_code_change_goes_to_data_fix
check "the data-fix closing line pastes the work item" test_the_data_fix_closing_line_pastes_the_work_item
check "the Data checklist names data-fix and diagnose" test_the_data_checklist_names_data_fix

echo
echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
