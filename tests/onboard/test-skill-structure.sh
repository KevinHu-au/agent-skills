#!/usr/bin/env bash
# Structure and drift tests for the agentd-onboard skill files. Reads the skill files. The only writes
# are throwaway folders from mktemp; nothing is deleted. They are left for the OS to clear and listed at the end.
# Usage: tests/onboard/test-skill-structure.sh
set -u

HERE=$(cd "$(dirname "$0")" && pwd -P)
REPO=$(cd "$HERE/../.." && pwd -P)
SKILL_DIR=${SKILL_DIR:-$REPO/skills/agentd-onboard}
SKILL="$SKILL_DIR/SKILL.md"
REFS="$SKILL_DIR/references"
PASS=0
FAIL=0
TMPS=""

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

REFERENCES="brief-template.md contract-fill.md dotnet.md explorer-prompts.md external-systems.md ios.md react.md safe-checks.md update-mode.md"

# frontmatter_value <key>: the value of a key in the first frontmatter block of SKILL.md.
frontmatter_value() {
  awk -v k="$1" '
    NR == 1 && $0 != "---" { exit 1 }
    /^---[ \t]*$/ { c++; if (c == 2) exit; next }
    c == 1 && index($0, k ": ") == 1 { print substr($0, length(k) + 3); exit }
  ' "$SKILL"
}

# h2_list <file>: the H2 headings of a markdown file, in order, one per line.
h2_list() { grep -E '^## ' "$1" | sed 's/^## //; s/[[:space:]]*$//'; }

test_frontmatter_name_matches_folder() {
  [ "$(frontmatter_value name)" = "agentd-onboard" ] && [ "$(basename "$SKILL_DIR")" = "agentd-onboard" ]
}

test_description_starts_with_use_when_and_covers_the_jobs() {
  local d
  d=$(frontmatter_value description)
  case "$d" in "Use when "*) ;; *) return 1 ;; esac
  printf '%s\n' "$d" | grep -qi 'onboarding' &&
    printf '%s\n' "$d" | grep -qi 'taking over support' &&
    printf '%s\n' "$d" | grep -qi 'refresh'
}

test_skill_is_at_most_160_lines() {
  [ -f "$SKILL" ] && [ "$(wc -l <"$SKILL" | tr -d ' ')" -le 160 ]
}

test_every_referenced_file_exists() {
  local f listed
  [ -f "$SKILL" ] || return 1
  listed=$(grep -oE 'references/[A-Za-z0-9._-]+\.md' "$SKILL" | sed 's|^references/||' | sort -u)
  [ "$listed" = "$(printf '%s\n' $REFERENCES | sort -u)" ] || return 1
  for f in $REFERENCES; do [ -f "$SKILL_DIR/references/$f" ] || return 1; done
}

test_required_h2_sections_in_order() {
  [ -f "$SKILL" ] &&
    [ "$(h2_list "$SKILL" | tr '\n' '|')" = "Prerequisite|Modes|Flow|Safe checks|Markers|Output|Rules|" ]
}

test_skill_has_no_absolute_home_paths() {
  [ -f "$SKILL" ] && ! grep -qE '/Users/|/home/|~/' "$SKILL"
}

# checker_sections: the nine H2 names that check-brief.sh requires (rule R4), one per line.
checker_sections() {
  awk '/^SECTIONS=\(/ { on = 1 } on { print } on && /\)$/ { exit }' "$HERE/check-brief.sh" | grep -oE '"[^"]+"' | tr -d '"'
}

# has_all <file> <text>...: the file contains every text, ignoring case.
has_all() {
  local f=$1 t
  shift
  [ -s "$f" ] || return 1
  for t in "$@"; do grep -qiF -- "$t" "$f" || return 1; done
}

test_brief_template_h2s_match_checker() {
  [ -s "$REFS/brief-template.md" ] &&
    [ "$(h2_list "$REFS/brief-template.md" | tr '\n' '|')" = "$(checker_sections | tr '\n' '|')" ]
}

test_filled_brief_template_passes_the_checker() {
  local d
  [ -s "$REFS/brief-template.md" ] || return 1
  d=$(mktemp -d)
  TMPS="$TMPS $d"
  sed -e 's|^Scanned commit: .*|Scanned commit: 0123456789abcdef0123456789abcdef01234567|' \
    -e 's|^Scanned on: .*|Scanned on: 2026-10-22|' \
    -e 's|^Working tree: .*|Working tree: clean|' "$REFS/brief-template.md" >"$d/README.md"
  "$HERE/check-brief.sh" "$d"
}

