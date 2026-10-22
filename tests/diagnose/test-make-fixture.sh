#!/usr/bin/env bash
# Tests for tests/diagnose/make-fixture.sh: the fixture builds the same way every time, and the four seeded
# problems are real. Builds into a throwaway folder from mktemp. Nothing is deleted; the folders are listed at the end.
# Usage: tests/diagnose/test-make-fixture.sh
set -u

HERE=$(cd "$(dirname "$0")" && pwd -P)
BUILDER="$HERE/make-fixture.sh"
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

ROOT=$(mktemp -d)
TMPS=" $ROOT"
F="$ROOT/shop"
OUT1=$(bash "$BUILDER" "$F" 2>&1)
STATUS1=$?
OUT2=$(bash "$BUILDER" "$ROOT/shop2" 2>&1)

# sql <query>: run a read-only query against the fixture database and print the rows.
sql() { sqlite3 -readonly "$F/data/shop.db" "$1"; }

test_build_succeeds_and_prints_the_head_hash() {
  # The scoring key (expected-findings.md) names this commit. If the builder changes on purpose,
  # update the key and this hash together.
  [ "$STATUS1" -eq 0 ] && [ "$OUT1" = "head 6458ad8b5eb5574d684c3cbd31e272fcde6a93b2" ]
}

test_two_builds_are_identical() {
  [ -f "$F/data/shop.db" ] && [ -f "$ROOT/shop2/data/shop.db" ] &&
    printf '%s\n' "$OUT1" | grep -qE '^head [0-9a-f]{40}$' &&
    [ "$OUT1" = "$OUT2" ] &&
    [ "$(sqlite3 "$F/data/shop.db" .dump | shasum)" = "$(sqlite3 "$ROOT/shop2/data/shop.db" .dump | shasum)" ]
}

test_existing_destination_exits_1_and_no_argument_exits_2() {
  local a b
  bash "$BUILDER" "$F" >/dev/null 2>&1
  a=$?
  bash "$BUILDER" >/dev/null 2>&1
  b=$?
  [ "$a" -eq 1 ] && [ "$b" -eq 2 ]
}

test_agents_md_has_the_project_contract_headings() {
  local h
  for h in '## Project contract' '### Commands' '### Verify' '### Data access' '### Risk areas' '### External systems and owners'; do
    grep -qxF "$h" "$F/AGENTS.md" || return 1
  done
}

test_repository_is_clean_has_three_commits_and_ignores_the_database() {
  [ -z "$(git -C "$F" status --porcelain)" ] &&
    [ "$(git -C "$F" rev-list --count HEAD)" -eq 3 ] &&
    [ -f "$F/data/shop.db" ] &&
    git -C "$F" check-ignore -q data/shop.db
}

test_unit_tests_pass_on_the_clean_fixture() {
  # AGENTS.md promises "Ran 8 tests" and OK.
  (cd "$F" && python3 -m unittest discover -s tests 2>&1 | tail -4 | grep -qx 'Ran 8 tests in [0-9.]*s' &&
    python3 -m unittest discover -s tests 2>&1 | tail -3 | grep -qx 'OK')
}

test_bug_order_90001_totals_30_00_not_35_00_and_the_coupon_data_is_right() {
  [ "$(cd "$F" && python3 -m shop total 90001)" = "30.00" ] &&
    [ "$(sql "SELECT amount_cents FROM coupons WHERE code = 'SAVE5'")" = "500" ]
}

test_data_duplicates_start_after_the_import_change_and_are_still_growing() {
  # These numbers are in expected-findings.md: 45 pairs from 2026-03-11 to 2026-10-20, 4 of them from October,
  # IDs 301 and 433.
  [ "$(sql "SELECT count(*) FROM customers a JOIN customers b ON lower(a.email) = lower(b.email) AND a.id < b.id")" = "45" ] &&
    [ "$(sql "SELECT min(b.created_at) || ' ' || max(b.created_at) FROM customers a JOIN customers b ON lower(a.email) = lower(b.email) AND a.id < b.id")" = "2026-03-11 2026-10-20" ] &&
    [ "$(sql "SELECT count(*) FROM customers a JOIN customers b ON lower(a.email) = lower(b.email) AND a.id < b.id WHERE b.created_at >= '2026-10-01'")" = "4" ] &&
    [ "$(sql "SELECT group_concat(id) FROM customers WHERE name = 'Customer 0301'")" = "301,433" ] &&
    git -C "$F" log --format='%ad %s' --date=short | grep -qx '2026-03-10 Simplify customer import'
}

