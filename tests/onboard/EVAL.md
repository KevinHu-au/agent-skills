# Evaluating agentd-onboard on the Shop fixture

How to check that the skill works, and the results of each run. The fixture is a synthetic project, so
nothing here touches a customer repository. Every run uses its own throwaway folder in the system temp
folder, and nothing is deleted.

Scoring uses `expected-facts.md`. For each of the nine questions:

- **pass:** every listed fact is present, or is marked `unknown:` with who to ask.
- **partial:** some facts are present and the rest are missing without a marker.
- **fail:** a listed fact is wrong, or the answer is missing with no marker.

The eight traps at the end of `expected-facts.md` are scored separately as T1 to T8.

## Setup

```
FIX=$(mktemp -d)
tests/onboard/make-fixture.sh "$FIX/shop"          # v1, one commit
tests/onboard/make-fixture.sh "$FIX/shop" --v2     # v2, two commits (use a new folder)
```

The builder prints the commit hashes. They are the same on every run.

## Procedure

1. **Baseline, no skill.** Build a v1 fixture. Give a fresh agent only the baseline prompt below. Score
   the brief it writes. This is the starting point the skill must beat.
2. **Create mode, headless.** Build a v1 fixture. Give a fresh agent the skill prompt below. Run
   `tests/onboard/check-brief.sh <fixture>/docs/onboarding <fixture>`. The second argument is the
   repository root. Pass = exit 0 and no secret value anywhere in the pack.
3. **Fresh reader.** Give another fresh agent the brief and `feature-to-code.md` from step 2, the nine
   questions, and one symptom: "the invoice amount is wrong". The agent has no tools. Score questions 1 to 8
   from the brief alone, and question 9 from the brief and `feature-to-code.md`. The symptom must map to
   files. The right answer is `OrdersController.Invoice`, `InvoiceService.Fetch` and
   `LegacyBusClient.GetInvoiceAsync`, with the calculation marked `unknown:` because it is outside the
   repository. Pass = every question is a pass or a marked gap, and the symptom answer is right or marked.
4. **No-op.** Run the skill again on the same fixture, unchanged. Pass = no file in the fixture changes
   (compare file checksums before and after, and `git status`).
5. **Update.** Build a v2 fixture. Copy the step 2 pack into it as `docs/onboarding/`, so the pack's scanned
   commit is the v1 commit, which is in the v2 history. Run the skill. Pass = the cancel use case and
   `net9.0` appear marked `changed:`, `Scanned commit` moves to the v2 commit, and the sections that
   cite no changed file (`Purpose and users`, `Data model`) are byte-for-byte the same. The cancel use case
   also gets a block in `feature-to-code.md`, marked `changed:`. Blocks in that file that cite no changed
   file are byte-for-byte the same. Blocks that cite `OrdersController.cs`, which v2 changes, may differ
   only in their `path:line` values. In a section that cites a changed file, only the facts the change
   touches and the `path:line` citations may differ. This narrows the plan's "unrelated sections
   untouched": update mode re-checks any section whose `Sources:` names a changed file, so a section is
   only unrelated if it cites no changed file. Update mode also goes one step beyond the plan's "re-check only
   sections whose `Sources:` changed": a changed path that no `Sources:` line names is mapped to the section it
   belongs to, so that a new file is not missed.
6. **Edge runs.** Each starts from a fresh fixture.
   - **a. Subfolder:** start in `src/Shop.Api`. The pack must land in the repository root.
   - **b. Worktree:** start in a linked worktree. A warning appears, and the pack goes to the main
     checkout (headless: nobody to ask).
   - **c. Dirty working tree:** change a tracked file first. The header says `Working tree: dirty`.
   - **d. Shallow clone:** copy the step 2 pack into a shallow clone of the v2 fixture, made with
     `git clone --depth 1 file://<fixture> <dest>`. A plain path is a local clone, and git ignores `--depth` for it.
     Confirm with `git rev-parse --is-shallow-repository`, which must print `true`. The skill
     does a full re-check and says why in the `Last refreshed:` line.
   - **e. Secrets:** in every pack above, `FIXTURE-NOT-A-SECRET` and `Password=` do not appear.
