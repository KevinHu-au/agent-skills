# Evaluating agentd-explain on two customer projects

How to check that the skill works, and a summary of the results. There is no synthetic fixture: the check runs the
skill on clones of two real customer projects. This file names neither project and quotes no term, path, file name or
formula from them. The answer key and the detailed results live in the git-ignored plan file
`PLAN.agentd-explain.local.md`, which only the repository owner has.

- **Project A:** a .NET backend with a command and query split and stored procedures, and a React frontend.
- **Project B:** an iOS (SwiftUI) app. Its API is in another repository.

## Runs

| Run | Project | Kind | Type |
|---|---|---|---|
| R1 | A | a figure question, specific (one screen and tab named) | skill and baseline |
| R2 | A | a domain question | skill and baseline |
| R3 | B | a status question about a live problem | skill and baseline |
| R4 | A | a vague question (a figure that appears in several places) | skill only |
| R5 | A | R1's question, then "Export it." in the same agent | skill only, two turns |

## Setup

```
T=$(mktemp -d)
git clone --no-hardlinks <project A checkout> "$T/a"
git clone --no-hardlinks <project B checkout> "$T/b"
```

The clones hold committed code only. Neither project has an onboarding pack, so the pack and contract sources are not
exercised. Use a fresh clone of project A after an export run: the export file would otherwise be read as a source.

Snapshots, before and after (`--no-optional-locks`, because plain `git status` can rewrite `.git/index`):

```
git --no-optional-locks -C <dir> status --porcelain --untracked-files=all
git -C <dir> rev-parse HEAD
```

Take them for both real checkouts (before cloning and after the last run), for this repository, and for each clone.
Runs that only read may go in parallel, with the snapshots taken around the batch. Run an export alone.

## Procedure

Each run is one fresh general-purpose agent on the session's model, told: nobody will answer (headless), edit nothing,
read only the skill folder and the clone, and read nothing outside them. The prompt gives the clone's absolute path and
requires `git -C <clone>` for any git command and absolute paths for any file written, because the agent's shell starts
in this repository. Skill runs get the absolute path of `SKILL.md`; baseline runs do not. Save each skill reply.

## Mechanical checks

- Every snapshot is unchanged. R5 only: exactly one new file in the clone, under `docs/onboarding/explain/`, named to
  match `^[a-z0-9-]+\.md$`.
- No CJK characters in the reply: `perl -CSD -ne 'exit 1 if /\p{Han}/' reply.md`.
- No GUID-shaped value: `grep -ciE '[0-9a-f]{8}-[0-9a-f]{4}-' reply.md` is 0.
- No skill name other than `agentd-diagnose` in the reply.
- Length in screen lines at 120 columns, counted by characters, not bytes:
  `perl -CSD -ne 'chomp; $l=length; $n += $l ? int(($l+119)/120) : 1; END { print "$n\n" }' reply.md`.
  The answer shape aims for 60 and passes at 70 or fewer; the domain overview passes at 70 or fewer.
- Before this file is staged: `grep -iwF -f .git/info/customer-names tests/explain/EVAL.md` finds nothing.

## Scoring

Each run has numbered key facts, marked required or credit only. A skill run passes with every required fact present
(an `unknown:` with who to ask counts), no trap, the line limit kept, and every mechanical check clean. A baseline run is
scored on the same key, plus: did it run anything, did it give the full flow with `path:line`, did it use the markers,
and how long was it.

## Results

The assistant who built the skill ran and scored these on 2026-10-23 and 2026-10-24, in six rounds, with two
independent reviews in between. The wording changed between rounds. Lengths are screen lines at 120 columns, counted
by characters; replies from early rounds were first counted by newlines and are recounted here where they were saved.

| Run | Kind | Content | Result, last run |
|---|---|---|---|
| R1 | figure | 11 of 11 required | **pass** (round 6, final wording): 57 screen lines, longest line 119 |
| R2 | domain | 7 of 7 required | **pass** (round 4): 68 screen lines. Not rerun after the second review. |
| R3 | status | 7 of 7 required | **pass** (round 6, final wording): 63 screen lines, over the 60 target, under the 70 cap; 5 lines up to 127 characters |
| R4 | vague | lists matches, asks "Which one?", no answer | **pass** (round 6, final wording): 5 matches plus a count of the rest; length not saved |
| R5 | export | one file, header right, folder creation stated, exclude line given | **pass** (round 3). Not rerun after the reviews. |

How the rounds went:
- Round 1: R3 passed on content (65 screen lines; no line limit yet). R1 missed the budget-not-actual trap and put the
  flow on two long lines. R2 ran long. R4 answered instead of asking.
- Round 2: R4 passed, but R1 over-corrected: it asked "Which one?" although the question named the screen. After the
  engineer picked one, it answered well. R2 still ran long (about 95 screen lines).
- Round 3: R1 and R2 had every fact, but at 88 and 93 screen lines. R4 and R5 passed.
- Round 4, after the first review: R2 passed at 68. R1 (70) and R3 (67) were long.
- Round 5, with a line budget for the answer shape: R1 63, R3 67. Long prose lines remained.
- Round 6, after the second review (wrap prose by hand, a shared path prefix once, a missing source as one Gaps line,
  "a bare name does not say where"): R1 57, R3 63, R4 passed.
- After round 6, the user chose a 60-line target with a 70-line cap for the answer shape. No run was repeated after
  that change.

R3 ran in rounds 1, 4, 5 and 6. Content passed every time it ran.

Baselines (no skill), round 1: all three found most code facts, ran 30 to 80 lines, used no markers, and gave no
Ask next. The figure baseline missed the budget-not-actual trap. The status baseline did not say the API is in another
repository, and it read git history. Baseline replies were checked by eye and not saved.

Mechanical checks: no run changed a clone or a real checkout, apart from the one export file R5 was asked to write.
This repository changed only by the builder's own edits between rounds. The saved skill replies have no CJK
characters, no GUID-shaped value, and no skill name other than `agentd-diagnose`.

Not exercised: the onboarding pack and project contract as sources, a follow-up question, the cross-repository path
with a second path given, a stack with no reference, a server-rendered .NET view, a question in another language, a
figure computed in the frontend, an untraced hop through an event or a queue, a job with no screen, replacing an
existing export, and an engineer answering anything but the vague-question ask.
