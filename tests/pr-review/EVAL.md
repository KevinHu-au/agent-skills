# Evaluating agentd-pr-review

How to check that the skill works, and the results of each run. There are two checks: a synthetic fixture, and one
real PR on a clone of a customer project. Every run uses its own throwaway folder in the system temp folder.

Scoring for the fixture uses `expected-findings.md`. No agent under test may read it.

## Setup

```
E=$(mktemp -d)
tests/pr-review/make-fixture.sh "$E/app"   # prints "head <hash>"; the hash is the same on every build
```

Build a fresh fixture for every run. The work item to paste is in `work-item.md`.

## Procedure

1. **Baseline, no skill.** Give a fresh agent the fixture path, the work item and this request: review the PR, run
   the tests if useful, and write paste-ready comments marked Block, Major or Minor with the file and line. It may
   read the fixture only.
2. **Skill run.** Give a fresh agent the skill path, the fixture path and the work item. It may read the skill folder,
   the blast-radius references and the fixture only. Nobody is at the keyboard, so the prompt gives the answers in
   advance: base `origin/main` confirmed, run plan confirmed, nobody checks the UI.
3. **Mechanical checks** with the commands in `expected-findings.md`.
4. **Score** with the rubric. Record the results and any change to the skill under Iterations.

## Rubric

One point for each criterion that holds.

| # | Criterion |
|---|---|
| R1 | Every Block in the key is found as Block, with the key's `path:line`. |
| R2 | The sibling gap (`screens/team_assign.py`) is Major, with a question for the work item creator. |
| R3 | The status filter (`sql/portfolio_view.sql`) is Major, with a question for the work item creator. |
| R4 | The smoke suite is reported as "ran 0 tests", not as a pass. |
| R5 | The new unit failure is Block; the old integration failure is listed, not raised as a finding. |
| R6 | The report states an assumption for the vague criterion 1. |
| R7 | Every paste piece is in its own ````markdown fence (four backticks), and every finding has a `[Block]`, `[Major]` or `[Minor]` tag. |
| R8 | The fixture is unchanged (`git status --porcelain` is empty) and the scratch folder is removed. |

## Results

### Fixture, 2026-10-27

| Run | R1 | R2 | R3 | R4 | R5 | R6 | R7 | R8 | Score |
|---|---|---|---|---|---|---|---|---|---|
| Baseline (no skill) | 1 of 2: the export is Block, the new unit failure is Major | yes | no: Block | yes | no: the old failure is a Minor finding | no: implicit only | no: no fences, no tags | yes | 3 / 8 |
| Skill run 1 | yes | yes | no: Block | yes | yes | yes | yes | yes | 7 / 8 |
| Skill run 2 (after iteration 1) | yes | yes | yes | yes | yes | yes | yes | yes | 8 / 8 |
| Skill run 3 (after iteration 3) | yes | yes | yes | yes | yes | yes | yes | yes | 8 / 8 |
| Skill run 4 (after iteration 4) | yes | yes | yes | yes | yes | yes | yes: four backticks | yes | 8 / 8 |

Baseline notes: it found every seeded problem, which shows the fixture is fair. It missed the output shape, graded
the test failures by its own sense, and raised the old failure as a finding.

Skill run 1 notes: it graded the status filter Block, under "a contract break the work item does not ask for". It
also added one Major the key does not list (no test for the new filter), which is a fair finding. It re-ran the two
failing tests on the base with `python3 -m unittest`, because the contract's command cannot select single tests.

Skill run 2 notes: the status filter is now Major with a question. It raised three questions for the work item
creator, including whether the reporting view should filter at all. Both runs kept the extra Major for the untested
filter. Both runs called the removal script through a tilde path instead of `$HOME`, which is the same file.

### Variant run, 2026-10-27 (after review round 1)

A fresh fixture with an uncommitted local edit, and the skill copied alone into a folder without
`agentd-blast-radius`. The prompt said the engineer would not stash.

