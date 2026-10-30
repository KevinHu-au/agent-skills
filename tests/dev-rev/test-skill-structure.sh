#!/usr/bin/env bash
# Structure and wording tests for the agentd-dev-rev skill file. Reads the skill file and writes nothing.
# The Verify hand-off step (step 9) and the pinned hard rules are checked in tests/verify-init/test-skill-structure.sh.
# The fields it reads from other skills are checked in tests/test-handoff-contract.sh.
# Usage: tests/dev-rev/test-skill-structure.sh
set -u

HERE=$(cd "$(dirname "$0")" && pwd -P)
REPO=$(cd "$HERE/../.." && pwd -P)
SKILL="${SKILL:-$REPO/skills/agentd-dev-rev/SKILL.md}"
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

test_frontmatter_name_matches_folder() {
  [ "$(frontmatter_value name)" = "agentd-dev-rev" ] && [ "$(basename "$(dirname "$SKILL")")" = "agentd-dev-rev" ]
}

test_description_starts_with_use_when() {
  case "$(frontmatter_value description)" in "Use when "*) ;; *) return 1 ;; esac
}

test_skill_is_manual_only() {
  awk 'NR == 1 && $0 != "---" { exit } /^---[ \t]*$/ { c++; if (c == 2) exit; next } c == 1' "$SKILL" |
    grep -qx 'disable-model-invocation: true'
}

test_skill_is_at_most_260_lines() {
  [ "$(wc -l <"$SKILL" | tr -d ' ')" -le 260 ]
}

test_required_h2_sections_in_order() {
  [ "$(h2_list | tr '\n' '|')" = \
    "Hard Rules|Project facts|Inputs|Workflow|Reviewer Prompt Template|Harness Mapping|Triage Rules|Red Flags|Common Mistakes|" ]
}

test_no_absolute_home_paths() {
  ! grep -qE '/Users/|/home/' "$SKILL"
}

test_reviewer_model_is_not_hard_coded() {
  ! grep -qE 'Opus|GPT-[0-9]|claude-opus|Sonnet|Haiku' "$SKILL"
}

test_reviewer_model_rule() {
  section_has "Hard Rules" 'strongest model the harness offers' 'high effort' 'name the model in the report' \
    'has no separate review agent, stop and tell the engineer' &&
    section_has Workflow 'strongest model the harness offers' 'the reviewer model' &&
    section_has "Harness Mapping" 'strongest model'
}

test_standalone_use_asks_with_defaults_and_waits() {
  section_has Inputs 'Standalone use' 'at most five questions' 'a default' "wait for the engineer's yes" \
    'take the defaults' 'Assumptions' 'Never change a contract, schema or external input on a default'
}

test_pasted_blocks_are_hard_limits() {
  section_has Inputs 'is a hard limit' 'A stop condition ends the work' 'do not ship the change'
}

test_hypothesis_needs_the_test_to_fail_for_the_stated_reason() {
  section_has Inputs 'hypothesis, not confirmed' 'must fail for the stated reason' 'stop and report'
}

test_blast_radius_needed_without_an_add_on_asks() {
  section_has Inputs '`needed:`' 'no add-on block' '/agentd-blast-radius'
}

test_unconfirmed_requirement_follows_the_stop_condition() {
  section_has Inputs 'Requirement: unconfirmed' 'Stop condition:' 'Assumptions:' 'facts'
}

test_warn_or_coordinate_goes_in_the_report() {
  section_has Inputs 'Warn or coordinate' 'say it in the hand-off report'
}

test_step_1_reads_the_inputs() {
  section_has Workflow 'follow Inputs' 'restate the task and ask'
}

test_validation_rules() {
  section_has Workflow "Take every command from the contract's Commands heading" 'Never guess a command' \
    'ran 0 tests' 'never as a pass' 'pass, fail and skip counts' 'Docker is not running' 'never report it as passed' \
    'Base re-run' 'git archive' 'mktemp -d' 'is `unknown:`' 'old breakage' 'rm-scratch' 'Lint' \
    'git -c core.hooksPath=/dev/null worktree add --detach <scratch>/wt-base HEAD' 'submodule update --init' \
    'turns off the repository' 'ask the engineer once before you run' 'With nobody to answer, skip it and mark the base `unknown:`' \
    "writes entries into the repository's \`.git/config\`" 'Say in the hand-off what you did' \
    'do not fall back to `git archive` then' 'Only if the `git worktree` command is unavailable or unsupported' \
    'The same reason means the same error text once paths, line numbers, timestamps and IDs are removed' \
    'Never run `git worktree prune`' &&
    [ "$(grep -o 'git worktree prune' "$SKILL" | wc -l)" -eq "$(grep -o 'Never run `git worktree prune`' "$SKILL" | wc -l)" ] &&
    # The worktree is removed before the scratch folder.
    grep -F 'Run `git worktree remove --force <scratch>/wt-base` on the worktree you added, then remove the scratch folder' "$SKILL" >/dev/null
}