7. **Layout upgrade.** Make a pack with the skill as it was at commit `7c0ed56`, then run the new skill on
   the same fixture, unchanged.
   - Make a scratch folder with `mktemp -d`. Run `git worktree add <scratch>/onboard-old 7c0ed56` from
     this repository.
   - Set `<REPO>` in the skill prompt to `<scratch>/onboard-old`, and run it on a v1 fixture. This writes an
     older-layout pack.
   - Set `<REPO>` back to this repository, and run the skill again on the same fixture.
   - Pass = `Start here`, `feature-to-code.md` and checklist item 9 appear, the findings move to `Unknowns`,
     and nothing else changes. The use-case text, owners and items 1 to 8 stay as they were.
   - Then run the skill once more. Pass = no file changes, so the upgrade happens once.
   - Afterwards, tell the engineer the worktree's path. Do not remove the worktree or the scratch folder
     without asking.
8. **Real projects.** Run the skill on one web and one mobile customer project, each in a scratchpad
   clone, never in the real checkout. Give a fresh reader the pack and two symptoms. Record the results in
   a git-ignored local file, not in this file. This file is public, so it names no customer, project or
   business term. Pass = the named files are right, or the gap is marked.

## Prompts

**Baseline prompt** (step 1). Nothing else is given.

```
Write an onboarding brief for this project, for an engineer who is new to it. The project is the git
repository at <FIXTURE>. Write the brief to <FIXTURE>/docs/onboarding/README.md. Work alone: nobody can
answer questions. Only read inside <FIXTURE>. Do not commit.
```

**Skill prompt** (steps 2, 4, 5, 6, 7). In step 7, `<REPO>` is the old worktree for the first run.

```
Run the agentd-onboard skill. Read <REPO>/skills/agentd-onboard/SKILL.md and follow it. It points to files
in the references folder next to it; read them as it says. The project is the git repository at <FIXTURE>.
Start in <START_DIR>.
This is a headless run: nobody can answer questions or confirm anything. Do what the skill says for that
case. Read only the skill folder and the project. Write only inside the project's docs/onboarding/ folder.
Do not edit anything in <REPO>. Do not commit.
When you finish, reply in under 200 words: the files you wrote, and any place where the skill's
instructions were unclear, contradictory or missing.
```

**Reader prompt** (step 3). The brief and `feature-to-code.md` are pasted in. The agent has no tools.

```
You are a brand-new engineer. Below are the only documents you have about a project: the brief and the
feature-to-code map. Answer questions 1 to 8 using only the brief. Answer question 9 using the brief and
the map. If the documents do not say, write "not in the document". Do not guess. For each answer, give
the section you used.
Then answer this: "the invoice amount is wrong". Which files do you open first? Mark anything the
documents cannot tell you.
<the nine questions from SKILL.md>
<the brief>
<feature-to-code.md>
```

## Results

### Round 1: the skill before the layout change (2026-10-22)

All runs were done on 2026-10-22, in throwaway folders in the system temp folder. "Final" means the skill
wording after iteration 3 (and the numbering fix, iteration 4). Two rounds of code review changed the skill after
that (iterations 5 and 6), and no agent run was repeated afterwards. The results describe the skill as it was
after iteration 4.

| Step | Run | Result | Notes |
|---|---|---|---|
| 1 | Baseline, no skill | done | Most facts found on this small fixture: the `.NET 6` conflict, the job that does not run nightly, the password withheld, a broken build. The pack fails `check-brief.sh` (no header, checklist or `Sources:` lines) and has no `unknown:`, `inferred:` or `conflict:` markers, so a reader cannot tell what was confirmed. Scored by checker plus spot checks of the bus section, not line by line. |
| 2 | Create, headless | pass, 3 runs | Three runs (before iteration 1, after it, and final) all exit 0 with 0 warnings. 1,700 to 1,970 words plus `open-questions.md`. Every run handled all six traps. |
| 3 | Fresh reader | 7 of 8 pass, 1 partial | Read the iteration 1 pack. Q7 left out "data access rules are unknown". The brief says it under Data model, and checklist item 7 links only to Risks and delivery. Not changed: the fact was in the brief. |
| 4 | No-op | pass, 2 runs | Iteration 1 pack and final pack. File checksums, `git status` and HEAD are identical before and after. Both runs wrote nothing. |
| 5 | Update to v2 | pass, 2 runs | Cancel use case and `net9.0` marked `changed:`. Header at the v2 commit. `Last refreshed:` line added. `Purpose and users` and `Data model` are byte-for-byte the same. No file outside `docs/onboarding/` changed. |
| 6a | Subfolder | pass | The pack landed in the repository root. Run before iteration 1 and not repeated. |
| 6b | Worktree | pass, 2 runs | Warned, wrote to the main checkout, left the linked worktree untouched. |
| 6c | Dirty tree | pass | Header said `Working tree: dirty` and the agent named the changed file. Run before iteration 1 and not repeated, so the rule "list the changed files under Unknowns" is checked by a wording test only. |
| 6d | Shallow clone | pass, 2 runs | Full re-check, with the reason in the `Last refreshed:` line. Header at the v2 commit. The clones were made with `file://` and held one commit. A plain path would not have been shallow. |
| 6e | No secret anywhere | pass | `FIXTURE-NOT-A-SECRET`, `Password=` and `User Id=shop_app` appear in none of the 12 packs. |

