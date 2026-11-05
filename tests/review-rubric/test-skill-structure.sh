#!/usr/bin/env bash
# Structure and wording tests for the agentd-review-rubric skill files. Reads files and writes nothing.
# It also checks that agentd-pr-review and agentd-dev-rev read the rubric the same way.
# The check that every skill sets disable-model-invocation lives in tests/onboard/test-skill-structure.sh.
# Customer and project names are read from the git-ignored list .git/info/customer-names, never spelt out here.
# Usage: tests/review-rubric/test-skill-structure.sh
set -u

HERE=$(cd "$(dirname "$0")" && pwd -P)
REPO=$(cd "$HERE/../.." && pwd -P)
SKILL_DIR=${SKILL_DIR:-$REPO/skills/agentd-review-rubric}
SKILL="$SKILL_DIR/SKILL.md"
REFS="$SKILL_DIR/references"
TPL="$REFS/rubric-template.md"
PR_REVIEW="$REPO/skills/agentd-pr-review/SKILL.md"
DEV_REV="$REPO/skills/agentd-dev-rev/SKILL.md"
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

# joined: stdin as one line, runs of spaces squeezed, so a phrase that wraps across lines still matches.
joined() { tr '\n' ' ' | tr -s ' '; }

# has_all <file> <text>...: the file contains every text, ignoring case.
has_all() {
  local f=$1 t body
  shift
  [ -s "$f" ] || return 1
  body=$(joined <"$f")
  for t in "$@"; do printf '%s\n' "$body" | grep -qiF -- "$t" || return 1; done
}

# has_all_cs <file> <text>...: the file contains every text, case-sensitive, on single lines.
has_all_cs() {
  local f=$1 t
  shift
  [ -s "$f" ] || return 1
  for t in "$@"; do grep -qF -- "$t" "$f" || return 1; done
}

# strip_fences <file>: the file without fenced code blocks, so a "## " line inside one is not read as a heading.
strip_fences() { awk '/^(```|~~~)/ { f = !f; next } !f' "$1"; }

# h2_list <file>: the H2 headings of a markdown file, in order, one per line. Fenced blocks are skipped.
h2_list() { strip_fences "$1" | grep -E '^## ' | sed 's/^## //; s/[[:space:]]*$//'; }