test_explorer_prompts_has_six_angles_and_synthesizer() {
  local f="$REFS/explorer-prompts.md" angle
  [ -s "$f" ] || return 1
  for angle in "UI and routes" "API and permissions" "Domain model and schema" "Data-flow tracer" \
    "Integrations and dependencies" "Documentation and tests" "Synthesizer"; do
    h2_list "$f" | grep -qxF "$angle" || return 1
  done
  has_all "$f" "read-only" "600 words" "Components" "Flow" "Files Read" "Boundaries" "Non-obvious" "Open Questions"
}

# section_of <file> <h2 name>: the lines under "## <name>" up to the next H2.
section_of() { awk -v h="## $2" '$0 == h { on = 1; next } /^## / { on = 0 } on' "$1"; }

test_safe_checks_lists_forbidden_commands() {
  local f="$REFS/safe-checks.md" never t
  never=$(section_of "$f" "Never")
  [ -n "$never" ] && [ -n "$(section_of "$f" "Allowed")" ] || return 1
  for t in "DbUp" "migrations" "integration tests" "database" "Start the application"; do
    printf '%s\n' "$never" | grep -qiF -- "$t" || return 1
  done
  ! section_of "$f" "Allowed" | grep -qiE 'DbUp|migrations|integration tests' &&
    section_of "$f" "Headless" | grep -qi 'read-only' &&
    section_of "$f" "Confirmation" | grep -qi "project's own build and test code" &&
    has_all "$f" "one confirmation"
}

test_references_name_the_four_markers() {
  local f
  for f in "$SKILL" "$REFS/explorer-prompts.md" "$REFS/brief-template.md"; do
    has_all "$f" 'unknown:' 'inferred:' 'changed:' 'conflict:' || return 1
  done
}

test_external_systems_has_method_limits_and_record() {
  local f="$REFS/external-systems.md"
  has_all "$f" "## Method" "## Limits" "## Record for each system" "integration code" "callers" "background job" \
    "inferred:" "unknown: ask the" "owner" "direction" "protocol" "failure behaviour" "local test"
}

test_dotnet_reference_names_where_to_look() {
  has_all "$REFS/dotnet.md" "*.csproj" "TargetFramework" "Route" "Authorize" "IHostedService" "AddHttpClient" \
    "appsettings" "DbUp" "migrations" "stored procedures"
}

test_ios_reference_names_where_to_look() {
  has_all "$REFS/ios.md" "*.xcodeproj" "Package.swift" "IPHONEOS_DEPLOYMENT_TARGET" "@main" "NavigationStack" "@Observable" \
    "SwiftData" "SchemaMigrationPlan" "Info.plist" "xcodebuild" "-only-testing" "general knowledge" "not yet checked" \
    "safe-checks.md" "Never run them from this skill" &&
    grep -qF 'For iOS (SwiftUI) projects also load `references/ios.md`' "$SKILL"
}

test_react_reference_names_where_to_look() {
  has_all "$REFS/react.md" "react-dom" "vite.config" "createBrowserRouter" "createContext" "NSwag" ".env" "localStorage" \
    "general knowledge" "not yet checked" "safe-checks.md" "Never run them from this skill" "root \`package.json\` of a monorepo" &&
    grep -qF 'For React web projects (a `package.json` that lists `react-dom` under `dependencies`, in any workspace) also load `references/react.md`' "$SKILL"
}

test_update_mode_has_the_eight_steps_in_order() {
  local f="$REFS/update-mode.md" n line prev=0
  [ -s "$f" ] || return 1
  for n in 1 2 3 4 5 6 7 8; do
    line=$(grep -n "^$n\. " "$f" | head -1 | cut -d: -f1)
    [ -n "$line" ] && [ "$line" -gt "$prev" ] || return 1
    prev=$line
  done
  ! grep -q '^9\. ' "$f"
}

test_update_mode_covers_missing_header() {
  has_all "$REFS/update-mode.md" "Scanned commit" "missing or garbled" "full re-check"
}

test_update_mode_covers_missing_commit() {
  has_all "$REFS/update-mode.md" "git cat-file -e" "shallow" "rebased" "no commits" "full re-check"
}

test_update_mode_has_noop_rule() {
  has_all "$REFS/update-mode.md" "write nothing" "not even the header date"
}

test_update_mode_uses_git_diff_name_only() {
  has_all "$REFS/update-mode.md" "git diff --name-only --no-renames" "git status --porcelain" "vanish"
}

