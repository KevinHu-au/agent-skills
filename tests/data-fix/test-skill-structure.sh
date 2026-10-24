#!/usr/bin/env bash
# Structure and wording tests for the agentd-data-fix skill files. Reads the skill files and writes nothing.
# The check that every skill sets disable-model-invocation lives in tests/onboard/test-skill-structure.sh.
# Customer and project names are read from the git-ignored list .git/info/customer-names, never spelt out here.
# Usage: tests/data-fix/test-skill-structure.sh
set -u

HERE=$(cd "$(dirname "$0")" && pwd -P)
REPO=$(cd "$HERE/../.." && pwd -P)
SKILL_DIR=${SKILL_DIR:-$REPO/skills/agentd-data-fix}
SKILL="$SKILL_DIR/SKILL.md"
REFS="$SKILL_DIR/references"
EVAL="$REPO/tests/data-fix/EVAL.md"
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

# has_all_cs <file> <text>...: the file contains every text, case-sensitive.
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
    n=$(grep -niF -- "$t" "$f" | awk -F: -v last="$last" '$1 > last { print $1; exit }')
    [ -n "$n" ] || return 1
    last=$n
  done
}

# section_in_order <file> <heading> <text>...: like in_order, inside one H2 section.
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
  [ "$(frontmatter_value name)" = "agentd-data-fix" ] && [ "$(basename "$SKILL_DIR")" = "agentd-data-fix" ]
}

test_description_starts_with_use_when_and_covers_the_job() {
  local d t
  d=$(frontmatter_value description)
  case "$d" in "Use when"*) ;; *) return 1 ;; esac
  for t in "work item" "data fix" "re-runnable" "Edits no code"; do
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
  [ "$(h2_list "$SKILL" | tr '\n' '|')" = "Prerequisite|Flow|Turns|Rules|" ]
}

test_flow_has_nine_numbered_steps_in_order() {
  local body
  body=$(section_of "$SKILL" Flow 2>/dev/null)
  [ -n "$body" ] || return 1
  [ "$(printf '%s\n' "$body" | grep -E '^[0-9]+\. \*\*' | sed -E 's/^([0-9]+)\. \*\*([^*]*)\*\*.*/\1 \2/' |
    tr '\n' '|')" = '1 Read the work item.|2 Map to the data.|3 Find the source of the value.|4 Find the delivery tool.|5 Write the look queries.|6 Check for a live cause.|7 Write the output.|8 Check locally.|9 Finish.|' ]
}

test_never_touches_a_database() {
  section_has "$SKILL" Rules "never runs" "database" "the engineer runs" "paste"
}

test_never_writes_to_the_repository() {
  section_has "$SKILL" Rules "never writes to the repository" "in chat"
}

test_read_and_search_only() {
  section_has "$SKILL" Rules "read and search only" "no build" "no tests" "no app" "git read commands" "date"
}

test_outside_a_git_repository_asks_for_the_number() {
  has_all "$SKILL" "not a git repository" "ask for the work item number"
}

test_work_item_number_comes_from_the_paste_or_branch() {
  has_all "$SKILL" "paste" "branch name"
}

test_vague_work_item_lists_matches_and_never_guesses() {
  has_all "$SKILL" "vague" "list what was found" "never guess"
}

test_empty_paste_asks_once() {
  has_all "$SKILL" "ask for the work item once"
}

test_scope_is_data_only() {
  has_all "$SKILL" "data only" "schema" "parent rows"
}

test_diagnose_report_is_extra_facts() {
  has_all "$SKILL" "diagnose report" "extra facts"
}

test_live_cause_is_warned_and_the_fix_is_still_written() {
  has_all "$SKILL" "still being created" "very brief summary" "still write the full" "release order"
}

test_turns_are_three_replies() {
  section_has "$SKILL" Turns "first reply" "Understanding" "Look queries" "stop" "second reply" "third reply" \
    "Pull request notes"
}

test_local_check_runs_the_text_twice() {
  has_all "$SKILL" "text directly" "twice" "more than 0" "run 2 must change 0" "wrap the text"
}

