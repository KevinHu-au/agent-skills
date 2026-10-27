# Evaluating agentd-blast-radius on the Shop fixture

How to check that the skill works, and the results of each run. The fixture is a synthetic Python and SQLite
shop, so nothing here touches a customer repository. Every run uses its own throwaway folder in the system temp
folder.

Scoring uses `expected-findings.md`. There are three scenarios, one change input each in
`tests/blast-radius/changes/`: 1 hidden break, 2 safe because of one fact, 3 unprovable.

## Setup

```
FIX=$(mktemp -d)
tests/blast-radius/make-fixture.sh "$FIX/shop"   # prints "head <hash>"; the hash is the same on every build
```

Build a fresh fixture for every run. A run may leave `__pycache__` folders in it. They are git-ignored, so
`git status` stays clean.

## Procedure

1. **Baseline, no skill.** One run for each scenario. Give a fresh agent only the baseline prompt below. Score the
   answer. This is the starting point the skill must beat.
2. **Skill runs.** One run for each scenario, each in its own fresh fixture, with the skill prompt below.
3. **Mechanical checks** on every run, with the commands in `expected-findings.md` (one block for each scenario,
   plus the checks that apply to every run).
4. **Score** each report with the rubric. Record the results and any change to the skill under Iterations.

No agent may read `expected-findings.md`. The skill prompt allows the skill folder and the fixture only. The
baseline prompt allows the fixture only.

## Rubric

For each run, one point for each criterion that holds.

| # | Criterion |
|---|---|
| R1 | The verdict matches `expected-findings.md`: Breaks, Contained, Unproven. |
| R2 | The report names the safety fact as one claim that a run can show true or false, and it matches the key. |
| R3 | Every fact the key lists is in the report with the key's tier, or is `unknown:` with who to ask. |
| R4 | Nothing is called confirmed without a run. A search that finds nothing is never confirmed. |
| R5 | The ending follows the gate. Breaks and Contained: an add-on block and the `/agentd-dev-rev` line. Unproven: the last line is the question, with no add-on block and no `/agentd-dev-rev` line before it. |
| R6 | The fixture is unchanged and the scratch folder is gone or was never made (the mechanical checks). |
| R7 | No trap from the scenario's trap list. |

A skill run passes with 7 of 7. A baseline run is scored on R1, R3, R4, R6 and R7 only, because it has no add-on
block or gate to follow. R2 is scored for a baseline only when it names a safety fact on its own.

## Prompts

**Baseline prompt.** Nothing else is given.

```
You are helping an engineer who supports a customer application. The project is the git repository at
<FIXTURE>. This is the change the engineer plans (or wants checked):

<CHANGE>

Find out what else this change could break before it ships. Do not change any file in the project folder. Read
only files inside that project folder. Work alone: nobody can answer questions. Write your answer as a report.

When you finish, write the report to <RESULTS>/<run>.md (create only that file there), then return the same
report as your last message.
```

**Skill prompt.** It makes the agent the engineer, so the run can go on without a person.

```
Run the agentd-blast-radius skill. Read <REPO>/skills/agentd-blast-radius/SKILL.md and follow it. It points to
files in the references folder next to it; read them as it says. Read nothing else in <REPO>. The project is
the git repository at <FIXTURE>. Start there. This is the change:

<CHANGE>

You are also the engineer. When the skill asks for the one confirmation of the run plan, the answer is yes: for
every command the project contract allows, for the scratch folder, and for its removal after the report. Nothing
else is confirmed. For any other question, do not answer it: end your reply with the question.
Do not edit anything in <REPO> or in the project. Do not commit.
When you finish, put a section "Skill feedback" first, with fewer than 150 words: any place where the skill's
instructions were unclear, contradictory or missing. Then give the report, and the add-on block if the skill
writes one.
This harness returns only your last message. So remove the scratch folder in the step before that message, and
say so in the Scratch line.
Also write that whole last message to <RESULTS>/<run>.md (create only that file there), then return it.
```

`<CHANGE>` is the text of the change file for the scenario, from its second line on. The removal sentence and
the results file are limits of this harness, which returns only the last message. They are not part of the skill.

