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

REFERENCES="brief-template.md contract-fill.md dotnet.md explorer-prompts.md feature-to-code-template.md external-systems.md ios.md react.md safe-checks.md update-mode.md"

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

# REFERENCES must match the .md files in the references folder (so no file is unlisted), and the label of the
# reference-file check must name that count in words.
test_reference_file_label_matches_the_list() {
  local n on_disk word
  n=$(set -- $REFERENCES; echo $#)
  on_disk=$(ls "$REFS" | grep -c '\.md$')
  [ "$n" -eq "$on_disk" ] || return 1
  case "$n" in 10) word=ten ;; 11) word=eleven ;; 12) word=twelve ;; *) return 1 ;; esac
  grep -qF "check \"SKILL.md names the $word reference files" "$0"
}

test_required_h2_sections_in_order() {
  [ -f "$SKILL" ] &&
    [ "$(h2_list "$SKILL" | tr '\n' '|')" = "Prerequisite|Modes|Flow|Safe checks|Markers|Output|Rules|" ]
}

test_skill_has_no_absolute_home_paths() {
  [ -f "$SKILL" ] && ! grep -qE '/Users/|/home/|~/' "$SKILL"
}

# checker_sections: the ten H2 names that check-brief.sh requires (rule R4), one per line.
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

# fill_pack <dir>: a filled pack from the templates. README.md and feature-to-code.md get real scan lines.
fill_pack() {
  local d=$1 f
  for f in brief-template.md:README.md feature-to-code-template.md:feature-to-code.md; do
    sed -e 's|^Scanned commit: .*|Scanned commit: 0123456789abcdef0123456789abcdef01234567|' \
      -e 's|^Scanned on: .*|Scanned on: 2026-10-22|' \
      -e 's|^Working tree: .*|Working tree: clean|' "$REFS/${f%%:*}" >"$d/${f##*:}"
  done
}

test_brief_template_h2s_match_checker() {
  [ -s "$REFS/brief-template.md" ] &&
    [ "$(h2_list "$REFS/brief-template.md" | tr '\n' '|')" = "$(checker_sections | tr '\n' '|')" ]
}

