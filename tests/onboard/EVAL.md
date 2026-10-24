# Evaluating agentd-onboard on the Shop fixture

How to check that the skill works, and the results of each run. The fixture is a synthetic project, so
nothing here touches a customer repository. Every run uses its own throwaway folder in the system temp
folder, and nothing is deleted.

Scoring uses `expected-facts.md`. For each of the eight questions:

- **pass:** every listed fact is present, or is marked `unknown:` with who to ask.
- **partial:** some facts are present and the rest are missing without a marker.
- **fail:** a listed fact is wrong, or the answer is missing with no marker.

The six traps at the end of `expected-facts.md` are scored separately as T1 to T6.

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
   `tests/onboard/check-brief.sh <fixture>/docs/onboarding`. Pass = exit 0 and no secret value anywhere in
   the pack.
3. **Fresh reader.** Give another fresh agent the brief from step 2 and the eight questions, with no
   tools. Score its answers. Pass = every question is a pass or a marked gap.
4. **No-op.** Run the skill again on the same fixture, unchanged. Pass = no file in the fixture changes
   (compare file checksums before and after, and `git status`).
5. **Update.** Build a v2 fixture. Copy the step 2 pack into it as `docs/onboarding/`, so the pack's scanned
   commit is the v1 commit, which is in the v2 history. Run the skill. Pass = the cancel use case and
   `net9.0` appear marked `changed:`, `Scanned commit` moves to the v2 commit, and the sections that
   cite no changed file (`Purpose and users`, `Data model`) are byte-for-byte the same. In a section that
   cites a changed file, only the facts the change touches and the `path:line` citations may differ. This
   narrows the plan's "unrelated sections untouched": update mode re-checks any section whose `Sources:`
   names a changed file, so a section is only unrelated if it cites no changed file. Update mode also goes
   one step beyond the plan's "re-check only sections whose `Sources:` changed": a changed path that no
   `Sources:` line names is mapped to the section it belongs to, so that a new file is not missed.
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

## Prompts

**Baseline prompt** (step 1). Nothing else is given.

```
Write an onboarding brief for this project, for an engineer who is new to it. The project is the git
repository at <FIXTURE>. Write the brief to <FIXTURE>/docs/onboarding/README.md. Work alone: nobody can
answer questions. Only read inside <FIXTURE>. Do not commit.
```

**Skill prompt** (steps 2, 4, 5, 6).

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

**Reader prompt** (step 3). The brief is pasted in. The agent has no tools.

```
You are a brand-new engineer. Below is the only document you have about a project. Answer the eight
questions using only this document. If the document does not say, write "not in the document". Do not
guess. For each answer, give the section you used.
<the eight questions from SKILL.md>
<the brief>
```

## Results

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

No agent run was repeated after iterations 5 and 6. The results above describe the skill as it was after
iteration 4. The changes since then are covered by tests, not by new runs.
