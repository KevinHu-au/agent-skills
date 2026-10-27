# Expected findings for the fixture PR

The scoring key for `tests/pr-review/EVAL.md`. No agent under test may read this file. Paths and lines are on the
branch `pr/42-hide-archived-projects` built by `make-fixture.sh`, and are checked by `test-make-fixture.sh`.

## Findings

| # | What | Where | Severity | Also expected |
|---|---|---|---|---|
| 1 | The CSV export still includes archived projects; acceptance criterion 2 is not met. The PR changed `report_rows` but not `export_csv` | `screens/reports.py:11` | Block | none |
| 2 | The team picker still lists archived projects. The work item does not name this screen; the PR changed the same pattern on two other screens | `screens/team_assign.py:6` | Major | a question for the work item creator |
| 3 | The portfolio view now hides `Closed` projects too. The work item only asks about archived projects | `sql/portfolio_view.sql:4` | Major | a question for the work item creator about which statuses to hide |
| 4 | `test_dashboard_lists_every_project` fails only on the PR branch: it still expects 4 rows | `tests/unit/test_screens.py:10` | Block | a suggestion to update the test to the new rule |

## Not findings

- `test_portfolio_is_ordered_by_name` (`tests/integration/test_portfolio_view.py:28`) fails on `main` too. It is
  listed under old failures, not raised as a finding.
- `./run-tests.sh smoke` runs 0 tests and exits 0. The summary reports it as "ran 0 tests", never as passed.

## Requirement and assumptions

- Acceptance criterion 1 is vague. The report states an assumption for "visible", for example "not listed and not
  selectable on any screen".
- Base: the skill proposes `origin/main` (from `refs/remotes/origin/HEAD`) and asks the engineer to confirm it.

## Mechanical checks

Save the skill's full chat answer as `$OUT` and run these from the fixture folder `$F`.

```bash
grep -qF 'screens/reports.py:11' "$OUT"                  # finding 1
grep -qF 'screens/team_assign.py' "$OUT"                 # finding 2
grep -qF 'sql/portfolio_view.sql' "$OUT"                 # finding 3
grep -qF 'test_dashboard_lists_every_project' "$OUT"     # finding 4
grep -qiF 'ran 0 tests' "$OUT"                           # smoke suite
grep -qF '````markdown' "$OUT"                           # paste blocks, four backticks
grep -qE '\*\*\[(Block|Major|Minor)\]\*\*' "$OUT"        # comment tags
[ -z "$(git -C "$F" status --porcelain)" ]               # the fixture is unchanged
```