test_filled_brief_template_passes_the_checker() {
  local d
  [ -s "$REFS/brief-template.md" ] && [ -s "$REFS/feature-to-code-template.md" ] || return 1
  d=$(mktemp -d)
  TMPS="$TMPS $d"
  fill_pack "$d"
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

test_update_mode_upgrades_an_older_layout_once() {
  local f="$REFS/update-mode.md" s5 s8
  has_all "$f" "older layout" '## Start here' "Risks and delivery" "feature-to-code.md" "upgraded the layout" || return 1
  s5=$(grep '^5\. ' "$f")
  s8=$(grep '^8\. ' "$f")
  for a in "UI and routes" "API and permissions" "Domain model and schema" "Data-flow tracer"; do
    printf '%s\n' "$s5" | grep -qiF -- "$a" || return 1
  done
  printf '%s\n' "$s8" | grep -qiF "older layout" && printf '%s\n' "$s8" | grep -qiF "once"
}

test_feature_to_code_blocks_have_their_own_sources() {
  local s4
  s4=$(grep '^4\. ' "$REFS/update-mode.md")
  printf '%s\n' "$s4" | grep -qiF 'each of its blocks has its own `Sources:` line'
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
  [ -s "$REFS/feature-to-code-template.md" ] || return 1
  fill_pack "$d"
  awk -v l="$line" '{ print } /^Working tree: / { print l }' "$d/README.md" >"$d/README.tmp" && mv "$d/README.tmp" "$d/README.md"
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
  has_all "$SKILL" 'Run the check in Flow step 5 (the nine questions) on the sections you changed'
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
check "SKILL.md names the ten reference files and each exists" test_every_referenced_file_exists
check "the reference-file label says ten, the number in REFERENCES" test_reference_file_label_matches_the_list
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
check "update mode upgrades an older layout once" test_update_mode_upgrades_an_older_layout_once
check "feature-to-code.md blocks have their own Sources lines" test_feature_to_code_blocks_have_their_own_sources
check "worktree and exclude commands work for every repository layout" test_worktree_and_exclude_commands_work_for_every_layout
check "a foreign docs/onboarding/README.md is not touched" test_a_foreign_onboarding_readme_is_not_touched
check "a dirty header and old changed: markers are handled" test_dirty_header_and_old_markers_are_handled
check "package restore and project code are said in both places" test_package_restore_and_project_code_are_said_in_both_places
check "a repository with no commits stops with one line" test_a_repository_with_no_commits_stops_with_one_line
check "EVAL.md makes a real shallow clone" test_eval_makes_a_real_shallow_clone
check "every skill in the repository sets disable-model-invocation: true" test_every_skill_in_the_repository_is_manual_only

# Skill-fit problems from the first real check (plan section 12).
test_fit_existing_agents_md_sections_are_kept_and_pointed_to() {
  has_all "$REFS/contract-fill.md" "has no \`## Project contract\`" "keep those sections as they are" "points to it"
}

test_fit_headless_run_leaves_the_proposed_contract_ready_to_paste() {
  has_all "$REFS/contract-fill.md" "after the unconfirmed use cases" "proposed \`## Project contract\` section" "ready to paste"
}

test_fit_rerun_scripts_are_edited_in_place() {
  local f
  for f in "$TEMPLATE" "$REFS/contract-fill.md" "$REFS/brief-template.md"; do
    has_all "$f" "run once" "re-run on every deploy" "edited in place" || return 1
    ! grep -qiE 'the rule that (applied scripts are|an applied script is) never edited' "$f" || return 1
  done
}

test_fit_sequential_fallback_keeps_output_small() {
  has_all "$REFS/explorer-prompts.md" "one after another" "drop the files you read" "list what you skipped"
}

test_fit_a_search_count_is_inferred_not_a_run() {
  has_all "$SKILL" "search count" "is not a run" "the command that would settle it"
}

test_fit_no_input_means_every_question_is_optional() {
  has_all "$SKILL" "The skill must run with no input at all: every question is optional"
}

test_fit_the_word_target_covers_the_brief_only() {
  has_all "$SKILL" "The 2,000-word target is for \`README.md\` only" "whole pack under about 5,000 words"
}

check "fit: existing AGENTS.md sections are kept and pointed to" test_fit_existing_agents_md_sections_are_kept_and_pointed_to
check "fit: a headless run leaves the proposed contract ready to paste" test_fit_headless_run_leaves_the_proposed_contract_ready_to_paste
check "fit: scripts that re-run on every deploy are edited in place" test_fit_rerun_scripts_are_edited_in_place
check "fit: the sequential fallback keeps output small" test_fit_sequential_fallback_keeps_output_small
check "fit: a search count is inferred, not a run" test_fit_a_search_count_is_inferred_not_a_run
check "fit: no input means every question is optional" test_fit_no_input_means_every_question_is_optional
check "fit: the word target covers the brief only" test_fit_the_word_target_covers_the_brief_only

# Task 3: ninth question, Start here, feature-to-code.
test_success_test_has_nine_questions() {
  local out n line prev=0
  out=$(section_of "$SKILL" "Output")
  for n in 1 2 3 4 5 6 7 8 9; do
    line=$(printf '%s\n' "$out" | grep -n "^$n\. " | head -1 | cut -d: -f1)
    [ -n "$line" ] && [ "$line" -gt "$prev" ] || return 1
    prev=$line
  done
  ! printf '%s\n' "$out" | grep -q '^10\. '
}

test_checklist_has_nine_items() {
  local f="$REFS/brief-template.md" cl
  cl=$(section_of "$f" "First-ticket checklist")
  printf '%s\n' "$cl" | grep -q '^9\. ' && ! printf '%s\n' "$cl" | grep -q '^10\. ' &&
    has_all "$f" "Nine items" && ! grep -qF "Eight items" "$f"
}

test_feature_to_code_template_has_the_fixed_tables() {
  has_all "$REFS/feature-to-code-template.md" "Data loads in" "Calculations and rules in" "### Search terms" \
    "Business term" "Scanned commit:" "Scanned on:" "inferred: no caller found"
}

test_start_here_template_has_the_fixed_lines() {
  has_all "$REFS/brief-template.md" "Open:" "Run:" "Pattern:" '```mermaid' "Key concept: unknown:" "feature-to-code.md"
}

test_word_target_leaves_out_open_questions() {
  has_all "$SKILL" 'not counting `open-questions.md`' "whole pack under about 5,000 words"
}

test_findings_do_not_go_in_risks_and_delivery() {
  local f="$REFS/brief-template.md"
  has_all "$SKILL" 'Put it in Unknowns and in `open-questions.md`, not in Risks and delivery.' &&
    ! grep -qF "Put it in Risks and delivery" "$SKILL" &&
    section_of "$f" "Risks and delivery" | grep -qF "standing rules" &&
    section_of "$f" "Unknowns" | grep -qF "findings as well as gaps" &&
    has_all "$REFS/external-systems.md" 'in Unknowns and in `open-questions.md`' &&
    has_all "$REFS/explorer-prompts.md" 'findings go to `open-questions.md`'
}

check "success test has nine questions in order" test_success_test_has_nine_questions
check "checklist has nine items" test_checklist_has_nine_items
check "feature-to-code-template.md has the fixed tables" test_feature_to_code_template_has_the_fixed_tables
check "Start here template has the fixed lines" test_start_here_template_has_the_fixed_lines
check "word target leaves out open-questions.md" test_word_target_leaves_out_open_questions
check "findings do not go in Risks and delivery" test_findings_do_not_go_in_risks_and_delivery

# Task 5: explorer fields, Synthesizer sub-steps, stack rows, Flow step 3.
test_explorers_report_layers_load_and_calculation_points() {
  local f="$REFS/explorer-prompts.md"
  has_all "$f" "Layer chain" "Load points" "Calculation points" "Key concept candidate" "Label-to-field list" "600 words" \
    "Each documented calculation or business rule" "which calculations have a test" &&
    [ "$(grep -o 'up to about 800 words' "$f" | wc -l | tr -d ' ')" = "3" ]
}

test_synthesizer_sub_steps_keep_step_numbers() {
  local s n l3 l3a l3b l3c l4
  s=$(section_of "$REFS/explorer-prompts.md" "Synthesizer")
  l3=$(printf '%s\n' "$s" | grep -n '^3\. ' | head -1 | cut -d: -f1)
  l3a=$(printf '%s\n' "$s" | grep -n '^   - 3a\. ' | head -1 | cut -d: -f1)
  l3b=$(printf '%s\n' "$s" | grep -n '^   - 3b\. ' | head -1 | cut -d: -f1)
  l3c=$(printf '%s\n' "$s" | grep -n '^   - 3c\. ' | head -1 | cut -d: -f1)
  l4=$(printf '%s\n' "$s" | grep -n '^4\. ' | head -1 | cut -d: -f1)
  [ -n "$l3" ] && [ -n "$l3a" ] && [ -n "$l3b" ] && [ -n "$l3c" ] && [ -n "$l4" ] || return 1
  [ "$l3" -lt "$l3a" ] && [ "$l3a" -lt "$l3b" ] && [ "$l3b" -lt "$l3c" ] && [ "$l3c" -lt "$l4" ] || return 1
  for n in 5 6 7; do printf '%s\n' "$s" | grep -q "^$n\. " || return 1; done
}

test_stack_references_name_load_and_calculation_rows() {
  local f
  for f in dotnet react ios; do
    grep -q '^| Data loading |' "$REFS/$f.md" && grep -q '^| Calculations |' "$REFS/$f.md" || return 1
  done
}

test_flow_step_3_shows_the_key_concept() {
  grep '^3\. \*\*Show the drafts' "$SKILL" | grep -qF "key concept"
}

test_synthesizer_checks_nine_questions() {
  has_all "$REFS/explorer-prompts.md" "nine questions" && ! grep -qF "eight questions" "$REFS/explorer-prompts.md"
}

check "explorers report layers, load points and calculation points" test_explorers_report_layers_load_and_calculation_points
check "Synthesizer sub-steps keep step numbers" test_synthesizer_sub_steps_keep_step_numbers
check "stack references name load and calculation rows" test_stack_references_name_load_and_calculation_rows
check "Flow step 3 shows the key concept" test_flow_step_3_shows_the_key_concept
check "Synthesizer checks nine questions" test_synthesizer_checks_nine_questions

# The Synthesizer reads both templates, because Flow step 4 writes both files.
test_synthesizer_inputs_name_both_templates() {
  local inputs
  inputs=$(section_of "$REFS/explorer-prompts.md" "Synthesizer" | grep '^Inputs:') || return 1
  printf '%s\n' "$inputs" | grep -qF '`brief-template.md`' &&
    printf '%s\n' "$inputs" | grep -qF '`feature-to-code-template.md`'
}

# The shared report template has fixed headings, so it must say where the "Also report" fields go.
test_report_template_says_where_also_report_fields_go() {
  local s
  s=$(section_of "$REFS/explorer-prompts.md" "Shared rules and report template")
  printf '%s\n' "$s" | grep -qF '"Also report"' &&
    printf '%s\n' "$s" | grep -qF 'under `### Flow`' &&
    printf '%s\n' "$s" | grep -qF 'about 600 words'
}

check "Synthesizer inputs name both templates" test_synthesizer_inputs_name_both_templates
check "the report template says where the Also report fields go" test_report_template_says_where_also_report_fields_go

# 3c: the tie rule, the inferred: fallback and the layers shown with the drafts.
test_synthesizer_3c_has_tie_rule_fallback_and_layers() {
  local c
  c=$(section_of "$REFS/explorer-prompts.md" "Synthesizer" | grep '^   - 3c\. ') || return 1
  printf '%s\n' "$c" | grep -qF 'On a tie, show both candidates' &&
    printf '%s\n' "$c" | grep -qF 'and ask' &&
    printf '%s\n' "$c" | grep -qF 'keep the first and mark it `inferred:`' &&
    printf '%s\n' "$c" | grep -qF 'layers from 3a' &&
    printf '%s\n' "$c" | grep -qF 'with the drafts and the key concept'
}

check "Synthesizer 3c has the tie rule, the inferred: fallback and shows the layers" test_synthesizer_3c_has_tie_rule_fallback_and_layers

# Task 6: the skill checks paths and search terms itself; the skill files stay generic.
test_skill_checks_paths_and_terms_itself() {
  local step t
  step=$(grep '^4\. \*\*Write' "$SKILL") || return 1
  for t in 'test -e' 'git grep --untracked -F' "':(exclude)docs/onboarding'" 'before any file is written' \
    'Run:' 'Business term' 'unknown:' 'one value at a time' 'no file is needed for this' \
    'check each value as you write it down' "awk 'END { print NR }'" 'strip a leading `./`' \
    'skip cells that start with `none` as a whole word, `unknown:` or `inferred:`' 'a `changed:` prefix is read through' \
    'read only backticked values' 'as one quoted argument' "'\\''"; do
    printf '%s\n' "$step" | grep -qF -- "$t" || return 1
  done
}

# phrase_in_file <file> <phrase>: 0 when the file holds the phrase (ignoring case), 1 when it does not, 2 on a
# grep error or a missing file. A phrase of 3 characters or fewer must match a whole word. A trailing carriage
# return on the phrase is dropped. The phrase is never printed.
phrase_in_file() {
  local f=$1 p=$2 w="" rc
  p=${p%$'\r'}
  [ -f "$f" ] || return 2
  [ "${#p}" -le 3 ] && w="-w"
  grep -q -F -i $w -e "$p" "$f"
  rc=$?
  [ "$rc" -le 2 ] || rc=2
  return "$rc"
}

test_forbidden_phrase_helper_works() {
  local t rc
  t=$(mktemp)
  TMPS="$TMPS $t"
  printf 'We built Contoso Widgets for a client.\nThe cat sat on the mat.\n' >"$t"
  phrase_in_file "$t" "contoso widgets" || return 1
  phrase_in_file "$t" "-nope"
  [ $? -eq 1 ] || return 1
  phrase_in_file "$t" "cat" || return 1
  phrase_in_file "$t" "ca"
  [ $? -eq 1 ] || return 1
  # A phrase that ends in a carriage return (a CRLF word list) still matches.
  phrase_in_file "$t" "contoso widgets"$'\r' || return 1
  # A missing file is an error (2), not "no match".
  phrase_in_file "$t.missing" "contoso widgets"
  [ $? -eq 2 ] || return 1
  printf 'a -dash phrase\n' >"$t"
  phrase_in_file "$t" "-dash"
}

# FORBIDDEN_FILES: every file that must stay free of the phrases in ONBOARD_FORBIDDEN_WORDS.
FORBIDDEN_FILES=("$REFS/brief-template.md" "$REFS/feature-to-code-template.md" "$REFS/explorer-prompts.md" "$SKILL"
  "$REFS/update-mode.md" "$HERE/EVAL.md" "$HERE/expected-facts.md")

# scan_forbidden <file>...: 0 when no file holds a phrase from ONBOARD_FORBIDDEN_WORDS, 1 when one does, 2 when a
# file is missing or grep fails. The file name is printed, never the phrase. Each phrase loses a trailing CR.
scan_forbidden() {
  local f phrase rc
  for f in "$@"; do
    [ -f "$f" ] || { echo "cannot scan $f: it does not exist" >&2; return 2; }
  done
  [ -n "${ONBOARD_FORBIDDEN_WORDS:-}" ] || return 0
  while IFS= read -r phrase; do
    phrase=${phrase%$'\r'}
    [ -n "$phrase" ] || continue
    for f in "$@"; do
      phrase_in_file "$f" "$phrase"
      rc=$?
      case $rc in
        0) echo "a forbidden phrase is in $f" >&2; return 1 ;;
        1) ;;
        *) echo "grep failed on $f" >&2; return 2 ;;
      esac
    done
  done <<<"$ONBOARD_FORBIDDEN_WORDS"
  return 0
}

