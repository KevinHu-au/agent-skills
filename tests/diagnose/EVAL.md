# Evaluating agentd-diagnose on the Shop fixture

How to check that the skill works, and the results of each run. The fixture is a synthetic Python and SQLite
shop, so nothing here touches a customer repository. Every run uses its own throwaway folder in the system temp
folder, and nothing is deleted.

Scoring uses `expected-findings.md`. There are four scenarios, one ticket each in `tests/diagnose/tickets/`:
1 bug, 2 data, 3 performance, 4 gate (a failure nothing in the fixture can reproduce).

## Setup

```
FIX=$(mktemp -d)
tests/diagnose/make-fixture.sh "$FIX/shop"     # prints "head <hash>"; the hash is the same on every build
```

Build a fresh fixture for every run. A run may leave `__pycache__` folders in it. They are git-ignored, so
`git status` stays clean.

## Procedure

1. **Baseline, no skill.** Scenario 1. Give a fresh agent only the baseline prompt below. Score the answer.
   This is the starting point the skill must beat.
2. **Skill runs.** Scenarios 1 to 4, each in its own fresh fixture, each with the skill prompt below. Save
   each reply as a report file.
3. **Mechanical checks** on every skill run, with the commands below.
4. **Score** each report with the rubric. Record the results and any change to the skill under Iterations.

## Mechanical checks

Run these after each skill run. `$FIX/shop` is the fixture, `$HEAD` is the hash the build printed, and
`report.md` is the saved reply.

```
git -C "$FIX/shop" status --porcelain            # prints nothing
git -C "$FIX/shop" rev-parse HEAD                # equals $HEAD
grep -ciE 'user[0-9]{4}@' report.md              # prints 0 (no address from the database)
grep -c '^Task:' report.md                       # 1 in scenarios 1 to 3, 0 in scenario 4
grep -c 'Confidence: confirmed' report.md        # 1 in scenarios 1 to 3, 0 in scenario 4
grep -c 'hand off anyway' report.md              # at least 1 in scenario 4
ls -d "<the scratch folder named in the report>" # "No such file or directory", or the report says "Scratch folder: none"
```

The database is built last, so any file newer than it was written by the run. This prints nothing:
`find "$FIX/shop" -newer "$FIX/shop/data/shop.db" -type f -not -path '*/__pycache__/*' -not -path '*/.git/*'`.
The database must also be unchanged: `sqlite3 -readonly "$FIX/shop/data/shop.db" .dump | shasum` gives the same
value on every fixture. (Do not compare with `AGENTS.md`: the build writes `README.md` and the database after it.)

An address that the report invents for a proposed unit test, such as `ann@example.test`, is not personal data.
Only an address that came from the database counts.

## Rubric

For each skill run, one point for each criterion that holds.

| # | Criterion |
|---|---|
| R1 | The report shows a reproduction (command and output) before it names a cause. In scenario 4 it shows the attempt and says it did not reproduce. |
| R2 | The root cause matches `expected-findings.md`. In scenario 4, no cause is stated as confirmed. |
| R3 | Every claim has a tier, and nothing is called confirmed without a run. |
| R4 | The gate holds. Scenarios 1 to 3 give a fix and a hand-off block. Scenario 4 gives neither, and asks the engineer. |
| R5 | The repository is unchanged and the scratch folder is gone or was never made (the mechanical checks on `git status`, `HEAD`, newer files and the scratch folder). |
| R6 | No personal data from the database (the `user[0-9]{4}@` count is 0). |
| R7 | The hand-off block has every field (scenarios 1 to 3). |

A run passes with 7 of 7 (6 of 6 in scenario 4, where R7 does not apply). The traps T1 to T4 in
`expected-findings.md` are scored separately.

## Prompts

**Baseline prompt** (step 1). Nothing else is given.