`check-brief.sh` exits 0 on every pack the skill wrote.

### Round 2: the skill on this branch, with the layout change (2026-10-29)

Every run used its own folder under the session scratchpad. The skill is as it was on this branch before
iteration 7, and nothing was committed. Questions 1 to 8, the nine-question reader and the symptom are
scored against `expected-facts.md`. The older rows above still describe the older skill.

| Step | Run | Result | Notes |
|---|---|---|---|
| 2 | Create, headless | pass | `check-brief.sh <pack> <fixture>` (with the root) exits 0, 0 failures, 0 warnings. `README.md` 1,455 words, `feature-to-code.md` 440, `open-questions.md` 830. The pack without `open-questions.md` is 1,895 words. |
| 3 | Fresh reader | 8 pass, Q9 partial, symptom right | Questions 1 to 8 were answered correctly from the brief. Question 9 was partial: the reader gave the load and calculation points and the search method, but not the layer chain or the key concept, because the question text does not ask for them. The symptom "the invoice amount is wrong" was right: `OrdersController.Invoice`, `InvoiceService.Fetch`, `LegacyBusClient.GetInvoiceAsync`, and the calculation marked `unknown:` (ask the bus team). The reader had two file reads, not pasted text. |
| 4 | No-op | pass | File checksums and HEAD are identical before and after. |
| 5 | Update to v2 | pass | Checker 0 failures, 0 warnings. `Purpose and users` and `Data model` are byte-for-byte the same. Header at the v2 commit. A cancel block was added to `feature-to-code.md`, marked `changed:`. The other blocks differ only in their `path:line` values. |
| 6a | Subfolder | pass | Checker 0 failures, 0 warnings. |
| 6b | Worktree | pass | Checker 0 failures, 0 warnings. |
| 6c | Dirty tree | pass | Header says `Working tree: dirty`. Checker 0 failures, 0 warnings. |
| 6d | Shallow clone | pass | Full re-check, with the reason in the `Last refreshed:` line. Checker 0 failures, 0 warnings. |
| 6e | No secret anywhere | pass | No secret string in any pack. |
| 7 | Layout upgrade | pass | The old pack was made with the skill at commit `7c0ed56` and had no `Start here`. The new skill added `Start here`, `feature-to-code.md` and checklist item 9, and moved the committed-secret finding to `Unknowns`. Checker 0 failures, 0 warnings. A second run changed no file. Limit: the old pack's text was not saved, so "items 1 to 8 unchanged" was checked only through the checker. |
| 8 | Real projects | not run here | Done in the next task, with the results kept in a git-ignored local file. |

### What these runs do not show

- **The parallel explorer path was not run.** Every agent was itself a sub-agent and could not start
  sub-agents, so each used the skill's sequential fallback. The six explorer prompts and the synthesizer are
  checked for structure only.
- **The fixture is small** (21 files). The baseline agent found almost every fact without the skill. On this
  fixture the skill's measurable gains are the checker pass, the markers, the header and `Sources:` lines, the
  refresh behaviour, and the questions grouped by who to ask. Whether it finds facts a plain agent misses needs
  a bigger codebase: that is the real-project check.
- **No run had an engineer to answer.** The question steps and the confirm-before-editing `AGENTS.md` step were
  not exercised. In headless mode `AGENTS.md` is never written, so the contract-filling path is untested.