test_update_mode_last_refreshed_line_passes_the_checker() {
  local f="$REFS/update-mode.md" d line
  [ -s "$f" ] || return 1
  line=$(grep -m1 '^Last refreshed: ' "$f") || return 1
  d=$(mktemp -d)
  TMPS="$TMPS $d"
  sed -e 's|^Scanned commit: .*|Scanned commit: 0123456789abcdef0123456789abcdef01234567|' \
    -e 's|^Scanned on: .*|Scanned on: 2026-10-22|' \
    -e 's|^Working tree: .*|Working tree: clean|' "$REFS/brief-template.md" |
    awk -v l="$line" '{ print } /^Working tree: / { print l }' >"$d/README.md"
  grep -q '^Last refreshed: ' "$d/README.md" && "$HERE/check-brief.sh" "$d"
}

TEMPLATE="$REPO/templates/project-contract.md"

test_contract_headings_match_template() {
  [ -s "$REFS/contract-fill.md" ] && [ -s "$TEMPLATE" ] &&
    [ "$(grep '^### ' "$REFS/contract-fill.md" | tr '\n' '|')" = "$(grep '^### ' "$TEMPLATE" | tr '\n' '|')" ] &&
    [ "$(grep -c '^### ' "$TEMPLATE")" -eq 5 ]
}

test_contract_fields_match_template() {
  local name
  [ -s "$REFS/contract-fill.md" ] && [ -s "$TEMPLATE" ] || return 1
  grep -q '^- \*\*' "$TEMPLATE" || return 1
  grep '^- \*\*' "$TEMPLATE" | sed 's/^- \*\*\([^*]*\)\*\*.*/\1/; s/:$//' | while IFS= read -r name; do
    grep -qF -- "**$name" "$REFS/contract-fill.md" || { echo "missing field: $name" >&2; exit 1; }
  done
}

test_contract_fill_rules_cover_where_and_when_to_ask() {
  has_all "$REFS/contract-fill.md" "AGENTS.md" "CLAUDE.md" "ask before" "does not exist" "imports" "update mode" \
    "unknown: ask" "inferred:" "conflict:" "secret" "headless"
}

test_the_pack_folder_is_excluded_from_changes_and_dirty_check() {
  local exclude="':(exclude)docs/onboarding'"
  has_all "$REFS/update-mode.md" "git diff --name-only --no-renames <commit>..HEAD -- . $exclude" \
    "git status --porcelain --no-renames --untracked-files=all -- . $exclude" "the pack itself" &&
    has_all "$REFS/brief-template.md" "git status --porcelain -- . $exclude" &&
    has_all "$SKILL" 'outside `docs/onboarding/`'
}

# Wording fixes found by the evaluation runs (EVAL.md, iteration 1).
test_one_rule_for_what_comes_first_in_open_questions() {
  has_all "$REFS/contract-fill.md" "after the unconfirmed use cases" &&
    ! grep -qi 'first in `open-questions.md`' "$REFS/contract-fill.md"
}

test_commit_id_lengths_are_not_ambiguous() {
  has_all "$REFS/update-mode.md" 'full output of `git rev-parse HEAD`' 'inside the `Last refreshed:` line' &&
    has_all "$REFS/brief-template.md" "full output of git rev-parse HEAD"
}

test_worktree_check_is_robust_and_has_a_headless_fallback() {
  has_all "$SKILL" "--path-format=absolute" "If nobody can answer, write to the main checkout" \
    "the repository root is the main checkout"
}

test_template_has_a_home_for_contract_facts_and_partial_gaps() {
  has_all "$REFS/brief-template.md" "If the project contract was not written" "access rules" \
    "add a short \`unknown:\` note" "list the changed files"
}

test_use_cases_stay_inferred_until_the_engineer_confirms() {
  has_all "$REFS/explorer-prompts.md" "until the engineer confirms it, even when a document states it"
}

test_references_cover_missing_project_files_and_committed_secrets() {
  has_all "$REFS/safe-checks.md" "no project file" "conflict:" &&
    has_all "$REFS/external-systems.md" "A committed secret is itself a finding" "Never copy a secret value" &&
    ! grep -q 'Never read or copy a secret' "$REFS/external-systems.md"
}

# Second round of wording fixes (EVAL.md, iteration 2).
test_open_questions_is_always_written() {
  has_all "$SKILL" '`open-questions.md` is always written'
}

test_worktree_works_entirely_in_the_main_checkout() {
  has_all "$SKILL" "read the code, run git commands and write the pack in the main checkout" "bare" \
    'put the warning in your final reply and in `open-questions.md`'
}

test_findings_go_to_unknowns_and_open_questions() {
  has_all "$SKILL" 'List the stale source as a finding in Unknowns and in `open-questions.md`'
}