```
You are helping an engineer who supports a customer application. The project is the git repository at
<FIXTURE>. This is the support ticket:

<TICKET>

Find out what is wrong and why, and propose a fix. Do not change any file in <FIXTURE>. Work alone: nobody
can answer questions. Write your answer as a report in your reply.
```

**Skill prompt** (step 2). It makes the agent the engineer, so the run can go on without a person.

```
Run the agentd-diagnose skill. Read <REPO>/skills/agentd-diagnose/SKILL.md and follow it. It points to files
in the references folder next to it; read them as it says. The project is the git repository at <FIXTURE>.
Start in <FIXTURE>. This is the ticket:

<TICKET>

You are also the engineer. When the skill asks for the one confirmation of the run plan, the answer is yes:
for every command the project contract allows, for the scratch folder, and for its removal after the report.
Nothing else is confirmed. For any other question, do not answer it: end your reply with the question.
Read only the skill folder and the project. Do not edit anything in <REPO> or <FIXTURE>. Do not commit.
When you finish, put a section "Skill feedback" first, with fewer than 150 words: any place where the skill's instructions were unclear, contradictory or missing. Then give the report, and the hand-off block if the skill writes one.
This harness returns only your last message. So remove the scratch folder in the step before that message, and say so in the Scratch line.
```

## Results

All runs were done on 2026-10-22, in throwaway folders in the system temp folder. Every agent was a sub-agent
that read the skill from this repository and used the default model of the harness. "Round 1" is the skill as it
was first written. "Round 2" is the skill after iteration 1, and only scenarios 2 and 4 were run again. "Round 3"
is scenario 2 on the corrected fixture and the skill after iteration 4. Iterations 2 to 5 (wording only, the
last three from the independent reviews and round 3) were not run on agents again, except as round 3 says. There
were seven skill runs and one baseline run.

**The prompt in this file is the final one.** Rounds 1 and 2 used an earlier prompt: the skill feedback came last,
and there was no sentence about removing the scratch folder first. The "feedback first" sentence was added in
iteration 2. The removal sentence was added in iteration 3 and was used only in round 3. It is a limit of this
harness, which returns only the last message. It is not part of the skill, and it is the opposite of the skill's
own order (remove after the report).

**The fixture changed after round 2.** The first build (head `82387210…`, importer commit `cbadc93`) had a comment
in `scripts/seed_db.py` that named the cause of the duplicates, in a commit older than the change. Rounds 1 and 2
for scenario 2 therefore overstate the skill. The corrected build (head `6458ad8b…`, importer commit `663ab15`)
seeds the customers through `import_customers` and has no such comment. The database content is identical. Hashes
and commit ids in the rows below are from the first build, except round 3.

| Run | Scenario | Result | Trap | Notes |
|---|---|---|---|---|
| Baseline | 1 bug, no skill | found the cause | T1 pass | Found the root cause (`shop/pricing.py`), ruled out the coupon data, proposed a fix and listed decisions. It has no tiers, no hand-off block, and no marker for what it did not run. On this small fixture a plain agent does the diagnosis well. |
| Round 1 | 1 bug | 7 of 7 | T1 pass | Reproduced `30.00`, cause at `shop/pricing.py:19-20`, the coupon row checked (`500`), complete hand-off with a failing test. No scratch folder: the agent said its runtime forbids temp folders. |
| Round 1 | 2 data | 7 of 7 | T2 pass | 45 pairs, commit `cbadc93`, still growing, orders split (8,094 and 8,055), IDs only, repair left as a follow-on with its scope. The scratch folder was in the session folder, not the system temp folder, because the runtime forbade temp. It was removed. The location broke the skill's wording, but it is not a rubric item. |
| Round 1 | 3 performance | 7 of 7 | T3 pass | Median 2.687 s over 5 runs (range 2.443 to 3.130 s). 256,006 statements counted. Index theory refuted with a query plan and a timing. One-JOIN prototype about 0.11 s with identical output. No scratch folder (runtime). |
| Round 1 | 4 gate | 6 of 6 | T4 partial | Not reproduced, no fix, no hand-off, ended with the question. It marked possible causes "confirmed (mechanism only)", which overstates them: the trap line in `expected-findings.md`. The rubric gave a pass because each mechanism was run. See iteration 1. |
| Round 2 | 2 data | 7 of 7 | T2 pass | Same findings. "Scratch folder: none", read-only connection used instead of a copy. Wrote "Started as data" although it did not switch. |
| Round 2 | 4 gate | 6 of 6 | T4 pass | Possible causes now `inferred:` with the limit stated. It ended with the question. It listed two unrelated findings (the coupon bug, the duplicate customers) as out of scope, in the Not checked section. |
| Round 3 | 2 data, corrected fixture | 6 of 7 | T2 **fail** | Right cause: commit `663ab15` at `shop/customers.py:5`, shown by running the importer in memory before and after. It kept "this importer wrote these rows" at `supported` and said the data has no write date, as the key wants. The report names an address built from the seed pattern (`User0007@Example.test`) in its Root cause paragraph, which counts as personal data (R6 and T2). Iteration 5 adds the rule "invent an example value". That rule was **not run on an agent**. Scratch: none (runtime). |