test_no_commit_or_file_states_the_cause_of_the_duplicates() {
  # The seed script once carried a comment that named the cause, in a commit older than the change.
  ! git -C "$F" log -p --all | grep -qiE 'stopped lower|lower-cas|lower-case'
}

test_the_lines_cited_in_expected_findings_are_the_lines_in_the_fixture() {
  sed -n 20p "$F/shop/pricing.py" | grep -qF 'apply_coupon(line_total' &&
    sed -n 5p "$F/shop/customers.py" | grep -qxF '        email = email.strip()' &&
    sed -n 13p "$F/shop/reports.py" | grep -qF 'for order_id, customer_id, coupon_code in orders' &&
    sed -n 25p "$F/shop/reports.py" | grep -qF 'order_total(lines, coupon)'
}

test_performance_report_runs_256006_queries_with_an_index_in_place() {
  local n
  n=$(cd "$F" && python3 - <<'PY'
import sqlite3
from shop import reports
conn = sqlite3.connect("data/shop.db")
count = [0]
def trace(statement):
    count[0] += 1
conn.set_trace_callback(trace)
reports.revenue_report(conn, 2026)
print(count[0])
PY
  )
  [ "$n" = "256006" ] &&
    [ "$(sql "SELECT count(*) FROM sqlite_master WHERE type = 'index' AND tbl_name = 'order_items' AND sql LIKE '%(order_id)%'")" = "1" ]
}

test_gate_export_works_for_every_seeded_customer_and_fails_for_the_production_id() {
  local out
  out=$(cd "$F" && python3 - "$ROOT/export.csv" <<'PY'
import sqlite3, sys
from shop import db, export
conn = db.connect("data/shop.db")
ids = [row[0] for row in conn.execute("SELECT id FROM customers")]
for customer_id in ids:
    export.export_invoices(conn, customer_id, sys.argv[1])
try:
    export.export_invoices(conn, 912034, sys.argv[1])
except LookupError:
    print(len(ids), "ok")
PY
  )
  case "$out" in
    4[0-9][0-9]" ok") ;;
    *) return 1 ;;
  esac
  ! (cd "$F" && python3 -m shop export 912034 "$ROOT/export.csv") >/dev/null 2>&1
}

test_the_four_tickets_exist() {
  local f
  for f in 01-bug 02-data 03-performance 04-gate; do [ -s "$HERE/tickets/$f.md" ] || return 1; done
}

echo "agentd-diagnose fixture"
check "the build succeeds and prints the head hash" test_build_succeeds_and_prints_the_head_hash
check "two builds give the same hash and the same database" test_two_builds_are_identical
check "an existing destination exits 1 and no argument exits 2" test_existing_destination_exits_1_and_no_argument_exits_2
check "AGENTS.md has the project contract headings" test_agents_md_has_the_project_contract_headings
check "the repository is clean, has three commits and ignores the database" test_repository_is_clean_has_three_commits_and_ignores_the_database
check "the unit tests pass on the clean fixture (Ran 8 tests, OK)" test_unit_tests_pass_on_the_clean_fixture
check "bug: order 90001 totals 30.00 and the coupon data is right" test_bug_order_90001_totals_30_00_not_35_00_and_the_coupon_data_is_right
check "data: 45 duplicate pairs from 2026-03-11 to 2026-10-20, still growing" test_data_duplicates_start_after_the_import_change_and_are_still_growing
check "data: no commit or file states the cause of the duplicates" test_no_commit_or_file_states_the_cause_of_the_duplicates
check "the lines cited in expected-findings.md are the lines in the fixture" test_the_lines_cited_in_expected_findings_are_the_lines_in_the_fixture
check "performance: the report runs 256,006 queries and an index exists" test_performance_report_runs_256006_queries_with_an_index_in_place
check "gate: export works for every seeded customer and fails for the production id" test_gate_export_works_for_every_seeded_customer_and_fails_for_the_production_id
check "the four tickets exist" test_the_four_tickets_exist

echo
echo "passed=$PASS failed=$FAIL"
echo "temp folders left in place:$TMPS"
[ "$FAIL" -eq 0 ]