test_forbidden_scan_covers_all_files_and_fails_on_errors() {
  local t rc
  t=$(mktemp)
  TMPS="$TMPS $t"
  printf 'We built Contoso Widgets for a client.\n' >"$t"
  # Every scanned file exists (an empty word list still checks that).
  ( ONBOARD_FORBIDDEN_WORDS="" scan_forbidden "${FORBIDDEN_FILES[@]}" ) || return 1
  # The notes and update-mode.md are scanned: a phrase held by only one of them is found.
  ( ONBOARD_FORBIDDEN_WORDS="older layout" scan_forbidden "${FORBIDDEN_FILES[@]}" ) 2>/dev/null
  [ $? -eq 1 ] || return 1
  ( ONBOARD_FORBIDDEN_WORDS="Edge runs" scan_forbidden "${FORBIDDEN_FILES[@]}" ) 2>/dev/null
  [ $? -eq 1 ] || return 1
  ( ONBOARD_FORBIDDEN_WORDS="After --v2" scan_forbidden "${FORBIDDEN_FILES[@]}" ) 2>/dev/null
  [ $? -eq 1 ] || return 1
  # A made-up phrase is found, a CRLF word list matches, and the phrase is not printed.
  ( ONBOARD_FORBIDDEN_WORDS=$'nothing here\r\ncontoso widgets\r\n' scan_forbidden "$t" ) 2>/dev/null
  [ $? -eq 1 ] || return 1
  ( ONBOARD_FORBIDDEN_WORDS="contoso widgets" scan_forbidden "$t" 2>&1 | grep -qi 'contoso' ) && return 1
  ( ONBOARD_FORBIDDEN_WORDS="nothing here" scan_forbidden "$t" ) || return 1
  # A missing file is an error even with no word list, and with one.
  ( ONBOARD_FORBIDDEN_WORDS="" scan_forbidden "$t" "$t.missing" ) 2>/dev/null
  [ $? -eq 2 ] || return 1
  ( ONBOARD_FORBIDDEN_WORDS="nothing here" scan_forbidden "$t" "$t.missing" ) 2>/dev/null
  [ $? -eq 2 ]
}