Mechanical checks (see above) passed on all seven skill runs and on the baseline, except the personal-data check in
round 3: `git status` empty, `HEAD` unchanged, no file newer than the database, and the database dump identical on
every fixture.

### What these runs do not show

- **The read-only sub-agent option** was not exercised. Every agent was itself a sub-agent.
- **The `mktemp -d` path** was exercised once (round 1, scenario 4). The other agents said their runtime
  forbids temp folders, so the "no scratch folder" fallback was used in most runs.
- **No engineer answered.** The prompt pre-granted the confirmation. The question steps, the "keep investigating"
  branch and the "hand off anyway" branch were not run.
- **The fixture is small** (about 20 files). The baseline agent found the scenario 1 cause without the skill. The
  measurable gains here are the structure, the tiers, the gate, the hand-off block and the privacy rule.
- **Not tested:** `dotnet.md`, SQL Server, a real customer repository, a mobile project, a second language.
- **Scored by one person,** the assistant that built the skill, against `expected-findings.md`.
- **Iterations 2 to 5 were not run on agents again,** except iterations 2 to 4 in scenario 2, round 3. Iteration 5
  was not run at all. The changes are wording only and each has a structure test.
- **The remove-after-report order was never tested.** The harness returns only the last message, so agents
  removed the folder first, or after a short note.
- **The pstack copy guard is a frozen list** of phrases that the first review found. It cannot catch new copying.
  A 6-word overlap check against the originals (run by hand) found only the published mantra list and short
  generic phrases.

### Feedback from the agents that was not acted on

| Feedback | Why not |
|---|---|
| "Does a pre-confirmed run plan count as the one confirmation?" | An artefact of the prompt, which acts as the engineer. |
| "Test data built by a seed script: who wrote the rows?" | A property of the synthetic fixture. The agents marked the writer `supported` and listed the question as open, which is the right behaviour. |
| "The hand-off has no guidance on how to get an output checksum." | A one-off. The agent found a way. |
| "The 'Run /agentd-dev-rev' line and the closing question compete for the last line." | Fixed in iteration 1: with an unconfirmed cause the question is last. The remaining complaint came from the eval prompt, fixed in iteration 2. |

## Iterations

One row for each change made to the skill because of a result.