# Third round of wording fixes (EVAL.md, iteration 3), from the no-op, update and shallow-clone runs.
test_modes_say_which_flow_steps_apply_in_update_mode() {
  has_all "$SKILL" 'instead of Flow steps 2 to 4'
}

test_side_files_carry_the_scan_lines_and_update_refreshes_them() {
  has_all "$SKILL" 'Each side file starts with the same `Scanned commit:` and `Scanned on:` lines' &&
    has_all "$REFS/update-mode.md" "each side file"
}

test_update_mode_handles_full_recheck_and_the_unwritten_contract() {
  has_all "$REFS/update-mode.md" "For a full re-check" &&
    has_all "$REFS/contract-fill.md" "If an earlier run did not write the contract and you can ask now, ask now"
}

test_a_finding_is_not_a_conflict() {
  has_all "$SKILL" 'A committed secret, or any problem with no second source, is a finding, not a `conflict:`'
}

test_update_mode_names_the_flow_step_it_means() {
  has_all "$SKILL" 'Run the check in Flow step 5 (the eight questions) on the sections you changed'
}

# Fixes from the code review, round 1.
test_update_mode_reaches_the_contract() {
  has_all "$SKILL" 'Refresh the project contract as Flow step 4 says' &&
    has_all "$REFS/update-mode.md" "contract-fill.md" '## Project contract' "if an earlier run did not write it"
}

test_the_skills_own_output_is_not_a_change() {
  has_all "$REFS/update-mode.md" "what this skill wrote itself" 'bin/' "git diff -U0" "hunk" &&
    has_all "$REFS/brief-template.md" "inside its \`## Project contract\` section" "do not count" &&
    has_all "$SKILL" "the contract section this skill wrote, and build output from safe checks never count"
}

test_git_commands_run_from_the_root_and_read_their_output_correctly() {
  has_all "$REFS/update-mode.md" 'git rev-parse --show-toplevel' "from the repository root" "XY path" "-z" &&
    has_all "$REFS/brief-template.md" "from the repository root"
}

test_a_user_guide_for_a_feature_maps_to_use_cases() {
  has_all "$REFS/update-mode.md" "a user guide for a feature: Use cases"
}

test_update_mode_step_4_does_not_contradict_itself() {
  has_all "$REFS/update-mode.md" 'A changed path that no `Sources:` line names also counts' &&
    ! grep -q 'only when a path in its' "$REFS/update-mode.md"
}

test_worktree_and_exclude_commands_work_for_every_layout() {
  has_all "$SKILL" "git worktree list --porcelain" "git rev-parse --git-path info/exclude" "bare" &&
    ! grep -q 'parent of the common git folder' "$SKILL"
}

test_a_foreign_onboarding_readme_is_not_touched() {
  has_all "$SKILL" "not written by this skill" "Do not change it" &&
    has_all "$REFS/update-mode.md" "is not a pack" '## First-ticket checklist'
}

test_dirty_header_and_old_markers_are_handled() {
  has_all "$REFS/update-mode.md" "files that Unknowns lists as uncommitted" 'remove every `changed:` marker'
}

test_package_restore_and_project_code_are_said_in_both_places() {
  has_all "$SKILL" "package restore" &&
    has_all "$REFS/safe-checks.md" "run the project's own build and test code"
}

test_a_repository_with_no_commits_stops_with_one_line() {
  has_all "$SKILL" "needs at least one commit"
}

test_eval_makes_a_real_shallow_clone() {
  has_all "$HERE/EVAL.md" "git clone --depth 1 file://" "is-shallow-repository"
}