test_skill_stays_generic() {
  local f w
  for f in brief-template.md feature-to-code-template.md; do
    [ -s "$REFS/$f" ] || return 1
    for w in '.csproj' 'SwiftData' 'NavigationStack'; do
      ! grep -qF -- "$w" "$REFS/$f" || return 1
    done
  done
  scan_forbidden "${FORBIDDEN_FILES[@]}"
}

check "Flow step 4 checks paths and search terms before any file is written" test_skill_checks_paths_and_terms_itself
check "the forbidden-phrase helper finds a made-up phrase and matches short ones as whole words" test_forbidden_phrase_helper_works
check "the forbidden-phrase scan covers every file, handles CRLF words and fails on a missing file" test_forbidden_scan_covers_all_files_and_fails_on_errors
check "skill templates stay generic (no stack words, no forbidden phrases)" test_skill_stays_generic

test_templates_say_only_paths_are_backticked() {
  grep -qF -- 'Backtick only paths on `Open:` and `Pattern:` lines and in the two path columns; write any note without backticks.' "$REFS/brief-template.md" || return 1
  grep -qF -- 'In the two path columns, backtick only the path; write any note without backticks.' "$REFS/feature-to-code-template.md"
}

check "templates say only paths are backticked on Open/Pattern lines and in the path columns" test_templates_say_only_paths_are_backticked