- **Round 2 skipped the explorers.** Every agent read the 21-file repository directly, so the new explorer
  fields and the Synthesizer sub-steps 3a to 3c were not exercised.
- **No round 2 step had an engineer to answer.**
- **The reader was scored by one person** (the assistant who built the skill), against `expected-facts.md`.

### Feedback from the agents that was not acted on

| Feedback | Why not |
|---|---|
| "I was a sub-agent, so I could not start sub-agents." | An artefact of the evaluation. The skill already has the sequential fallback. |
| "I could not read `templates/project-contract.md`." | By design: the skill works without it. The wording now says so. |
| A refresh can push the use cases above five. | A real limit. A refresh adds the new use case, and a person decides whether to merge. Left for the engineer. |
| `Purpose and users` can go stale when a change adds a use case, because update mode re-checks by `Sources:`. | The plan's rule. A section that cites no changed file is not re-read. An unclaimed changed path is mapped to the section it describes, and a user guide for a feature maps to Use cases, so `docs/userGuide/cancel.md` does not pull in Purpose and users. |
| The headless rules are spread across `SKILL.md`, `safe-checks.md` and `contract-fill.md`. | Each file states its own part. Worth a one-line summary later if more skills need it. |
| No marker for "the name says X but the code does Y". | `inferred:` and `conflict:` were used and read clearly. |
| Round 2: no rule to skip the explorers on a tiny repository. | Not changed. The fixture is small on purpose. The explorer path is unrun on a small repository: the real web and mobile runs started the explorers in parallel, and the fixture runs did not. |
| Round 2: no template line for a layer with no command. | Not changed. The agents wrote `unknown:`, which is the right marker. |
| Round 2: a backticked search term inside a layer-cell note trips the path check. | Fixed. Both templates now say to backtick only paths on `Open:` and `Pattern:` lines and in the two path columns, and to write any note without backticks. |
| Round 2: no home for a use case that breaks the layer pattern. | Not changed. The agents used prose in the block. |
| Round 2: the `AGENTS.md` headless rule lives only in `contract-fill.md`. | Not changed, same reason as the earlier row about spread headless rules. |
| Round 2: update mode does not say whether "was `net8.0`" is a `changed:` marker. | Not changed. The agents chose consistently. Left for a later wording pass. |

## Iterations

One row for each change made to the skill because of a result.

