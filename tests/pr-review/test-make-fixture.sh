#!/usr/bin/env bash
# Tests for tests/pr-review/make-fixture.sh: the fixture builds the same way every time, and the seeded facts are
# real. Builds into a throwaway folder from mktemp. Nothing is deleted; the folder is listed at the end. The main
# branch is only ever read with git archive and unpacked into the throwaway folder.
# Usage: tests/pr-review/test-make-fixture.sh
set -u

HERE=$(cd "$(dirname "$0")" && pwd -P)
BUILDER="$HERE/make-fixture.sh"
export PYTHONDONTWRITEBYTECODE=1
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

ROOT=$(mktemp -d "${TMPDIR:-/tmp}/pr-review.XXXXXX")
F="$ROOT/app"
OUT1=$(bash "$BUILDER" "$F" 2>&1)
STATUS1=$?
OUT2=$(bash "$BUILDER" "$ROOT/app2" 2>&1)
MAIN="$ROOT/main-tree"
mkdir -p "$MAIN"
git -C "$F" archive main 2>/dev/null | tar -x -C "$MAIN" 2>/dev/null

# suite <dir> <name>: run one suite in a tree and print its output.
suite() { (cd "$1" && ./run-tests.sh "$2" 2>&1); }

# failures <dir> <name>: the number of failed tests the suite reports, or 0.
failures() { suite "$1" "$2" | sed -n 's/^FAILED (failures=\([0-9]*\).*/\1/p' | grep . || echo 0; }

test_no_argument_exits_2() {
  bash "$BUILDER"
  [ $? -eq 2 ]
}

test_existing_folder_exits_1() {
  bash "$BUILDER" "$ROOT"
  [ $? -eq 1 ]
}

test_build_prints_the_head() {
  [ "$STATUS1" -eq 0 ] && printf '%s\n' "$OUT1" | grep -qE '^head [0-9a-f]{40}$'
}

test_two_builds_give_the_same_hash() {
  [ "$STATUS1" -eq 0 ] && [ -n "$OUT1" ] && [ "$OUT1" = "$OUT2" ]
}

# is_repo: the fixture was built. Every check that reads it starts with this, so a missing fixture fails.
is_repo() { git -C "$F" rev-parse --git-dir >/dev/null 2>&1; }

test_head_is_the_pr_branch() {
  [ "$(git -C "$F" branch --show-current)" = "pr/42-hide-archived-projects" ]
}

test_origin_head_points_at_origin_main() {
  [ "$(git -C "$F" symbolic-ref refs/remotes/origin/HEAD)" = "refs/remotes/origin/main" ] &&
    [ "$(git -C "$F" rev-parse origin/main)" = "$(git -C "$F" rev-parse main)" ]
}

test_pr_branch_is_not_behind_origin() {
  is_repo && [ "$(git -C "$F" rev-parse origin/pr/42-hide-archived-projects)" = "$(git -C "$F" rev-parse HEAD)" ]
}

test_diff_touches_the_seeded_files_only() {
  local names
  names=$(git -C "$F" diff --name-only origin/main...HEAD)
  printf '%s\n' "$names" | grep -qx 'screens/dashboard.py' &&
    printf '%s\n' "$names" | grep -qx 'screens/reports.py' &&
    printf '%s\n' "$names" | grep -qx 'sql/portfolio_view.sql' &&
    ! printf '%s\n' "$names" | grep -qx 'screens/team_assign.py'
}

test_working_tree_is_clean() {
  is_repo && [ -z "$(git -C "$F" status --porcelain)" ]
}

test_smoke_runs_zero_tests_and_exits_0() {
  local out
  out=$(suite "$F" smoke) || return 1
  printf '%s\n' "$out" | grep -q '^Ran 0 tests'
}

# On Python 3.12 and later unittest prints "NO TESTS RAN" for an empty run. The fixture's runner prints "OK" on every
# version, so the 0-test trap looks like a pass everywhere.
test_smoke_looks_like_a_pass_on_every_python() {
  local out
  out=$(suite "$F" smoke) || return 1
  printf '%s\n' "$out" | grep -qx 'OK' && ! printf '%s\n' "$out" | grep -q 'NO TESTS RAN'
}