## Results

Round 1 ran on 2026-10-27: one baseline and one skill run for each scenario, six fixtures in all (head `3fc4ff2`,
the same database dump on every build). Every agent was a sub-agent that used the default model of the harness
and ran in parallel with the others. The assistant who scored the runs also wrote the prompts. Scoring was done
by reading the saved reports against `expected-findings.md`.

| Run | Scenario | Score | Traps | Notes |
|---|---|---|---|---|
| Baseline | 1 hidden break | 4 of 5 | none hit | Found all three hidden readers and ran the report, the export and the `$NaN` mapping on a copy. Named Priya and the old app versions. It gives no verdict word and no tiers (R3 fail), so the reader cannot tell what was run from what was read. |
| Skill | 1 hidden break | 7 of 7 | none hit | Breaks. Safety fact stated and shown false by runs. Report and export `confirmed`. The in-repository client `confirmed` with `node`, the deployed apps `supported` with `unknown: ask Mobile team (Priya)`. Fulfilment feed and positional inserts cleared by a run. Add-on block and the `/agentd-dev-rev` line. Extra, true finding: nothing migrates an existing `data/shop.db`. |
| Baseline | 2 safe on one fact | 3 of 5 | T2 partial | Right answer (safe, and a no-op for the ticket). It checked the 62 accepted characters, but shows no run of the real `CODE_RE` over every code point (R3 fail, T2 partial). No tiers. |
| Skill | 2 safe on one fact | 7 of 7 | none hit | Contained. A script imported the branch copy from `git archive` and ran the real `CODE_RE` over every code point (62 accepted) and the CHECK over every code point (36 accepted). Add-on block and the `/agentd-dev-rev` line. Extra, true finding: the new test also passes on `main`, so the branch does not fix the ticket. |
| Baseline | 3 unprovable | 4 of 5 | none hit | Said do not ship until the partner and the time zone are answered, and named Marcus. Ran the feed on a copy. No verdict word and no tiers (R3 fail). |
| Skill | 3 unprovable | 7 of 7 | none hit | Unproven. Our side `confirmed` by a feed run on a copy (141 lines, same header, same wall-clock value). The partner's import `unknown: ask Fulfilment team (Marcus)`, with the evidence needed. Stale document listed, not used as evidence. No add-on block. The last line is the question. |

Mechanical checks passed on all six fixtures: `git status --porcelain` empty, `HEAD` on `main` at `3fc4ff2`, three
migration files, no `fulfilment_*.csv`, no file newer than the database, the same database dump, no stash and one
worktree. The three skill runs removed their scratch folders with `rm-scratch`; each folder is gone. The three
baseline runs wrote their copies into the session scratchpad of the assistant, outside the fixture. That is not a
rubric item.

On this small fixture a plain agent finds most of the facts. The skill's gains are the verdict, the tiers that
separate a run from a reading, the proof over the whole input space in scenario 2, the gate in scenario 3, and the
add-on block for `agentd-dev-rev`.

### What these runs do not show

- One run for each scenario, so no measure of how often a run goes wrong.
- The read-only sub-agent option for a wide change. Every agent was itself a sub-agent.
- An engineer answering: "get more evidence", "hand off anyway", and the add-on block after hand off anyway.
- A branch diff with staged changes on top (the default input), a .NET, iOS or React project, and a real customer
  repository.
- The order "remove the scratch folder after the report". The harness returns only the last message, so the
  prompt asked for the removal first.

### Feedback from the agents that was not acted on

- The skill gives no place for a finding that is not a break, such as "the change does not fix the ticket"
  (scenario 2), or for a decision the engineer must make on Breaks (scenario 1).
- It does not say whether a runtime the contract does not list (`node`) counts as a safe check.
- It does not say what to do when two safety facts meet (scenario 3: the reader accepts the value, and the stored
  value is UTC).
- `references/surfaces.md` has no item for "who migrates an existing database" (scenario 1).
- On Unproven, there is no place for a document the change must also update (scenario 3).

## Iterations

None yet. The skill was not changed after round 1.