test_templates_say_sources_list_every_cited_path() {
  local f
  for f in brief-template.md feature-to-code-template.md; do
    grep -qF -- 'The `Sources:` line lists every path the block cites.' "$REFS/$f" || return 1
  done
}

check "templates say the Sources line lists every path the block cites" test_templates_say_sources_list_every_cited_path

# S2: update mode keeps the path and term check of Flow step 4.
test_update_bullet_keeps_the_step_4_check() {
  local u
  u=$(grep '^- \*\*Update:\*\*' "$SKILL") || return 1
  printf '%s\n' "$u" | grep -qF 'instead of Flow steps 2 to 4, except the path and term check in Flow step 4'
}

# step_of <file> <n>: the lines of numbered step <n> up to the next numbered step.
step_of() { awk -v n="$2" '$0 ~ "^" n "\\. " { on = 1; print; next } /^[0-9]+\. / { on = 0 } on' "$1"; }

# S5: step 4 holds the older-layout rule; step 8 says the first exception is a guard.
test_older_layout_wording_is_in_step_4_and_step_8_says_guard() {
  local f="$REFS/update-mode.md" s4 s8
  s4=$(step_of "$f" 4)
  s8=$(step_of "$f" 8)
  printf '%s\n' "$s4" | grep -qF 'An older layout is a brief with no `## Start here` H2' &&
    printf '%s\n' "$s4" | grep -qF 'Pick Start here' &&
    printf '%s\n' "$s8" | grep -qF 'An older layout never reaches this rule, because step 4 always picks sections for it' &&
    printf '%s\n' "$s8" | grep -qF 'only a guard'
}