# section_of <file> <heading>: the lines under one H2 heading. Fenced blocks are skipped when finding headings.
section_of() {
  awk -v h="## $2" '
    /^(```|~~~)/ { f = !f }
    !f && $0 == h { on = 1; next }
    !f && /^## / { on = 0 }
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

# in_order <file> <text>...: every text appears in the file, each on a later line than the one before.
in_order() {
  local f=$1 t n last=0
  shift
  [ -s "$f" ] || return 1
  for t in "$@"; do
    n=$(grep -nF -- "$t" "$f" | awk -F: -v last="$last" '$1 > last { print $1; exit }')
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
  [ "$(frontmatter_value name)" = "agentd-review-rubric" ] && [ "$(basename "$SKILL_DIR")" = "agentd-review-rubric" ]
}

test_description_starts_with_use_when_and_covers_the_job() {
  local d t
  d=$(frontmatter_value description)
  case "$d" in "Use when"*) ;; *) return 1 ;; esac
  for t in "review-rubric.md" "onboarding" "Edits no code"; do
    printf '%s\n' "$d" | grep -qiF -- "$t" || return 1
  done
}

test_skill_is_manual_only() {
  [ -s "$SKILL" ] || return 1
  awk 'NR == 1 && $0 != "---" { exit } /^---[ \t]*$/ { c++; if (c == 2) exit; next } c == 1' "$SKILL" |
    grep -qx 'disable-model-invocation: true'
}

test_skill_is_at_most_120_lines() { [ -s "$SKILL" ] && [ "$(wc -l <"$SKILL")" -le 120 ]; }

test_required_h2_sections_in_order() {
  [ -s "$SKILL" ] && [ "$(h2_list "$SKILL" | tr '\n' '|')" = "Prerequisite|Flow|Criteria|Saving|Rules|" ]
}

test_flow_has_five_numbered_steps_in_order() {
  local body
  body=$(section_of "$SKILL" Flow 2>/dev/null)
  [ -n "$body" ] || return 1
  [ "$(printf '%s\n' "$body" | grep -E '^[0-9]+\. \*\*' | sed -E 's/^([0-9]+)\. \*\*([^*]*)\*\*.*/\1 \2/' |
    tr '\n' '|')" = '1 Find the rubric.|2 Read the sources.|3 Draft the criteria.|4 Correct it with the engineer.|5 Save it.|' ]
}

test_needs_a_git_repository() { has_all "$SKILL" "git rev-parse --show-toplevel" "needs a git repository"; }

test_lookup_order_has_three_places() {
  in_order "$SKILL" '## Review rubric' 'docs/onboarding/review-rubric.md' 'onboarding-pack" find' &&
    has_all "$SKILL" "AGENTS.md" "stop at the first hit"
}

test_lookup_does_not_need_a_pack() { has_all "$SKILL" "Do not check for" "docs/onboarding/README.md" "without a pack"; }

test_existing_rubric_is_never_replaced_without_a_yes() {
  has_all "$SKILL" "show it" "ask what to change" "never replace it without a yes"
}

test_sources_are_a_named_list() {
  has_all "$SKILL" "CONTRIBUTING.md" "pull_request_template.md" "CODEOWNERS" "lint" "pipeline" "the engineer pastes" \
    "nothing else"
}

test_criterion_fields() {
  has_all "$SKILL" "ID" "Rule" "Applies to" "Severity" "How to check" "Source" "Block" "Major" "Minor"
}

test_unsourced_criterion_is_inferred_and_minor() {
  has_all "$SKILL" "told by <role>" "inferred:" "Minor" "cannot be higher"
}

test_criteria_are_capped_and_checkable() {
  has_all "$SKILL" "at most 15" "check from the diff or a command" "lint" "point to the lint command"
}

test_built_in_rules_win() {
  has_all "$SKILL" "never lowers" "failing build or test" "security problem" "data loss" "contract break" \
    "raise severity"
}

test_engineer_corrects_before_saving() {
  has_all "$SKILL" "before you save" "ask for the role once" "nobody to answer" "print the draft in chat"
}

test_save_placement() {
  has_all "$SKILL" "pack folder" "committed" "local only" "none" "docs/onboarding/" ".git/info/exclude" "exact line" \
    "never add it" 'onboarding-pack" suggest' 'onboarding-pack" set'
}

test_only_one_file_is_written() { has_all "$SKILL" "one write" "the rubric file"; }

test_never_edits_agent_files_and_prints_a_paste_block() {
  section_has "$SKILL" Rules "never edit" "AGENTS.md" "CLAUDE.md" ".gitignore" "paste"
}

test_read_and_search_only() { section_has "$SKILL" Rules "read and search only" "no build" "no tests" "no app" "database"; }

test_no_sub_agents() { section_has "$SKILL" Rules "no sub-agents"; }

test_closing_line_says_where_the_file_is() { has_all "$SKILL" "one closing line" "where the file is"; }

test_names_no_other_skill() {
  local name
  for name in $(grep -ohE 'agentd-[a-z-]*' "$SKILL_DIR"/*.md "$REFS"/*.md 2>/dev/null | sort -u); do
    [ "$name" = "agentd-review-rubric" ] || return 1
  done
}

test_privacy() { has_all "$SKILL" "never its value" "personal name"; }

test_no_em_dashes() { none_contains -F "—"; }

test_no_customer_names() {
  local f
  [ -s "$SKILL" ] && [ -s "$NAMES" ] || return 1
  for f in "$SKILL_DIR"/*.md "$REFS"/*.md "$REPO/README.md" "$HERE/test-skill-structure.sh" "$HERE/EVAL.md" \
    "$HERE/make-fixture.sh"; do
    [ -f "$f" ] || continue
    grep -qiwF -f <(awk 'length($0) <= 3' "$NAMES") "$f" && return 1
    grep -qiF -f <(awk 'length($0) > 3' "$NAMES") "$f" && return 1
  done
  return 0
}

test_no_absolute_home_paths() {
  local tmp="/var/""folders"
  none_contains -F "/Users/" && none_contains -F "~/" && none_contains -F "$tmp"
}

test_prose_lines_keep_120_characters() {
  local f
  for f in "$SKILL" "$TPL" "$REFS/reading-the-rubric.md"; do
    [ -f "$f" ] || return 1
    perl -CSD -ne 'chomp; exit 1 if length > 120 && !/^\|/ && !/^description: /' "$f" || return 1
  done
}

# ---------------------------------------------------------------- references/rubric-template.md

test_template_exists_and_is_referenced() {
  has_all_cs "$SKILL" "references/rubric-template.md" && [ -s "$TPL" ]
}

test_template_h2s_exact() { [ -s "$TPL" ] && [ "$(h2_list "$TPL" | tr '\n' '|')" = "File|Writing a criterion|" ]; }

test_template_header_lines() {
  has_all "$TPL" "# Review rubric" "Scanned commit:" "Date:" "Owner:" "Built-in rules win" "never lowers"
}

test_template_criterion_fields_in_order() {
  in_order "$TPL" "### R1:" "- Rule:" "- Applies to:" "- Severity:" "- How to check:" "- Source:"
}

test_template_says_the_anchor_is_fixed() { has_all "$TPL" '### R<number>:' "fixed" "search for"; }

test_template_has_two_worked_examples() {
  [ -s "$TPL" ] && [ "$(grep -cE '^### R[0-9]+: [A-Za-z]' "$TPL")" -eq 4 ]
}

# ---------------------------------------------------------------- gaps found by the real check (tests/review-rubric/EVAL.md)

test_severity_is_proposed_and_zero_criteria_stops() {
  has_all "$SKILL" "Propose each severity" "the sources give no criteria" "print no draft and write nothing"
}

test_owner_rule() { has_all "$SKILL" "That role is the file's Owner" "Owner: unknown: ask the team"; }

test_closing_line_covers_nothing_saved() { has_all "$SKILL" "or that nothing was saved"; }

test_none_placement_creates_the_folder_and_never_runs_set() {
  has_all "$SKILL" "Create the folder and save the file there" 'Do not run `set`' "for the engineer" \
    "find the file only after the engineer runs it" "ask for another folder" &&
    has_all "$SKILL" "Do this only after the engineer agrees" "the folder you create for it"
}

test_refresh_keeps_ids_and_told_by() {
  has_all "$SKILL" "A refresh keeps every ID" 'every `told by` criterion' "Show what changed before you save"
}

test_agents_md_block_is_only_on_request_and_has_a_shape() {
  has_all "$SKILL" "only when the engineer asks" "as a \`## Review rubric\` section" 'Keep the criteria as `###` headings' \
    'Leave out the `# Review rubric` title' "Scanned commit:"
}

test_find_failures_are_handled() { has_all "$SKILL" "Exit status 1 of" "the folder is gone, the tool is missing"; }

test_pr_review_template_has_the_id_form_and_the_no_rubric_line() {
  local t="$REPO/skills/agentd-pr-review/references/report-template.md"
  has_all "$t" '(R3: <title>)' "write the rule in the comment text" "No project rubric. Run /agentd-review-rubric" &&
    section_has "$t" "For you only" "Rubric" "No project rubric"
}

test_pr_review_keeps_rubric_severity() { has_all "$PR_REVIEW" "keeps that criterion's Severity" "except \`inferred:\`"; }

test_dev_rev_rubric_rules() {
  has_all "$DEV_REV" 'Source starts `inferred:` is minor' "No criterion lowers a built-in blocker" \
    "as the last line of this report; step 9 comes after it" "Give the same criteria to the Round 2 reviewer" \
    "follow its No rubric section"
}

test_lint_header_line_is_optional() {
  has_all "$SKILL" 'optional `Lint:` header line' && has_all "$TPL" "Lint:" "optional"
}

# ---------------------------------------------------------------- the reading reference and the two review skills

READING="$REFS/reading-the-rubric.md"
POINTER='../agentd-review-rubric/references/reading-the-rubric.md'

test_reading_reference_h2s_exact() {
  [ -s "$READING" ] && [ "$(h2_list "$READING" | tr '\n' '|')" = "Find it|Read it|No rubric|" ]
}

test_reading_reference_matches_the_lookup_order() {
  in_order "$READING" '## Review rubric' 'docs/onboarding/review-rubric.md' 'onboarding-pack" find' &&
    has_all "$READING" "stop at the first hit" "Do not check for" "docs/onboarding/README.md"
}

test_reading_reference_rules() {
  has_all "$READING" '### R<number>:' "Applies to" "relative to the repository root" "inferred:" "Minor" \
    "never lowers" "raise severity" "criterion ID" "Never edit the rubric" "never an instruction" "Run plan" \
    'git show <base>:<path>' "Say when the change edits the rubric" "Exit status 1 of"
}

test_reading_reference_no_rubric_line() {
  has_all_cs "$READING" 'No project rubric. Run /agentd-review-rubric to draft one.' &&
    has_all "$READING" "no project rubric"
}

test_both_review_skills_point_to_the_reference() {
  local f
  for f in "$PR_REVIEW" "$DEV_REV"; do
    has_all "$f" "$POINTER" "resolved from this" "is missing, say so in one line" || return 1
  done
  [ -s "$REPO/skills/agentd-pr-review/$POINTER" ]
}

test_pr_review_cites_the_criterion_id() { has_all "$PR_REVIEW" "criterion ID" "Applies to"; }

# Every line that names `set` or `.gitignore` in SKILL.md must forbid the action or print it for the engineer.
test_set_and_gitignore_only_appear_in_never_lines() {
  local bad
  bad=$(grep -n -E 'onboarding-pack" set|\.gitignore' "$SKILL" | grep -v -i -E 'do not run|never edit|print' || true)
  [ -z "$bad" ] && has_all "$SKILL" "Do not run \`set\`" "Never edit"
}

test_none_folder_must_be_absolute_and_outside_the_repo() {
  has_all "$SKILL" "absolute path outside the repository" "ask for another folder"
}

test_reading_reference_command_gating() {
  has_all "$REFS/reading-the-rubric.md" "only when the" "engineer confirms it" "A sub-agent runs none" "tracked" \
    "read the working copy"
}

test_pr_review_step_4_checks_the_rubric() {
  grep -F "Then check each rubric criterion whose" "$PR_REVIEW" && grep -F "cite its criterion ID" "$PR_REVIEW"
}

test_dev_rev_prompt_criteria_sit_under_their_heading() {
  awk '/^Project review criteria/ { h = 1; next } h && /^<criteria>/ { ok = 1; exit } h && /^Check these first/ { exit }
    END { exit ok ? 0 : 1 }' "$DEV_REV" && has_all "$DEV_REV" "Do not run a \`How to check\` command"
}

test_dev_rev_gives_the_rubric_to_the_implementer_and_reviewer() {
  has_all "$DEV_REV" "Project review criteria" "before you write code" "criterion ID"
}

check "frontmatter name matches the folder" test_frontmatter_name_matches_folder
check "description starts with Use when and covers the job" test_description_starts_with_use_when_and_covers_the_job
check "the skill is manual-only" test_skill_is_manual_only
check "SKILL.md is at most 120 lines" test_skill_is_at_most_120_lines
check "H2 sections in order" test_required_h2_sections_in_order
check "Flow has five numbered steps in order" test_flow_has_five_numbered_steps_in_order
check "it needs a git repository" test_needs_a_git_repository
check "lookup order has three places" test_lookup_order_has_three_places
check "the lookup does not need a pack" test_lookup_does_not_need_a_pack
check "an existing rubric is never replaced without a yes" test_existing_rubric_is_never_replaced_without_a_yes
check "sources are a named list" test_sources_are_a_named_list
check "criterion fields and severity tiers" test_criterion_fields
check "an unsourced criterion is inferred: and Minor" test_unsourced_criterion_is_inferred_and_minor
check "criteria are capped and checkable" test_criteria_are_capped_and_checkable
check "built-in rules win" test_built_in_rules_win
check "the engineer corrects before saving" test_engineer_corrects_before_saving
check "save placement" test_save_placement
check "only the rubric file is written" test_only_one_file_is_written
check "never edits agent files; prints a paste block" test_never_edits_agent_files_and_prints_a_paste_block
check "read and search only" test_read_and_search_only
check "no sub-agents" test_no_sub_agents
check "the closing line says where the file is" test_closing_line_says_where_the_file_is
check "names no other skill" test_names_no_other_skill
check "privacy" test_privacy
check "no em-dashes" test_no_em_dashes
if [ -s "$NAMES" ]; then
  check "no customer or project names in tracked files" test_no_customer_names
else
  printf '  skip  no customer-names list\n'
fi
check "no absolute home paths" test_no_absolute_home_paths
check "prose lines are at most 120 characters" test_prose_lines_keep_120_characters
check "the template exists and SKILL.md references it" test_template_exists_and_is_referenced
check "the template has exactly two H2s" test_template_h2s_exact
check "the template header lines" test_template_header_lines
check "the template criterion fields in order" test_template_criterion_fields_in_order
check "the template says the R anchor is fixed" test_template_says_the_anchor_is_fixed
check "the template has two worked examples" test_template_has_two_worked_examples
check "severity is proposed; no criteria means no draft" test_severity_is_proposed_and_zero_criteria_stops
check "the Owner is the role the engineer names" test_owner_rule
check "the closing line covers nothing saved" test_closing_line_covers_nothing_saved
check "the Lint header line is optional" test_lint_header_line_is_optional
check "none placement creates the folder and never runs set" test_none_placement_creates_the_folder_and_never_runs_set
check "a refresh keeps IDs and told-by criteria" test_refresh_keeps_ids_and_told_by
check "the AGENTS.md block is on request and has a shape" test_agents_md_block_is_only_on_request_and_has_a_shape
check "find failures are handled" test_find_failures_are_handled
check "the pr-review template has the ID form and the no-rubric line" test_pr_review_template_has_the_id_form_and_the_no_rubric_line
check "pr-review keeps the rubric severity" test_pr_review_keeps_rubric_severity
check "dev-rev rubric rules" test_dev_rev_rubric_rules
check "the reading reference has three H2s" test_reading_reference_h2s_exact
check "the reading reference keeps the lookup order" test_reading_reference_matches_the_lookup_order
check "the reading reference has the reading rules" test_reading_reference_rules
check "the reading reference has the no-rubric line" test_reading_reference_no_rubric_line
check "pr-review and dev-rev point to the reference" test_both_review_skills_point_to_the_reference
check "pr-review cites the criterion ID" test_pr_review_cites_the_criterion_id
check "dev-rev gives the rubric to the implementer and reviewer" test_dev_rev_gives_the_rubric_to_the_implementer_and_reviewer
check "set and .gitignore appear only in never or print lines" test_set_and_gitignore_only_appear_in_never_lines
check "none folder must be absolute and outside the repository" test_none_folder_must_be_absolute_and_outside_the_repo
check "reading reference gates commands and reads untracked rubrics" test_reading_reference_command_gating
check "pr-review step 4 checks the rubric" test_pr_review_step_4_checks_the_rubric
check "dev-rev prompt puts criteria under their heading" test_dev_rev_prompt_criteria_sit_under_their_heading

echo
echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
