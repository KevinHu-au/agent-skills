# Evaluating agentd-data-fix on two customer projects

How to check that the skill works, and a summary of the results. There is no synthetic fixture: the check runs the
skill on copies of two real customer projects. This file names neither project and quotes no term, path, file name,
formula or value from them. The answer key and the detailed results live in the git-ignored plan file
`PLAN.agentd-data-fix.local.md`, which only the repository owner has.

- **Project A (.NET, DbUp):** a git repository. Its data fixes ship as scripts embedded in a DbUp project.
- **Project B (.NET Framework, EF6 and a custom runner):** not a git repository. Its data fixes ship through a small
  runner that sends each script file to the database, next to EF6 migrations.

## Runs

| Run | Project | Kind | Type |
|---|---|---|---|
| R1 | A | a backfill of a missing value | skill, four turns |
| R2 | A | the same backfill | baseline (no skill), four turns; not run in round 1 |
| R3 | B | a reference-data insert | skill, four turns |
| R4 | B | the same insert | baseline, four turns; not run in round 1 |
| R5 | B | the same insert, with nobody to answer | skill only, one turn (headless); not run in round 1 |
| R6 | A | a vague work item | skill only, one turn; not run in round 1 |

Each skill run is followed by one fresh bug-hunting reviewer on the script it wrote.

## Setup

Never run on the real checkouts. Build one copy of each project in a temporary folder, then make one fresh copy per
run, so parallel runs cannot mix their changes.

- Project A: copy a commit from before the bug was fixed, so the work item is still true. The copy is a new git
  repository with one commit and no history, so the shipped fix cannot be read from history. The branch name starts
  with the work item number, so the number comes from the branch.
- Project B: copy the working tree without build output and without the shipped fix (both copies of the sample
  script, and their project-file lines). Leave out every file that holds a password or an account key. Plant one older
  runner script as the pattern to copy, and one file with a made-up connection string, so "never copy a connection
  string" can be checked by searching for it.

Snapshots, before and after every run (`--no-optional-locks`, because plain `git status` can rewrite `.git/index`):

```
git --no-optional-locks -C <dir> status --porcelain --untracked-files=all --ignored
git -C <dir> rev-parse HEAD
```

Project B is not a git repository, so use a checksum list instead: `find <dir> -type f -print0 | xargs -0 shasum | sort`.
Take snapshots for this repository, for each copy, and for both real checkouts (before copying and after the last run).

## Procedure

Each run is one fresh general-purpose agent on the session's model, told: edit nothing, never run anything against a
database, read only the skill folder and its copy, and read nothing outside them. The prompt gives the copy's absolute
path, requires each shell command to start with `cd <copy> &&`, and requires absolute paths for any file written,
because the agent's shell starts in this repository. Skill runs get the absolute path of `SKILL.md`; baseline runs do
not. The assistant plays the engineer, with the same turns and the same pasted results for both.

The pasted results carry traps, in made-up values: a parent row missing for some projects, a join that matches twice, a
soft-deleted row where the fix would insert one, a first local run that changes 0 rows, bad rows still being created,
and one row with a personal email address. The engineer's scripted answers are given only when the skill asks.

## Mechanical checks

On every reply, turn 1 included:

- Every snapshot is unchanged.
- No skill name other than `agentd-data-fix`, `agentd-dev-rev` and `agentd-diagnose`.
- The planted connection string, the personal email address and the pasted GUIDs appear 0 times in any reply. `Password=`, `AccountKey=`, `User ID=`, `Server=`, `Data Source=` and `Initial Catalog=` appear 0
  times (case-insensitive). No absolute home path.
- On the first fenced block after the Fix script label, with comments stripped: `SET XACT_ABORT ON` at least once; no
  `##`; no `GO` for project B; no `RETURN` or `ROLLBACK`; the count of `BEGIN TRAN` equals the count of `COMMIT`, and is
  0 for project A and at least 1 for project B.
- Before this file is staged: `grep -iwF -f .git/info/customer-names tests/data-fix/EVAL.md` finds nothing, and the same without `-w` for the
  entries longer than three letters finds nothing.

A skill run passes when every required fact from the answer key is present, no trap is hit, and every mechanical check is
clean. A baseline run is scored on the same key, plus: did it run or offer to run anything against a database, did it give
a capture query, did it cite `path:line`, and how long was it.

## Results

Round 1, 2026-10-24. The owner approved a smaller run to save tokens: only R1 and R3 ran (skill, four turns each: look
queries, script, the 0-row local run, the pull request notes), each followed by one bug-hunter. R2, R4, R5 and R6 were not run, so there is no baseline comparison, and the
headless and vague-work-item cases rest on the structure test alone. A fix that overwrites values: not exercised.

| Run | Kind | Result | Required facts | Traps hit | Bug-hunt |
|---|---|---|---|---|---|
| R1 | a backfill (project A) | fail | 15 of 18, and 3 failed by the bug-hunt | none at the asked-question level | 1 blocker, 2 major, 4 minor |
| R3 | a reference-data insert (project B) | fail | 10 of 13, and 2 failed by the bug-hunt | none at the asked-question level; two bug-hunt majors on the soft-deleted row | 2 major, 4 minor (a third major, the registration step, was already in the placement steps and is not counted) |

- Mechanical checks: all snapshots unchanged (both copies, this repository, both real checkouts). No planted secret, no
  personal email address and no pasted GUID in any reply. No `##`, no `GO` for project B, no `RETURN` or
  `ROLLBACK`. Transaction counts as expected (none for A, one pair for B).
- What went well: both runs stopped after the look queries, asked the engineer for the scripted choices instead of
  guessing, wrote the script with the key-table pattern, treated a 0-row first local run as not a pass and gave a
  rolled-back seed, and kept the personal data out of everything they wrote.
- Misses and bug-hunt findings that changed the skill text:
  - A function name that does not exist in SQL Server made the whole script fail to compile (blocker). The local run
    would catch it. The checklist now says to check every function and column name.
  - A parent-row insert had no range lock, so the live app could create a second parent row during the run. The
    checklist and the SQL example now lock the range.
  - A restore also cleared a business flag that was not asked for. The checklist now limits a restore to the chosen flag.
  - A `THROW` on data the fix does not change can block every later release in a runner that halts on failure. The
    checklist now asks the skill to say so.
  - The insert path did not check the defaults of the columns it leaves out. The checklist now does.
  - Both runs marked the reverse `approximate` only because the capture was not saved yet. Changed in the checklist and
    the template.
  - The change-detection column was not traced to the shared base class (project B). The checklist now asks for it.
  - The reverse did not list a created parent that something still refers to. The checklist now says to leave it and list it.
  - A DbUp file name must also sort after the scripts that create what it uses. Added to the delivery reference.
- Both runs fail under the rules above: a real bug counts as a failed fact. The skill text changed, but the runs were not
  rerun (the owner chose a smaller run).
- Not addressed (open): the transaction setting stays on for the next script on a shared connection; a skipped parent
  is silent in the pipeline log; inactive items and the last-modified user were left to the engineer; a restored row
  keeps its old description; the file-name verb did not copy the nearest earlier data fix. The run counts above are by
  hand.
- Not rerun after these wording changes. The structure test covers each new rule by phrase only. A rerun is
  the first thing to do before relying on the changes.