# Every skill in this repository is manual-only: the model never starts one by itself (PLAN.local.md, section 3).
test_every_skill_in_the_repository_is_manual_only() {
  local f found=0
  for f in "$REPO"/skills/*/SKILL.md; do
    found=$((found + 1))
    awk 'NR == 1 && $0 != "---" { exit } /^---[ \t]*$/ { c++; if (c == 2) exit; next } c == 1' "$f" |
      grep -qx 'disable-model-invocation: true' || return 1
  done
  [ "$found" -ge 4 ]
}

echo "agentd-onboard skill structure"
check "frontmatter name matches the folder" test_frontmatter_name_matches_folder
check "description starts with 'Use when' and covers onboarding, taking over support and refreshing" test_description_starts_with_use_when_and_covers_the_jobs
check "SKILL.md is at most 160 lines" test_skill_is_at_most_160_lines
check "SKILL.md names the seven reference files and each exists" test_every_referenced_file_exists
check "the seven H2 sections appear in order" test_required_h2_sections_in_order
check "SKILL.md has no absolute home paths" test_skill_has_no_absolute_home_paths
check "brief-template.md H2 sections equal the checker's required sections" test_brief_template_h2s_match_checker
check "a filled-in brief-template.md passes check-brief.sh" test_filled_brief_template_passes_the_checker
check "explorer-prompts.md has six angles, the report template and a synthesizer" test_explorer_prompts_has_six_angles_and_synthesizer
check "safe-checks.md lists the forbidden commands" test_safe_checks_lists_forbidden_commands
check "SKILL.md, explorer-prompts.md and brief-template.md name the four markers" test_references_name_the_four_markers
check "external-systems.md has method, limits and the per-system record" test_external_systems_has_method_limits_and_record
check "dotnet.md names where to look in a .NET project" test_dotnet_reference_names_where_to_look
check "ios.md names where to look in an iOS project" test_ios_reference_names_where_to_look
check "react.md names where to look in a React project" test_react_reference_names_where_to_look
check "update-mode.md has the eight steps, in order" test_update_mode_has_the_eight_steps_in_order
check "update-mode.md covers a missing or garbled header" test_update_mode_covers_missing_header
check "update-mode.md covers a scanned commit that does not exist" test_update_mode_covers_missing_commit
check "update-mode.md has the no-op rule" test_update_mode_has_noop_rule
check "update-mode.md uses git diff --name-only and git status --porcelain" test_update_mode_uses_git_diff_name_only
check "the Last refreshed example line passes check-brief.sh" test_update_mode_last_refreshed_line_passes_the_checker
check "contract-fill.md headings equal the template's five headings" test_contract_headings_match_template
check "contract-fill.md names every field in the template" test_contract_fields_match_template
check "contract-fill.md says which file to write and when to ask" test_contract_fill_rules_cover_where_and_when_to_ask
check "the pack folder is excluded from the change list and the dirty check" test_the_pack_folder_is_excluded_from_changes_and_dirty_check
check "one rule for what comes first in open-questions.md" test_one_rule_for_what_comes_first_in_open_questions
check "commit id lengths are not ambiguous" test_commit_id_lengths_are_not_ambiguous
check "worktree check uses absolute paths and has a headless fallback" test_worktree_check_is_robust_and_has_a_headless_fallback
check "template has a home for contract facts and partial gaps" test_template_has_a_home_for_contract_facts_and_partial_gaps
check "use cases stay inferred until the engineer confirms" test_use_cases_stay_inferred_until_the_engineer_confirms
check "references cover missing project files and committed secrets" test_references_cover_missing_project_files_and_committed_secrets
check "open-questions.md is always written" test_open_questions_is_always_written
check "a worktree run reads, runs git and writes in the main checkout" test_worktree_works_entirely_in_the_main_checkout
check "stale-source findings go to Unknowns and open-questions.md" test_findings_go_to_unknowns_and_open_questions
check "Modes say which Flow steps update mode replaces" test_modes_say_which_flow_steps_apply_in_update_mode
check "side files carry the scan lines and update mode refreshes them" test_side_files_carry_the_scan_lines_and_update_refreshes_them
check "update mode covers a full re-check and the unwritten contract" test_update_mode_handles_full_recheck_and_the_unwritten_contract
check "a finding is not a conflict" test_a_finding_is_not_a_conflict
check "Modes name the Flow step they mean, not a bare step number" test_update_mode_names_the_flow_step_it_means
check "update mode reaches the project contract" test_update_mode_reaches_the_contract
check "the skill's own output is not counted as a change" test_the_skills_own_output_is_not_a_change
check "git commands run from the root and their output is read correctly" test_git_commands_run_from_the_root_and_read_their_output_correctly
check "a user guide for a feature maps to Use cases" test_a_user_guide_for_a_feature_maps_to_use_cases
check "update mode step 4 does not contradict itself" test_update_mode_step_4_does_not_contradict_itself
check "worktree and exclude commands work for every repository layout" test_worktree_and_exclude_commands_work_for_every_layout
check "a foreign docs/onboarding/README.md is not touched" test_a_foreign_onboarding_readme_is_not_touched
check "a dirty header and old changed: markers are handled" test_dirty_header_and_old_markers_are_handled
check "package restore and project code are said in both places" test_package_restore_and_project_code_are_said_in_both_places
check "a repository with no commits stops with one line" test_a_repository_with_no_commits_stops_with_one_line
check "EVAL.md makes a real shallow clone" test_eval_makes_a_real_shallow_clone
check "every skill in the repository sets disable-model-invocation: true" test_every_skill_in_the_repository_is_manual_only

echo
echo "passed=$PASS failed=$FAIL"
echo "temp folders left in place:$TMPS"
[ "$FAIL" -eq 0 ]