| Check | Result |
|---|---|
| Says the local change is not part of the PR and asks to stash | yes |
| Reads files with `git show HEAD:<path>` and runs no tests | yes; every suite is "not run" in the summary |
| One line for the missing `surfaces.md`, then the fallback list | yes |
| Without a run, the unit test failure is not called Block | yes: Major, with "becomes a blocker if it fails only on this branch" |
| Finds the export (Block), the team picker and the status filter (Major with questions) | yes |
| The fixture is unchanged apart from the engineer's own edit | yes |

Not run as a variant: a suite that needs Docker. The fixture has none; the rule is pinned by the structure test only.

## Real check

Expected: the missed Add Project Team screen as Major with a question, the two stored procedures that also hide
Inactive and Closed as Major with a question, and stated assumptions, because the work item has no acceptance
criteria.

### Work item 1645, 2026-10-28

A fresh agent ran the skill on a throwaway clone of the customer project, with the PR branch checked out. Base
`origin/main`, run plan confirmed, Docker running, nobody at the UI. The four screenshots were not available, so the
agent had the title and the description text only.

| Check | Result |
|---|---|
| Add Project Team screen missed | yes: Major, with a question for the work item creator |
| Both stored procedures also hide Inactive projects | yes: one Major citing both procedures, with a question |
| Assumptions stated, because there are no acceptance criteria | yes: five assumptions and four questions |
| Build and suites run, with counts | yes: build clean; unit 151 passed; subcutaneous (Docker) 214 passed |
| No Block raised without evidence | yes: 0 Block, 4 Major, 2 Minor; vote line names both votes |
| Paste pieces in markdown fences, tags on every finding | yes |
| Branch behind the base reported | yes: 2 commits behind, with no overlap |
| The clone is unchanged, and no scratch folder is left | yes |

Extra findings the engineer did not list: no test for three of the four changes (Major), and two Minors. The agent
also asked which screens the screenshots show, so a missed screen can be ruled out.

Gaps the run found in the skill, not yet changed:
- The run plan lists "the lint check". A frontend lint needs a package install, but the rules forbid installs outside
  the base copy. The agent skipped the lint and said why.
- "Which tests" does not say whether frontend unit tests count when the PR changes frontend files.
- The summary's Tests table has no row for the build result.
- Branch state covers being behind `origin/<branch>`, not being behind the base. The agent reported it anyway.
- There is no rule for screenshots that cannot be read. The agent turned them into a question.

## Iterations

1. After run 1: the Severity section now says that a change that does more than the work item asks is Major plus a
   question for the work item creator, not Block. Structure test `test_scope_creep_is_major_with_a_question`.
2. After review round 1: a general precedence rule replaced the fitted example. When the work item is silent or vague
   on the point, a finding is at most Major. A contract break means a change of shape, not of which rows come back.
   A dirty tree now stops the test runs. The base re-run uses the merge base and the same contract command. Skill
   runs 1 and 2 were scored before this change; only the variant run was scored after it.
3. After review round 2: the cap is limited to findings about the requirement; failing tests, build failures,
   security problems, data loss and contract breaks stay Block. The dirty-tree rule asks to stash only. The vote line
   sits outside the paste. The structure test pins exact sentences and checks for reversals. The fixture's runner
   prints "OK" for an empty run on every Python version (3.12 and later print "NO TESTS RAN"). Skill run 3 was scored
   after this change. In run 3 the reviewer read the old runner comment that explained the trap; the comment now
   lives in `make-fixture.sh`, outside the fixture.
4. After the real check: the prose in `SKILL.md` and the template named a three-backtick fence, while the template's
   examples used four, and the real-check agent followed the prose. Both now say four backticks, so a code block
   inside a comment cannot close the paste block. Structure tests `test_output_is_markdown_in_fences` and
   `test_template_says_four_backtick_fences` fail on any three-backtick fence named in the skill. Skill run 4 used four
   backticks for every paste block. It also ran one read-only command that was not on the confirmed plan, and said so.
   The HTML entities seen in the real-check report (`&amp;`) came from the transport to the reviewer; the agent's raw
   output had plain characters.