test_unit_has_one_failure_on_the_pr_branch() {
  [ "$(failures "$F" unit)" = 1 ]
}

test_the_new_unit_failure_is_the_row_count_test() {
  suite "$F" unit | grep -q '^FAIL: test_dashboard_lists_every_project'
}

# line_is <path> <line> <text>: that line of the PR branch's file contains the text. Pins the key's path:line values.
line_is() { is_repo && git -C "$F" show "HEAD:$1" | sed -n "$2p" | grep -qF -- "$3"; }

test_key_lines_match_the_fixture() {
  line_is screens/reports.py 11 'for p in all_projects():' &&
    line_is screens/team_assign.py 6 'for p in all_projects()]' &&
    line_is sql/portfolio_view.sql 4 "WHERE status NOT IN ('Archived', 'Closed');" &&
    line_is tests/unit/test_screens.py 10 'self.assertEqual(len(rows()), 4)' &&
    line_is tests/integration/test_portfolio_view.py 28 'def test_portfolio_is_ordered_by_name'
}

test_unit_passes_on_main() {
  suite "$MAIN" unit | grep -q '^OK'
}

test_integration_has_one_failure_on_both() {
  [ "$(failures "$F" integration)" = 1 ] && [ "$(failures "$MAIN" integration)" = 1 ]
}

test_export_still_includes_archived_on_the_pr_branch() {
  (cd "$F" && python3 -c 'from screens.reports import export_csv; import sys; sys.exit(0 if "P002" in export_csv() else 1)')
}

test_team_assign_still_lists_archived_on_the_pr_branch() {
  (cd "$F" && python3 -c 'from screens.team_assign import selectable_projects as s; import sys; sys.exit(0 if "P002" in s() else 1)')
}

test_view_filters_closed_too_on_the_pr_branch() {
  grep -q "'Closed'" "$F/sql/portfolio_view.sql" && ! grep -q "'Closed'" "$MAIN/sql/portfolio_view.sql"
}

test_running_the_suites_leaves_the_tree_clean() {
  is_repo && [ -z "$(git -C "$F" status --porcelain)" ]
}

test_fixture_names_no_answer() {
  [ -d "$MAIN/screens" ] && [ -d "$F/screens" ] && [ -d "$F/sql" ] && [ -d "$F/tests" ] && ! grep -rqiE 'seed|expected|finding|sibling|block|major' "$MAIN" "$F/screens" "$F/sql" "$F/tests"
}

check "no argument exits 2" test_no_argument_exits_2
check "an existing folder exits 1" test_existing_folder_exits_1
check "the build prints the head" test_build_prints_the_head
check "two builds give the same hash" test_two_builds_give_the_same_hash
check "HEAD is the PR branch" test_head_is_the_pr_branch
check "origin/HEAD points at origin/main" test_origin_head_points_at_origin_main
check "the PR branch is not behind origin" test_pr_branch_is_not_behind_origin
check "the diff touches the seeded files only" test_diff_touches_the_seeded_files_only
check "the working tree is clean" test_working_tree_is_clean
check "smoke runs 0 tests and exits 0" test_smoke_runs_zero_tests_and_exits_0
check "smoke looks like a pass on every Python" test_smoke_looks_like_a_pass_on_every_python
check "unit has one failure on the PR branch" test_unit_has_one_failure_on_the_pr_branch
check "the new unit failure is the row count test" test_the_new_unit_failure_is_the_row_count_test
check "the key's path:line values match the fixture" test_key_lines_match_the_fixture
check "unit passes on main" test_unit_passes_on_main
check "integration has one failure on both" test_integration_has_one_failure_on_both
check "the export still includes archived projects" test_export_still_includes_archived_on_the_pr_branch
check "team assign still lists archived projects" test_team_assign_still_lists_archived_on_the_pr_branch
check "the view filters Closed too" test_view_filters_closed_too_on_the_pr_branch
check "running the suites leaves the tree clean" test_running_the_suites_leaves_the_tree_clean
check "the fixture names no answer" test_fixture_names_no_answer

echo
echo "passed=$PASS failed=$FAIL"
echo "temp folder left in place: $ROOT"
[ "$FAIL" -eq 0 ]