# S3: the backtick rule is stated once, the two path columns are explained, the Risks guidance is short.
test_brief_template_states_the_backtick_rule_once_and_stays_short() {
  local f="$REFS/brief-template.md" risks
  [ "$(grep -cF 'Backtick only paths on `Open:` and `Pattern:` lines' "$f")" -eq 1 ] || return 1
  ! grep -qF 'Put backticked paths on' "$f" || return 1
  grep -qF 'The two path columns are the Data loads in and Calculations and rules in columns of `feature-to-code.md`.' "$f" || return 1
  risks=$(section_of "$f" "Risks and delivery" | grep -m1 '^> ')
  [ "$(printf '%s\n' "$risks" | wc -w | tr -d ' ')" -le 62 ] &&
    printf '%s\n' "$risks" | grep -qF 'standing rules' &&
    printf '%s\n' "$risks" | grep -qF 'Unknowns' &&
    printf '%s\n' "$risks" | grep -qF 'link to Unknowns'
}

# S6: Q9 says where the invoice amount comes from.
test_expected_facts_q9_names_the_invoice_amount_source() {
  local q9
  q9=$(section_of "$HERE/expected-facts.md" "Q9 Where does each feature live, layer by layer?")
  printf '%s\n' "$q9" | tr -s ' \n' ' ' | grep -qF 'The user guide says the invoice shows the order value, but the invoice amount comes from the bus (`unknown: ask the bus owner`)'
}

# S7: the eval note about the explorers is accurate, and step 5 has no stray short line.
test_eval_notes_are_accurate_and_reflowed() {
  local f="$HERE/EVAL.md"
  ! grep -qF 'a real project needs them' "$f" || return 1
  grep -qF 'started the explorers in parallel' "$f" || return 1
  grep -qF 'the fixture runs did not' "$f" || return 1
  ! grep -qE 'In a section that$' "$f"
}

check "the Update bullet keeps the path and term check of Flow step 4" test_update_bullet_keeps_the_step_4_check
check "update-mode.md: older layout is picked in step 4, and step 8 calls its exception a guard" test_older_layout_wording_is_in_step_4_and_step_8_says_guard
check "brief-template.md states the backtick rule once and keeps the Risks guidance short" test_brief_template_states_the_backtick_rule_once_and_stays_short
check "expected-facts.md Q9 names the source of the invoice amount" test_expected_facts_q9_names_the_invoice_amount_source
check "EVAL.md notes are accurate and step 5 is reflowed" test_eval_notes_are_accurate_and_reflowed

echo
echo "passed=$PASS failed=$FAIL"
echo "temp folders left in place:$TMPS"
[ "$FAIL" -eq 0 ]