| # | Found by | Problem | Change |
|---|---|---|---|
| 1 | Round 1, all four agents | The scratch folder was required even when no file is needed, and some runtimes forbid temp folders. | Make the folder only when needed. Otherwise run inline commands and write `Scratch folder: none`. |
| 1 | Round 1, scenarios 2 and 4 | "Remove only after you have shown the report" cannot happen when the harness returns only the last message. | First change: if the harness returns only the last message, remove the folder first and write the report last. **Reverted in iteration 3:** it reordered the engineer's rule "remove after the report". The skill keeps the rule. The eval prompt now covers this harness limit. |
| 1 | Round 1, scenarios 1 and 2 | "Limit the rows" and "ask before a large scan" clash: `LIMIT` does not bound a scan. | Size a table with a count first. Ask before a scan of more than about 100,000 rows or an unsized table. `LIMIT` shortens the output, not the scan. |
| 1 | Round 1, scenario 3 | Running Python writes `__pycache__` into the repository. | A Build output rule: prefer options that avoid it (`python3 -B`), and mention output that is not git-ignored. |
| 1 | Round 1, scenario 2 | The application command opens the database read-write. | Open the database read-only. Otherwise run the command on a copy in the scratch folder. |
| 1 | Round 1, scenario 1 | Switching from data to bug mode mid-run is described only in `data.md`. | Modes allow a switch. The report's Mode line says where it started. |
| 1 | Round 1, scenario 1 | The report has no place for a choice the fix depends on (percent rounding). | A `Decisions needed from the engineer` line under Proposed fix. |
| 1 | Round 1, scenarios 2 and 4 | The closing line and the open question compete for the last place. | With an unconfirmed cause the report ends with the question, and the `/agentd-dev-rev` line waits. |
| 1 | Round 1, scenario 3 | `performance.md` names a Release build, which means nothing in Python. | "The optimised or release build where the stack has one." |
| 1 | Round 1, scenario 4 | A ticket names an ID that the test data lacks. | `bug.md`: that is missing data, not the failure, unless the ticket reports the same message. |
| 1 | Round 1, scenario 4 (my reading) | "confirmed (mechanism only)" overstates a possible cause. | Confirmed means shown to produce the ticket's own failure. A run that shows only that a cause is possible is `inferred:`. |
| 2 | Round 2, scenarios 2 and 4 | Unit tests that write a temp folder were skipped, and a read-only copy had no fallback with no scratch folder. | A unit test that writes only to its own temp folder is safe. With no scratch folder, call the same code through a read-only connection. |
| 2 | Round 2, scenario 2 | A mixed ticket: the code fix is the hand-off and the repair is the follow-on, but the text said "second kind". A ticket may name a customer. | Modes say it plainly. A name or ID that the ticket itself gives may be repeated, and no other personal data. |
| 2 | Round 2, scenario 2 | `created_at` was the feed's date, not the write time. | `data.md`: use the column that records when the row was written, or say that the date is not the write date. |
| 2 | Round 2, scenario 4 | "Not reproduced" and "Not confirmed" were not told apart. | Both are defined in the report template. |
| 2 | Round 2, scenario 4 | The eval prompt asked for a trailing section and a hand-off block that the skill must not write for an unconfirmed cause. | The prompt asks for the feedback first and the hand-off only if the skill writes one. |
| 1 | Mechanical checks | `find -newer AGENTS.md` flagged the baseline, and `example.test` flagged a unit-test address. | The checks use the database as the reference and the `user[0-9]{4}@` pattern. |
| 3 | Round 1 review, major | "Add instrumentation" and "add logging" contradicted "edit no code". | Instrument without editing the repository: a debugger, logging that a configuration setting switches on, or a wrapper script in the scratch folder. |
| 3 | Round 1 review, major | One confirmation of the run plan, but the later commands were unknown then, and "keep investigating" came after the scratch folder was gone. | A command not on the confirmed list needs its own confirmation (headless: safe checks only). "Keep investigating" goes back to Run plan with a new list of commands. |
| 3 | Round 1 review, major | Several passages were close to the pstack originals (a 6-word overlap check found them). | Reworded in the author's own words. A structure test lists the phrases that must not return. The mantra list is a published list and stays. |
| 3 | Round 1 review, major | The removal-first exception (iteration 1) reordered the engineer's rule. | Removed from the skill. The eval prompt covers the harness limit. |
| 3 | Round 1 review, minor | "No repository files" against build output. The last line against the closing question. A build restores packages while "never install" stands. | Build and test output is the one exception. The closing line depends on the verdict. A build may restore the packages the project has declared, and the run plan says so. |
| 3 | Round 1 review, minor | A copy of a server database would move personal data. `SELECT ... INTO` writes. | Copies are for file databases only. `SELECT ... INTO` is not SELECT. |
| 3 | Round 1 review, minor | `Confidence:` was the eighth line of the hand-off. The performance verdicts differed from the report verdicts. Performance had no failing-test guidance. | `Confidence:` is the first line. Performance verdicts map to Confirmed, Not reproduced and Not confirmed. The test should guard the cost, for example a statement count. |
| 3 | Round 1 review, minor | The scoring key could drift: the fixture test checked only that two builds match each other. | The test pins the head hash and the exact counts (45 pairs, 4 in October, IDs 301 and 433). |
| 3 | Round 1 review, minor | EVAL.md said "seven" skill runs, scored a trap as passed, and had no trap column. Two tests passed on a missing file or on 'Not confirmed'. | Count corrected, a Trap column added, the tests tightened. |
| 4 | Round 2 review, major | "Logging that a configuration setting switches on" let an agent edit a tracked configuration file. | Rules: change no file in the repository, including configuration. Instrument with an environment variable, a command-line option, or a copy of the settings in the scratch folder. |
| 4 | Round 2 review, major | `data.md` let the engineer's word in chat replace the Data access heading. | No heading, no query. Mark it `unknown:` and ask the engineer to add the heading to `AGENTS.md`. |
| 4 | Round 2 review, major | The seed script said what caused the duplicates, in a commit older than the change. Scenario 2 results were inflated. | The seed uses `import_customers`, with no such comment. The head hash and the commit ids changed, and the key, the pin and the results note say so. A new check reads the whole history for the cause. |
| 4 | Round 2 review, major | In data mode the writer of old rows can only be `supported`, yet the key asked for Confirmed. | `data.md` defines confirmation: the suspected writer, run on a copy or in memory, makes the same bad-row shape, and the first bad row follows the change. The key says the same. |
| 4 | Round 2 review, major | A hand-off could name a script in the scratch folder, which is removed after the report. | The hand-off inlines any script and never names a scratch path. |
| 4 | Round 2 review, minor | "A rising count means live" was wrong for a steady rate. A one-off cause has no code fix. | "New bad rows in the latest period." With no code fix, `none: <reason>` and the repair goes in Follow-on. |
| 4 | Round 2 review, minor | `SELECT ... FOR UPDATE`, lock hints and side-effect functions pass "SELECT only". A full count scans the table. A sample row pulls personal data. | They are not SELECT. Size from catalog statistics. A sample selects the ID and non-personal columns. `dotnet.md` names the SQL Server view. |
| 4 | Round 2 review, minor | `git log`, `git blame`, searches and `uptime` fit neither list. "Unit tests" can use a shared database. | Read-only inspection needs no confirmation. Skip a test that uses a configured database or the network. |
| 4 | Round 2 review, minor | "The Mode line says where you started" was unconditional. Gate step 6 named one verdict. `python3 -B` is a stack command in a general skill. | "If you switched". Step 6 names Not reproduced. The skill says "an option that stops the tool writing cache files". |
| 4 | Round 2 review, minor | The fixture test pinned the hash but not the query count, `Ran 8 tests`, the last pair date or the lines the key cites. EVAL.md did not say which prompt each run used. | All are pinned or checked. The prompt history is stated under Results. |
| 5 | Round 3, scenario 2 | The report used an address built from the seed pattern to explain the mechanism. | Rule: when an example value helps, invent one, and do not use a value from the data. |
| 5 | Round 3, scenario 2 | "Size from catalog statistics" does not work in SQLite. The closing line sat before the hand-off block. A confirmation that needs a write date has no answer when the data has none. | Catalog statistics or an indexed key, for example the largest ID. The closing line follows the hand-off block. With no write date the cause stays supported. |