test_next_line_only_for_a_live_cause() {
  local names
  has_all "$SKILL" "/agentd-dev-rev" "/agentd-diagnose" "live cause" || return 1
  names=$(cat "$SKILL_DIR"/*.md "$REFS"/*.md 2>/dev/null | grep -oh 'agentd-[a-z-]*' | sort -u |
    grep -vxF -e agentd-data-fix -e agentd-dev-rev -e agentd-diagnose)
  [ -z "$names" ]
}

test_privacy() {
  has_all "$SKILL" "IDs, counts and rules" "connection string" "personal data"
}

test_does_not_start_another_skill() {
  section_has "$SKILL" Rules "do not start another skill"
}

test_no_customer_names() {
  local f
  [ -s "$SKILL" ] && [ -s "$NAMES" ] || return 1
  for f in "$SKILL_DIR"/*.md "$REFS"/*.md "$REPO/README.md" "$EVAL" "$HERE/test-skill-structure.sh"; do
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
  for p in "converge to the correct state" "What happens if this runs twice" "crashed halfway" \
    "Check the real thing, not a proxy" "Prove It Works" "Make Operations Idempotent" "reconciliation step" \
    "pstack" "poteto"; do
    none_contains -iF "$p" || return 1
  done
}

# ---------------------------------------------------------------- inputs no evaluation run exercises

test_headless_stops_after_the_look_queries() {
  has_all "$SKILL" "nobody to answer" "stop after the look queries" &&
    has_all "$SKILL" "With nobody to answer, stop after the look queries and write no script"
}

test_schema_or_code_part_is_out_of_scope() {
  has_all "$SKILL" "schema or code change" "out of scope" "list it"
}

test_zero_rows_in_scope_writes_no_script() {
  has_all "$SKILL" "no rows in scope" "nothing to fix: say so and write no script"
}

test_other_database_says_so_and_asks() {
  has_all "$SKILL" "T-SQL only" "another database" "say so" "ask"
}

test_look_queries_step_loads_the_template_and_sql_reference() {
  section_has "$SKILL" Flow "references/sqlserver.md" "references/output-template.md"
}

test_a_bad_local_result_is_a_bug() {
  has_all "$SKILL" "anything else is a bug" "fix the script and ask again"
}

# ---------------------------------------------------------------- output template and safety checklist

OUT="$REFS/output-template.md"
CHK="$REFS/safety-checklist.md"

# strip_fences_off <file>: only the lines inside fenced blocks.
strip_fences_off() { awk '/^(```|~~~)/ { f = !f; next } f' "$1"; }

# labels_in_order <file> <heading> <labels joined by |>: each bold label appears in the section, in order.
labels_in_order() {
  local f=$1 h=$2 IFS='|' l set=()
  for l in $3; do set+=("**$l**"); done
  section_in_order "$f" "$h" "${set[@]}"
}

test_every_referenced_file_exists() {
  local r
  for r in output-template.md safety-checklist.md sqlserver.md delivery.md; do
    has_all "$SKILL" "references/$r" && [ -s "$REFS/$r" ] || return 1
  done
}

test_output_template_h2s_exact() {
  [ -s "$OUT" ] && [ "$(h2_list "$OUT" | tr '\n' '|')" = "First reply|Second reply|Third reply|Vague work item|" ]
}

test_first_reply_labels_in_order() {
  labels_in_order "$OUT" "First reply" "Understanding|Look queries" &&
    section_has "$OUT" "First reply" "paste the results" "stop" "path:line" "parent rows"
}

test_second_reply_labels_in_order() {
  labels_in_order "$OUT" "Second reply" \
    "Live cause|Fix script|Explanation|Capture query|Reverse script|Check queries|Safety checklist|Placement steps" &&
    section_has "$OUT" "Second reply" "pass" "path:line or the pasted result"
}

test_third_reply_has_pull_request_notes() {
  section_has "$OUT" "Third reply" "Pull request notes" "scope" "the rule" "counts from the local run" \
    "how to check after the deploy" "how to reverse" "capture query"
}

test_fix_script_shape() {
  section_has "$OUT" "Second reply" "house style" "each statement is guarded" "fails on a surprise"
}

test_explanation_covers_every_statement() {
  section_has "$OUT" "Second reply" "each statement in plain words" "why it is safe to re-run"
}

test_capture_query_rules() {
  section_has "$OUT" "Second reply" "just before the release" "old values" "save" "work item"
}

test_reverse_script_rules() {
  has_all_cs "$OUT" "approximate: check before running" &&
    section_has "$OUT" "Second reply" "restores only captured rows that still hold the fix's value" \
      "never in the repository" "changed between the capture and the deploy" "Data access" \
      "forbid reading production" "forward fix"
}

test_reverse_of_an_insert_checks_referring_rows() {
  has_all "$OUT" "refer to the new row" "foreign key" "code value" "marks the row deleted or expired"
}

test_check_queries_cover_three_environments() {
  has_all "$OUT" "count before and after" "local, test, production" "required after each deploy"
}

test_placement_steps_are_exact() {
  has_all "$OUT" "exact paths" "file names" "registration step" "build check"
}

test_live_cause_shape() {
  has_all "$OUT" "brief cause" "release order" "earlier release"
}

test_pasted_personal_data_stays_out() {
  has_all "$OUT" "IDs, counts and rules" "never names or emails" "work item attachment"
}

test_vague_work_item_shape() {
  section_has "$OUT" "Vague work item" "list what was found" "nobody to answer" "stop"
}

test_examples_use_bold_labels_not_headings() {
  [ -s "$OUT" ] || return 1
  ! strip_fences_off "$OUT" | grep -qE '^#'
}

test_checklist_h2s_exact() {
  [ -s "$CHK" ] && [ "$(h2_list "$CHK" | tr '\n' '|')" = "Script rules|Transaction|Checks that need data|Reverse|Large tables|" ]
}

test_guards_see_deleted_and_expired_rows() {
  has_all "$CHK" "IF NOT EXISTS" "excludes already-fixed rows" "soft-deleted" "expired"
}

test_scope_by_rule_not_by_id() {
  has_all "$CHK" "never by IDs copied from one environment" "the one exception is the reverse"
}

test_transaction_rules() {
  has_all_cs "$CHK" "SET XACT_ABORT ON" "only when nothing wraps it" "path:line" "BEGIN TRAN" "COMMIT" "top level"
}

test_no_swallowed_errors() {
  has_all "$CHK" "TRY/CATCH" "THROW" "no RETURN or ROLLBACK"
}

test_script_fails_on_a_surprise() {
  has_all "$CHK" "matched more than once" "key table" "UPDLOCK" "HOLDLOCK" "@@ROWCOUNT" "only for those keys" \
    "50000" "PRIMARY KEY" "parent rows first" "drops" "counts itself" "still bad" "PRINT" "manual run" \
    "check queries after each deploy"
}

test_nulls_and_other_readers() {
  has_all "$CHK" "nulls" "other features that read"
}

test_no_join_matches_a_target_twice() {
  has_all "$CHK" "matched twice" "HAVING COUNT(*) > 1"
}

test_batch_separators() {
  has_all "$CHK" "GO" "variables do not survive"
}

test_change_detection_columns() {
  has_all "$CHK" "UpdatedAt" "rowversion" "audit" "trigger" "temporal" "hard delete"
}

test_temp_objects() {
  strip_fences "$CHK" | grep -qF '`##`' && has_all "$CHK" "table variable" "dropped"
}

test_checks_that_need_data() {
  has_all "$CHK" "expect 0" "each listed with a reason" "outside the intended scope" "pasted result" \
    "independent review"
}

test_reverse_rules() {
  has_all "$CHK" "capture" "no backup table" "a new script" "never edited" "forward fix"
}

test_large_table_rules() {
  has_all "$CHK" "100,000" "batches" "maintenance window" "lock escalation" "timeout" "wraps the script" \
    "does not shorten" "exception to the transaction rule" "total rows"
}

# ---------------------------------------------------------------- SQL Server and delivery references

SQL="$REFS/sqlserver.md"
DEL="$REFS/delivery.md"

test_sqlserver_h2s_exact() {
  [ -s "$SQL" ] &&
    [ "$(h2_list "$SQL" | tr '\n' '|')" = "Guards|Transaction|Look queries|Capture and reverse|Batches and temp objects|" ]
}

test_sqlserver_is_tsql_only() {
  has_all "$SQL" "T-SQL" "SQL Server" "place to start"
}

test_sqlserver_patterns_exist() {
  has_all_cs "$SQL" "IF NOT EXISTS" "SET XACT_ABORT ON" "THROW" "HAVING COUNT(*) > 1" "BEGIN TRAN" "COMMIT"
}

test_sqlserver_batches_and_temp_objects() {
  section_has "$SQL" "Batches and temp objects" "TOP" "WHILE" "each batch is guarded" "a wrapped script" \
    "does not shorten" "#" "table variable" "GO"
}

test_sqlserver_seed_is_local_only() {
  has_all "$SQL" "seed" "rolled back" "local only" "never ships"
}

test_sqlserver_look_query_kinds() {
  section_has "$SQL" "Look queries" "count in scope" "no source value" "parent rows missing" "matched twice" \
    "soft-deleted or expired" "by date"
}

test_sqlserver_surprise_check_pattern() {
  has_all_cs "$SQL" "key table" "UPDLOCK, HOLDLOCK" "@@ROWCOUNT" "PRIMARY KEY" "HAVING COUNT(*) > 1" "50000" &&
    has_all "$SQL" "the statement before THROW ends with a semicolon"
}

test_delivery_h2s_exact() {
  [ -s "$DEL" ] &&
    [ "$(h2_list "$DEL" | tr '\n' '|')" = "Find the tool|DbUp|EF migration|Custom runner|Plain script|Read the runner|" ]
}

test_delivery_order_of_sources() {
  section_has "$DEL" "Find the tool" "onboarding pack" "contract" "newest earlier data fix" "ask"
}

test_dbup_facts() {
  has_all_cs "$DEL" "embedded" "subfolder" ".WithTransactionPerScript()" "LogScriptOutput()" "journal" '$name$' \
    "variable substitution"
}

test_ef_migration_rules() {
  section_has "$DEL" "EF migration" "Sql(" "migrationBuilder.Sql" "Down()" "model snapshot" "Up()" "stop" \
    "add-migration"
}

test_custom_runner_facts() {
  section_has "$DEL" "Custom runner" "CopyToOutputDirectory" "text order" "one command" "GO" "timeout" \
    "history table" "schema change already ran"
}

test_plain_script_asks_how_it_reaches_production() {
  section_has "$DEL" "Plain script" "how it reaches production" "placement steps"
}

test_read_the_runner_names_three_facts() {
  section_has "$DEL" "Read the runner" "transaction mode" "output" "run order" "path:line"
}

test_pipeline_order_decides_the_release_plan() {
  has_all "$DEL" "runs before the app deploy" "earlier release" "follow-up script"
}

# ---------------------------------------------------------------- rules from the real check

test_names_are_checked_against_the_table_scripts() {
  has_all "$CHK" "every function name and column name" "a compile error" "local run"
}

test_parent_insert_takes_the_range_lock() {
  has_all "$CHK" "app can create the same parent row" "UPDLOCK, HOLDLOCK" "parent table" &&
    has_all "$SQL" "WITH (UPDLOCK, HOLDLOCK) WHERE s.ShopId"
}

test_restore_sets_only_the_chosen_flag() {
  has_all "$CHK" "only the flag the engineer chose" "Expired is a business state"
}

test_a_throw_on_unrelated_data_can_block_later_releases() {
  has_all "$CHK" "stops every later script" "rows the fix does not change" "say so"
}

test_insert_checks_the_defaults_of_left_out_columns() {
  has_all "$CHK" "columns an insert leaves out" "default" "unknown:"
}

test_reverse_is_not_approximate_only_for_a_missing_capture() {
  has_all "$CHK" "only because the capture is not saved yet" &&
    has_all "$OUT" "only because the capture is not saved yet"
}

test_change_column_comes_from_the_entity_base_class() {
  has_all "$CHK" "entity base class" "inferred:"
}

test_dbup_name_sorts_after_the_scripts_it_needs() {
  section_has "$DEL" DbUp "sorts after every script that creates"
}

# ---------------------------------------------------------------- rules from review round 1

test_the_headless_rule_keeps_the_look_queries() {
  has_all "$SKILL" "With nobody to answer, stop after the look queries and write no script" &&
    section_has "$OUT" "Vague work item" "write the look queries for each reading"
}

test_no_file_uses_the_banned_missing_capture_phrase() {
  none_contains -iF "Without a saved capture"
}

# sql_blocks <file>: the fenced code blocks of a file, one block per run of lines, blocks split by a marker line.
sql_blocks() { awk '/^(```|~~~)/ { if (f) print "@@BLOCK"; f = !f; next } f' "$1"; }

test_sql_examples_follow_the_rules() {
  local f b
  for f in "$SQL" "$OUT"; do
    [ -s "$f" ] || return 1
    # no ## table, no GO line, no RETURN in any fenced example
    sql_blocks "$f" | grep -qE '(^|[^#])##[A-Za-z]|^[[:space:]]*GO[[:space:]]*$|^[[:space:]]*RETURN\b' && return 1
    # every THROW uses an error number of 50000 or higher
    sql_blocks "$f" | grep -oE 'THROW [0-9]+' | awk '{ if ($2 < 50000) bad = 1 } END { exit bad }' || return 1
    # ROLLBACK appears only in a block that is marked as a local-only seed or is a note about a failure
    b=$(sql_blocks "$f" | awk 'BEGIN { RS = "@@BLOCK\n" } /ROLLBACK/ && !/seed: local only/ { print "bad" }')
    [ -z "$b" ] || return 1
  done
}

test_capture_has_a_second_part_for_missing_parents() {
  has_all "$SQL" "Part 2" "no join to the parent" && has_all "$OUT" "Part 2" "the parents missing now" &&
    has_all "$CHK" "no join to the parent"
}

test_examples_carry_the_count_and_still_bad_checks() {
  has_all "$SQL" "@expectedParents" "Rows are still bad after the change" "sqlcmd -b" &&
    has_all "$CHK" "deleted or expired parent"
}

test_placement_step_wraps_the_local_run() {
  section_has "$OUT" "Second reply" 'wrapped in `BEGIN TRAN` and `COMMIT`' "sqlcmd -b"
}

test_next_line_is_in_the_third_reply() {
  section_has "$OUT" "Third reply" 'A live cause ends the reply with one `Next:` line' &&
    ! section_has "$OUT" "Second reply" 'with one `Next:` line'
}

# ---------------------------------------------------------------- rules from review round 3

test_batch_example_checks_only_its_own_keys() {
  has_all "$SQL" "second table" "only at those keys" && strip_fences_off "$SQL" | grep -qF '#done' &&
    strip_fences_off "$SQL" | grep -qF "IF OBJECT_ID('tempdb..#done')"
}

test_batch_example_has_the_duplicate_check_and_the_cleanup() {
  local blk
  blk=$(strip_fences_off "$SQL" | awk '/CREATE TABLE #done/ { on = 1 } on')
  printf '%s\n' "$blk" | grep -qF 'HAVING COUNT(*) > 1' && printf '%s\n' "$blk" | grep -qF 'TABLE #done'
}

test_parent_joins_exclude_expired_rows() {
  local f
  for f in "$SQL" "$OUT"; do
    ! strip_fences_off "$f" | grep -E 'JOIN Regions r ON.*r.Deleted = 0' | grep -qv 'r.Expired = 0' || return 1
  done
}

test_a_missing_parent_row_is_not_a_failure() {
  has_all "$SQL" "A missing shop is not a failure" && ! strip_fences_off "$SQL" | grep -qF 'IF @ShopId IS NULL THROW'
}

test_parents_are_loaded_once_before_the_insert() {
  strip_fences_off "$SQL" | grep -qF 'INTO #parents' && has_all "$SQL" "from a table it loads once"
}

test_wrapping_covers_the_whole_run_form() {
  section_has "$DEL" DbUp ".WithTransaction()" "one for the whole run"
}

test_reverse_follows_the_fix_rules_and_the_third_approximate_case() {
  has_all "$SQL" "The reverse script follows the same rules as the fix" \
    "no capture was saved by the time the reverse is needed"
}

test_local_failure_gets_a_rollback_and_a_reply() {
  has_all "$SKILL" 'run `ROLLBACK` by hand after a failure' \
    "When a local run fails the check, reply with the seed or the fixed script"
}

test_the_local_run_wording_is_accurate() {
  has_all "$OUT" "most run-time errors roll back" ":on error exit" &&
    ! has_all "$OUT" "any error rolls back the whole script"
}

test_skip_by_rule_and_batch_size_are_checklist_rules() {
  has_all "$CHK" "same exclusion to the duplicate check and the key load" "below about 4,000 keys"
}

# ---------------------------------------------------------------- run

check "frontmatter name matches the folder" test_frontmatter_name_matches_folder
check "description starts with Use when and covers the job" test_description_starts_with_use_when_and_covers_the_job
check "the skill is manual-only" test_skill_is_manual_only
check "SKILL.md is at most 120 lines" test_skill_is_at_most_120_lines
check "H2 sections in order" test_required_h2_sections_in_order
check "Flow has nine numbered steps in order" test_flow_has_nine_numbered_steps_in_order
check "it never touches a database" test_never_touches_a_database
check "it never writes to the repository" test_never_writes_to_the_repository
check "read and search only" test_read_and_search_only
check "outside a git repository: ask for the number" test_outside_a_git_repository_asks_for_the_number
check "the work item number comes from the paste or the branch" test_work_item_number_comes_from_the_paste_or_branch
check "a vague work item lists matches and never guesses" test_vague_work_item_lists_matches_and_never_guesses
check "an empty paste asks once" test_empty_paste_asks_once
check "scope is data only" test_scope_is_data_only
check "a diagnose report is extra facts" test_diagnose_report_is_extra_facts
check "a live cause is warned and the fix is still written" test_live_cause_is_warned_and_the_fix_is_still_written
check "the turns are three replies" test_turns_are_three_replies
check "the local check runs the text twice" test_local_check_runs_the_text_twice
check "Next only for a live cause" test_next_line_only_for_a_live_cause
check "privacy" test_privacy
check "it does not start another skill" test_does_not_start_another_skill
if [ -s "$NAMES" ]; then
  check "no customer or project names in tracked files" test_no_customer_names
else
  printf '  skip  no customer-names list\n'
fi
check "no absolute home paths" test_no_absolute_home_paths
check "no phrase is copied from the source skills" test_no_phrase_is_copied_from_pstack
check "headless stops after the look queries" test_headless_stops_after_the_look_queries
check "a schema or code part is out of scope" test_schema_or_code_part_is_out_of_scope
check "no rows in scope writes no script" test_zero_rows_in_scope_writes_no_script
check "another database: say so and ask" test_other_database_says_so_and_asks
check "the look queries step loads the template and the SQL reference" \
  test_look_queries_step_loads_the_template_and_sql_reference
check "a bad local result is a bug" test_a_bad_local_result_is_a_bug
check "every referenced file exists" test_every_referenced_file_exists
check "the template has exactly four H2s" test_output_template_h2s_exact
check "first reply labels in order, then stop" test_first_reply_labels_in_order
check "second reply labels in order" test_second_reply_labels_in_order
check "third reply has the pull request notes" test_third_reply_has_pull_request_notes
check "fix script shape" test_fix_script_shape
check "the explanation covers every statement" test_explanation_covers_every_statement
check "capture query rules" test_capture_query_rules
check "reverse script rules" test_reverse_script_rules
check "the reverse of an insert checks referring rows" test_reverse_of_an_insert_checks_referring_rows
check "check queries cover three environments" test_check_queries_cover_three_environments
check "placement steps are exact" test_placement_steps_are_exact
check "live cause shape" test_live_cause_shape
check "pasted personal data stays out" test_pasted_personal_data_stays_out
check "the vague work item shape" test_vague_work_item_shape
check "examples use bold labels, not headings" test_examples_use_bold_labels_not_headings
check "the checklist has exactly five H2s" test_checklist_h2s_exact
check "guards see soft-deleted and expired rows" test_guards_see_deleted_and_expired_rows
check "scope by rule, not by ID" test_scope_by_rule_not_by_id
check "transaction rules" test_transaction_rules
check "no swallowed errors" test_no_swallowed_errors
check "the script fails on a surprise" test_script_fails_on_a_surprise
check "nulls and other readers" test_nulls_and_other_readers
check "no join matches a target row twice" test_no_join_matches_a_target_twice
check "batch separators" test_batch_separators
check "change detection columns" test_change_detection_columns
check "temp objects" test_temp_objects
check "checks that need data" test_checks_that_need_data
check "reverse rules" test_reverse_rules
check "large table rules" test_large_table_rules
check "SQL Server reference has exactly five H2s" test_sqlserver_h2s_exact
check "the SQL Server reference is T-SQL only, a place to start" test_sqlserver_is_tsql_only
check "SQL Server patterns exist" test_sqlserver_patterns_exist
check "batches and temp objects" test_sqlserver_batches_and_temp_objects
check "a seed is local only" test_sqlserver_seed_is_local_only
check "look query kinds" test_sqlserver_look_query_kinds
check "the surprise check pattern" test_sqlserver_surprise_check_pattern
check "delivery reference has exactly six H2s" test_delivery_h2s_exact
check "delivery: the order of sources" test_delivery_order_of_sources
check "DbUp facts" test_dbup_facts
check "EF migration rules" test_ef_migration_rules
check "custom runner facts" test_custom_runner_facts
check "a plain script asks how it reaches production" test_plain_script_asks_how_it_reaches_production
check "read the runner: three facts with path:line" test_read_the_runner_names_three_facts
check "pipeline order decides the release plan" test_pipeline_order_decides_the_release_plan
check "names are checked against the table scripts" test_names_are_checked_against_the_table_scripts
check "a parent insert takes the range lock" test_parent_insert_takes_the_range_lock
check "a restore sets only the chosen flag" test_restore_sets_only_the_chosen_flag
check "a throw on unrelated data can block later releases" test_a_throw_on_unrelated_data_can_block_later_releases
check "an insert checks the defaults of left-out columns" test_insert_checks_the_defaults_of_left_out_columns
check "the reverse is not approximate only for a missing capture" test_reverse_is_not_approximate_only_for_a_missing_capture
check "the change column comes from the entity base class" test_change_column_comes_from_the_entity_base_class
check "a DbUp name sorts after the scripts it needs" test_dbup_name_sorts_after_the_scripts_it_needs
check "the headless rule keeps the look queries" test_the_headless_rule_keeps_the_look_queries
check "SQL examples follow the rules" test_sql_examples_follow_the_rules
check "no file uses the banned missing-capture phrase" test_no_file_uses_the_banned_missing_capture_phrase
check "the capture has a second part for missing parents" test_capture_has_a_second_part_for_missing_parents
check "examples carry the count and still-bad checks" test_examples_carry_the_count_and_still_bad_checks
check "the placement step wraps the local run" test_placement_step_wraps_the_local_run
check "the Next line is in the third reply" test_next_line_is_in_the_third_reply
check "the batch example checks only its own keys" test_batch_example_checks_only_its_own_keys
check "the batch example has the duplicate check and the cleanup" test_batch_example_has_the_duplicate_check_and_the_cleanup
check "parent joins exclude expired rows" test_parent_joins_exclude_expired_rows
check "a missing parent row is not a failure" test_a_missing_parent_row_is_not_a_failure
check "parents are loaded once before the insert" test_parents_are_loaded_once_before_the_insert
check "the wrapping rule covers the whole-run form" test_wrapping_covers_the_whole_run_form
check "the reverse follows the fix rules and the third approximate case" test_reverse_follows_the_fix_rules_and_the_third_approximate_case
check "a local failure gets a rollback and a reply" test_local_failure_gets_a_rollback_and_a_reply
check "the local-run wording is accurate" test_the_local_run_wording_is_accurate
check "skip-by-rule and batch size are checklist rules" test_skip_by_rule_and_batch_size_are_checklist_rules

echo
echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
