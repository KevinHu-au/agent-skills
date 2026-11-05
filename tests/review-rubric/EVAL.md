# Evaluating agentd-review-rubric

How to check that the skill works, and the results of each run. The check uses three synthetic repositories from
`make-fixture.sh`. Every run uses its own throwaway folder in the system temp folder. No customer project is used.

## Setup

```
E=$(mktemp -d)
tests/review-rubric/make-fixture.sh "$E/fx"   # builds a, b and c; the commit hashes are the same on every build
```

Build a fresh set for every run. After the run, remove the folder with `"$HOME/.agents/bin/rm-scratch" "$E"`.

## Procedure

For each fixture, give a fresh agent the skill path and the fixture path. It may read the skill folder and its fixture
only. Nobody is at the keyboard, so the prompt gives the engineer's answers in advance and asks the agent to quote each
question it would have asked. Ask the agent to report where the skill text was unclear or it had to guess.

Run every command from the fixture's root. A run that calls `onboarding-pack find` from another folder looks up the
wrong repository.

## Fixtures and pass criteria

| Run | Fixture | Scripted answers | Pass when |
|---|---|---|---|
| A | `a`: `CONTRIBUTING.md`, a PR template, a lint config; no rubric, no pack | Files: `committed`. Role: tech lead. Add one rule. Agree to save. | Criteria cite those files by `path:line`. At most 15. No rule that lint enforces. Saved to `docs/onboarding/review-rubric.md` after the placement question. Nothing else written. |
| B | `b`: a README with no norms; no rubric | Nobody answers. | Asks for rules and roles. Writes no file. No `inferred:` criterion above Minor. |
| C | `c`: a rubric already in `AGENTS.md` | Nobody answers "what to change". | Shows the rubric, asks what to change, edits no file. |

## Results

### 2026-11-05, first run (skill as first written)

| Run | Result | Notes |
|---|---|---|
| A | Pass | Five criteria. Every cited line number matches its file. No commit-size or "clean code" rule was drafted, because they fail the Checkable rule. |
| B | Pass | No file written. The draft held a header only. |
| C | Pass | Showed the rubric, asked, edited nothing. |

Gaps the agents reported, and the change that closed each:

| Gap | Change |
|---|---|
| No wording for a closing line when nothing is saved, or when a rubric already exists (B, C) | The closing line now says where the file is, or that nothing was saved. |
| Sources give no criteria: header-only draft printed (B) | Say so, ask for rules, and with nobody to answer print no draft and write nothing. |
| `Owner:` had no rule (A, B) | The role the engineer names is the Owner; otherwise `Owner: unknown: ask the team`. |
| No place for the lint pointer; the agent added its own header line (A) | The template has an optional `Lint:` header line. |
| Nothing said who picks a severity (A) | The skill proposes it and the engineer corrects it. |

Harness note: in run B the agent called `onboarding-pack find` from another folder, so the lookup used the wrong
repository. The result was the same (no pack). The Procedure now says to run every command from the fixture's root.
This is a fault of the test setup, not of the skill.

### 2026-11-05, second run (skill after the round 1 and round 2 reviews)

Fixtures `a` and `c` were copied for each run. Fixture `d` is `c` plus a branch with one change in `src/reports/`.
Every run used a fresh agent, and every command ran from the fixture root.

| Run | Fixture | Scripted answers | Result |
|---|---|---|---|
| D | `a` copy | `none`; first a relative folder, then an absolute one outside the repository; role tech lead; add one rule; save | Pass. The relative folder was rejected. One file was written, the repository stayed clean, `set` was printed and not run. |
| E | `a` copy | `local only`; role tech lead; no extra rule; save | Pass. One file in `docs/onboarding/`. The exclude file was left as it was, and the exclude line was printed. The agent forgot the closing line, because the text gave no wording for `local only`. |
| F | `d` and `b` | pr-review and dev-rev, rubric parts only | Pass. Found the rubric in `AGENTS.md`, matched only R1, wrote a Block finding in the template form, gave the right no-rubric line for both skills. |

Gaps the agents reported, and the change that closed each:

| Gap | Change |
|---|---|
| Closing line has no wording for `local only` | The same line tells the engineer to add the exclude line. |
| `/var` against `/private/var`: no way to compare real paths | The `none` folder check compares `pwd -P` paths. An existing empty folder is fine. |
| Role question when the engineer states no rule | Ask for the Owner role once even then. |
| Two sources for one rule | One criterion lists both sources. |
| `Date:` had no format | `YYYY-MM-DD`. |
| `**` and zero folders; own staged work against a base | `**` matches zero or more folders; the engineer's own staged work is read from the working copy. |
| No evidence tier for a rubric finding | `supported by the diff and R<number>` when the diff shows it plainly. |

Left as written: in dev-rev the no-rubric line ends the step 8 report, and step 9 comes after it. `SKILL.md` step 8
says so, and the agent read it correctly.

Not run: `committed` placement, a refresh of an existing rubric, `Applies to` lists with several globs.