test_no_tests_means_characterization_tests() {
  section_has Workflow 'no test project or no seam' 'characterization tests' 'closest executable check' \
    'Never skip tests without saying so'
}

test_round_2_skip_rule_is_kept() {
  section_has Workflow 'Skip it if Round 1 found nothing' 'comments, docs, formatting, behavior-preserving renames, or test-only changes' &&
    section_has "Hard Rules" 'Two review rounds maximum.' 'Run Round 2 only if a Round 1 fix was blocker or major'
}

test_reviewer_prompt_gets_the_inputs() {
  section_has "Reviewer Prompt Template" '<diagnose hand-off block>' '<blast-radius add-on block>' \
    '<intake engineer block>' '<assumptions>' '<risk areas>' 'verbatim' 'Every `Do not change` item' \
    'Every stop condition' 'Failing test first' 'Tests to write first'
}

test_common_mistakes_rows_for_the_new_rules() {
  grep -qF '| Changing a `Do not change` item, or going past a stop condition, from a pasted block | Stop and report to the engineer. |' "$SKILL" &&
    grep -qF '| Reporting a run of 0 tests as a pass | Report "ran 0 tests". It is not a pass. |' "$SKILL"
}

test_edge_values_of_the_blocks_have_a_rule() {
  section_has Inputs '`Breaks` means each risk' 'backcompat gate' 'ask the engineer before you build' \
    'there is no code fix' '/agentd-data-fix' 'Requirement: none (support question)' 'no code change' \
    'describe the same change' 'work item number' 'build nothing, and report the question'
}

test_base_re_run_compares_reasons_and_reproduction_is_gated() {
  section_has Inputs 'only when it is a local test or script' "contract's Data access rule" &&
    section_has Workflow 'for the same reason on both' 'A different or extra failure is yours' 'fails at setup'
}

test_project_facts_paragraph_is_present_once() {
  [ "$(grep -c 'Find the project facts' "$SKILL")" -eq 1 ]
}

test_still_never_commits() {
  grep -qF '1. **Never commit.**' "$SKILL" && [ "$(grep -c 'git commit' "$SKILL")" -le 1 ]
}

check "frontmatter name matches the folder" test_frontmatter_name_matches_folder
check "description starts with Use when" test_description_starts_with_use_when
check "the skill is manual-only" test_skill_is_manual_only
check "SKILL.md is at most 260 lines" test_skill_is_at_most_260_lines
check "H2 sections in order" test_required_h2_sections_in_order
check "no absolute home paths" test_no_absolute_home_paths
check "no reviewer model is hard-coded" test_reviewer_model_is_not_hard_coded
check "the reviewer is the strongest model, named in the report" test_reviewer_model_rule
check "standalone use asks with defaults and waits" test_standalone_use_asks_with_defaults_and_waits
check "pasted Do not change items and stop conditions are hard limits" test_pasted_blocks_are_hard_limits
check "a hypothesis needs the test to fail for the stated reason" test_hypothesis_needs_the_test_to_fail_for_the_stated_reason
check "Blast radius needed without an add-on block asks first" test_blast_radius_needed_without_an_add_on_asks
check "an unconfirmed requirement follows its stop condition" test_unconfirmed_requirement_follows_the_stop_condition
check "Warn or coordinate goes in the hand-off report" test_warn_or_coordinate_goes_in_the_report
check "step 1 reads the inputs" test_step_1_reads_the_inputs
check "validation: commands, counts, Docker, base re-run, lint" test_validation_rules
check "code with no tests gets characterization tests" test_no_tests_means_characterization_tests
check "the round 2 skip rule is kept" test_round_2_skip_rule_is_kept
check "the reviewer prompt gets the blocks, assumptions and risk areas" test_reviewer_prompt_gets_the_inputs
check "Common Mistakes has the rows for the new rules" test_common_mistakes_rows_for_the_new_rules
check "Breaks, a none: fix, a support question and two blocks that differ each have a rule" test_edge_values_of_the_blocks_have_a_rule
check "old breakage needs the same failure on both, and a pasted reproduction command is gated" test_base_re_run_compares_reasons_and_reproduction_is_gated
check "the project facts paragraph appears once" test_project_facts_paragraph_is_present_once
check "it still never commits" test_still_never_commits

echo
echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