| # | Found by | Problem | Change |
|---|---|---|---|
| 0 | Reading the procedure before step 4 | After a first run the new `docs/onboarding/` is untracked, so update mode counted the pack itself as changed and as a dirty tree. A second run on an untouched repository would not be a no-op. | `update-mode.md`, `brief-template.md` and `SKILL.md` exclude `docs/onboarding/` from the change list and the dirty check. Test added first. |
| 1 | The feedback every agent gave in steps 2, 6a, 6b and 6c | (a) Two "list first" rules for `open-questions.md` clashed. (b) A full 40-character scanned commit and a 7 to 12 character id read as a contradiction. (c) The worktree check printed a relative path from a subfolder and had no headless fallback. (d) The brief had no home for contract facts when `AGENTS.md` was not written, and no way to mark a partly answered checklist item. (e) A use case a document states was `inferred:` in one file and not in another. (f) `external-systems.md` said never to read a secret, yet the key names are in the file that holds one. (g) No rule for a pipeline that names a project that is not in the repository. | Wording changes in `contract-fill.md`, `update-mode.md`, `SKILL.md`, `brief-template.md`, `explorer-prompts.md`, `safe-checks.md` and `external-systems.md`. Six tests added first, all failing before the change. Steps 2 and 6b repeated. |
| 2 | The repeat runs of steps 2 and 6b | (a) `open-questions.md` was always written, but `SKILL.md` listed it as an optional side file. (b) A worktree run did not say which checkout to read and run git in, how to deliver the warning headless, or what to do with a bare main repository. (c) No rule for where a stale-source finding goes in create mode. | `SKILL.md`: `open-questions.md` is always written; a worktree run reads, runs git and writes in the main checkout; findings go to Unknowns and `open-questions.md`. Three tests added first. |
| 3 | Steps 4, 5 and 6d | (a) `SKILL.md` did not say which Flow steps update mode replaces. (b) Side files carried scan lines that nothing refreshed. (c) A full re-check had no rule on explorers. (d) A headless refresh had no rule for a contract not written earlier. (e) `conflict:` was used for a committed password, which is a finding. | `SKILL.md`, `update-mode.md` and `contract-fill.md`. Four tests added first. |
| 4 | The final no-op run | Iteration 3 wrote "the check in step 5", which collides with step 5 of `update-mode.md`. | `SKILL.md` says "Flow step 5 (the eight questions)". Test added first. The final runs were done before this one-phrase fix. |
| 5 | Code review, round 1 (a separate reviewer sub-agent, 15 findings) | (a) Update mode never reached the contract refresh. (b) The skill's own `AGENTS.md` edit and build output counted as changes. (c) `make-fixture.sh` took identity, dates and ignore rules from the caller's environment and could fail with exit 0. (d) Step 4 said "only when" and then added unclaimed paths. (e) The worktree commands failed for a separate git dir and a bare main repository, and `.git/info/exclude` is not a file in a worktree. (f) A customer's own `docs/onboarding/README.md` would be rewritten as a pack. (g) Step 6d did not make a shallow clone. (h) The safe-checks test was vacuous. (i) R6 missed provider token formats and exempted any `Scanned commit:` line. (j) R5 and R7 read fenced text, titled links and CRLF files wrongly. (k) A dirty header forced a full re-check every time, and old `changed:` markers were never cleared. (l) `SKILL.md` and `safe-checks.md` disagreed about the package restore. (m) A repository with no commits had no rule. (n) R5 accepted an empty `Sources:` line. | Fixes in `check-brief.sh`, `make-fixture.sh`, `SKILL.md`, `update-mode.md`, `safe-checks.md` and this file, each with a failing test first. Declined: widening the R6 token class (false positives on long paths), changing the worktree design (the agreed design, left to you), rewriting the phrase tests, and checking reference-style links. |
| 6 | Code review, round 2 (a fresh reviewer, 8 findings) | (a) The failing-commit test passed even when the bug returned. (b) A stray byte in a brief hid a secret from the checker under a UTF-8 locale, and the error message echoed it. (c) The pathspec `.` made the git commands depend on the current folder, and the porcelain output format was described wrongly. (d) The dirty-tree rule disagreed between files and could not be applied to a section of `AGENTS.md`. (e) The safe-checks test had a vacuous branch, and the confirmation did not say the build runs the project's own code. (f) This file described wording that had changed. | `check-brief.sh` sets `LC_ALL=C`. `update-mode.md` runs git from the repository root, describes the `XY path` output and `-z`, and says how to tell whether `AGENTS.md` changed outside its contract section. The failing-commit test now fails the second commit and was checked against a builder that swallows the error. Declined: making a long identifier with a digit a warning in R6 (you approved the rule; see the review notes). |
| 7 | Steps 6a, 6b and 6c (round 2) | Flow step 4 says "before any file is written". Three headless agents read this as impossible, because the drafted text is not yet a file. They wrote the pack, then ran the checks. | `SKILL.md` Flow step 4 adds: run the commands on the values in your draft, one value at a time; no file is needed for this; if the draft is only in your head, check each value as you write it down. `test_skill_checks_paths_and_terms_itself` extended first, and seen to fail. No agent run was repeated. |
| 8 | A real mobile project run (the first real mobile create run) | The checker failed R9. A `Pattern:` line note held a second backticked word, and R9 read it as a path. | Both templates say only paths are backticked on `Open:` and `Pattern:` lines and in the two path columns. Test added first. |
| 9 | Code review by Opus | R6 flagged long code identifiers, such as the exact names in `feature-to-code.md` (for example `GetCustomerOrderSummaryForPeriod2024`), because they are 32 or more characters and hold a digit. | A plain identifier (letters, then at most four trailing digits) is not a secret, in the R6 scan and in `looks_secret`. Hex, base64-like tokens, digits in the middle and five or more trailing digits still fail. This reverses the decision declined in iteration 6, after the engineer's approval on 2026-10-30. Tests added first; the two that covered the identifier were seen to fail. One older test string (letters then 12) became a plain identifier, so it now has its digits in the middle. |

No agent run was repeated after iterations 5, 6 and 7. The round 1 results describe the skill as it was after
iteration 4. The changes since then are covered by tests, not by new runs.
