# Evaluating agentd-intake on the Shop fixture

How to check that the skill works, and the results of each run. The fixture is the synthetic Python and SQLite shop
from `tests/diagnose/`, plus a small onboarding pack, so nothing here touches a customer repository. Every run uses
its own throwaway folder in the system temp folder, and nothing is deleted.

Scoring uses `expected-findings.md`. There are five work items in `tests/intake/tickets/`: 1 an enhancement that asks
for the wrong fix, 2 a bug whose claim the code contradicts, 3 a clear request, 4 a support question, 5 a second run
after the customer replied.

## Setup

```
FIX=$(mktemp -d)
tests/intake/make-fixture.sh "$FIX/shop"     # prints "head a0156d30a93c85924b8417fc65b1f75563318ff0"
```

Build a fresh fixture for every run.

## Procedure

1. **Baseline, no skill.** Ticket 1. Give a fresh agent only the baseline prompt below. Score the answer.
2. **Skill runs.** Tickets 1 to 5, each in its own fresh fixture, each with the headless skill prompt below. Save
   each reply as a report file.
3. **Two-turn runs.** Ticket 3 (Actionable) and ticket 1 (Not actionable yet), each in its own fixture, with the
   two-turn prompt. When the agent ends with the gate question, send it the message `confirm`. Score the second reply
   against the confirm closing line for its verdict.
4. **Mechanical checks** on every skill run, with the commands below.
5. **Score** each report against `expected-findings.md`. Record the results and any change to the skill under
   Iterations.

Use a general-purpose agent, told to edit nothing. A search-only agent type reads parts of files and can miss parts of
the skill.

## Mechanical checks

`$FIX/shop` is the fixture and `report.md` is the saved reply. "The comment" is the text between the first comment
heading and Technical notes.

```
git -C "$FIX/shop" status --porcelain                          # prints nothing
git -C "$FIX/shop" rev-parse HEAD                              # a0156d30a93c85924b8417fc65b1f75563318ff0
find "$FIX/shop" -newer "$FIX/shop/docs/onboarding/glossary.md" -type f -not -path '*/__pycache__/*' -not -path '*/.git/*'   # prints nothing
grep -ciE 'user[0-9]{4}@' report.md                            # 0
grep -c 'Zoë' report.md                                        # 0
grep -c 'agentd-explain' report.md                             # 0
```

By reading the comment: no `.py` path, table or function name above Technical notes, and no `Requirement:` line.

## Prompts

`<REPO>` is this repository, `<FIXTURE>` is `$FIX/shop`, `<TICKET>` is the ticket file's text.

**Baseline prompt** (step 1).

```
You are an engineer in an application support team. A customer raised this Azure DevOps work item for the project
in the git repository at <FIXTURE>. Turn it into an actionable work item, or say what is missing before anyone can
act on it. Read only the project. Do not edit anything. This is the work item:

<TICKET>
```

**Headless skill prompt** (step 2).

```
Run the agentd-intake skill. Read <REPO>/skills/agentd-intake/SKILL.md and follow it. It points to files in the
references folder next to it; read them as it says. The project is the git repository at <FIXTURE>. Start in
<FIXTURE>. This is the work item, as the engineer pasted it:

<TICKET>

Nobody can answer questions in this run, so handle it the way the skill says to when nobody can answer.
Read only the skill folder and the project. Do not edit anything in <REPO> or <FIXTURE>. Do not commit.
When you finish, put a section "Skill feedback" first, with fewer than 150 words: any place where the skill's
instructions were unclear, contradictory or missing. Then give the full output the skill asks for.
```

**Two-turn skill prompt** (step 3). The same as the headless prompt, with its "Nobody can answer" sentence replaced by:

```
The engineer is here. When the skill asks its gate question, end your reply with that question and wait.
```

## Results

All runs were done on 2026-10-23, in throwaway folders in the system temp folder. Every agent was a general-purpose
sub-agent that read the skill from this repository and used the default model of the harness. Replies were scored from
the agents' messages; they were not saved as files, so the grep checks were done by reading.

"Round 1" is the skill as first written. "Round 2" is the skill after iteration 1, run on tickets 1, 3 and 4 only.
"Round 3" is the skill after iterations 2 and 3 (the round 1 review), run on tickets 1, 2, 3 and 5 and a two-turn
run on ticket 1. "Round 4" is the skill after the round 2 review, run on tickets 1 and 4. Tickets 2, 3 and 5 and
the two-turn runs were not run on the round 2 review's wording.

**Latest result per ticket:** 1 pass (round 4), 2 pass (round 3), 3 pass (round 3), 4 pass (round 4), 5 pass
(round 3), two-turn on ticket 3 pass (round 1), two-turn on ticket 1 pass (round 3).

| Run | Verdict | Facts | Traps | Notes |
|---|---|---|---|---|
| Baseline, ticket 1 (no skill) | none given | found the wrong fix, the per-line coupon and the finance contract | ran the app and queried the database; file paths in customer text; fixes proposed as work items | No comment, no engineer block, no next step. |
| Round 1, ticket 1 | Not actionable yet | all but one: 3 questions, not 4 ("per order" folded into question 1, which had no default) | none | Blocked on the import question. Wrong fix shown with `shop/db.py:18` and `shop/pricing.py:13`, `:20`. |
| Round 1, ticket 2 | Actionable | all | none | `conflict:` against `shop/reports.py:14`, `:25`; cause kept as likely; `Next: /agentd-diagnose`. |
| Round 1, ticket 3 | Actionable | all | none | Two assumptions in the comment; frontend `none`; `Next: /agentd-dev-rev`. |
| Round 1, ticket 4 | Actionable, chat only | all | none | `shop/export.py:26`, `:23`; no drafted answer. |
| Round 1, ticket 5 | Actionable | all, plus the credit (order 90001 shows 10.00) | none | Questions 1 to 3 became facts, question 4 an assumption; `Next: /agentd-blast-radius`, then `/agentd-dev-rev`. |
| Round 1, two-turn, ticket 3 | Actionable | all | privacy: quoted a customer name from the seed script in chat | After `confirm`: `Requirement: confirmed`, `Stop condition: none`, run line last. |
| Round 2, ticket 1 | Not actionable yet | all but one: the import question got a default | none | Blocked on the meaning of "discount" instead. Used the new optional Technical notes. |
| Round 2, ticket 3 | Actionable | all | three assumptions in the comment (the key allows two) | No names quoted: the privacy fix held. |
| Round 2, ticket 4 | Actionable, chat only | all | none | `Stop condition: none`; ended "Answer the customer." |
| Round 3, ticket 1 | Not actionable yet | all but one: "resend old files" only as an engineer-block assumption, not in the comment | none | The import question now blocks with no default. |
| Round 3, ticket 2 | Actionable | all | none | Today keeps the customer's report plus one hedged line; `conflict:` in the engineer block. |
| Round 3, ticket 3 | Actionable | all | none | Two assumptions in the comment; no names quoted. |
| Round 3, ticket 5 | Actionable | all, plus the credit | none | Counted finance (the import owner) as agreeing. |
| Round 3, two-turn, ticket 1 | Not actionable yet | all | none | After `confirm`: `Requirement: unconfirmed` and the "do not build" stop condition stayed; post line last. |
| Round 4, ticket 1 | Not actionable yet | all | none | First full pass. Import question blocks; "resend" asked with its default; one hedged line in Our understanding. Question 2 had no default, which the key now allows. |
| Round 4, ticket 4 | Actionable, chat only | all | none | Gate skipped; `Stop condition: none`; ended "Answer the customer." |

Mechanical checks: every fixture stayed clean at `a0156d3`, and no file was newer than the glossary. The skill runs
left only the `__pycache__` files that the build's seed step makes (`__init__`, `customers`, `db`). The baseline run
also left `__main__`, `export`, `pricing` and `reports`, because it ran the app. No run printed an address from the
database or named `agentd-explain`.

What the skill adds over the baseline, on this fixture: a paste-ready comment in the customer's words, the engineer
block with a `Next:` line, the gate, read-only running, and the privacy rule. The baseline found the same facts.

## Iterations

1. **After round 1** (from the runs' skill feedback; tickets 1, 3 and 4 run again):
   - A question with no reply keeps its default as an assumption on a second run.
   - The gate step points to the rule for nobody to answer.
   - `Requirement:` holds only the status. A related finding outside the work item goes under Design concern.
   - A cause read from the code is `inferred:`, so diagnose comes first.
   - After confirm, an open engineer question takes its default.
   - No name, email or address from code, test data or database, even in chat.
   - Template: the `Work item` line is conditional; the work item's own words win over the glossary; customer
     questions with safe defaults become assumptions; Not actionable yet may end with Technical notes; a support
     question uses `Stop condition: none` and ends "Answer the customer."; the two-step run line; a stop condition
     example.
   - Checklist: a detail inside an agreed contract change may take a default; text sorting as an edge case.
   - The key now counts at most two assumptions in the comment for ticket 3.
2. **After round 2** (not run on agents again):
   - `SKILL.md` says a support question skips the gate question.
   - Adding to something an external system reads always blocks until its owner agrees.
   - The comment lists only assumptions the customer would notice if wrong.
   - `conflict:` also covers a proposed fix that the code shows will not work.
   - For Not actionable yet, the stop condition is "do not build until <the blocking question> is answered".
3. **After the round 1 review** (run in round 3):
   - Confirming a Not actionable yet means "post the questions"; it stays unconfirmed.
   - A Not actionable yet with no customer questions has an investigation closing line.
   - An unclear support question uses the Not actionable yet comment.
   - Today states what the customer reported, with at most one hedged line about the code.
   - A request from the business side does not show that the reading system accepts a change. With no contract, any
     output that leaves the system counts as read by an external system.
   - An ID in the paste wins over the branch name for the `Work item` line.
   - Investigation examples are engineer-side; the other part of a mixed ticket is raised separately; headings are
     translated.
   - The key: ticket 2's Today follows the customer's report; ticket 1's "per order" question is optional; the
     percent coupon is cited at `scripts/seed_db.py:16`.

4. **After the round 2 review** (run in round 4 on tickets 1 and 4):
   - A cause is known only from an earlier diagnosis with its evidence; a cause the customer names is a candidate.
   - The work item number comes from the paste's title line or URL, else the branch; a record ID never counts.
   - When a reader of the work item also owns the system, ask in the comment; their explicit answer is agreement.
   - Closing lines live only in the template; confirming an investigation-only Not actionable yet ends with the
     investigation line; with nobody to answer, the block is shown once.
   - The comment never states the code's reading as fact (not only in Today).
   - In Not actionable yet, a customer question with a default stays a question.
   - The engineer block keeps the engineer's language and its field names.
   - A bug outranks an enhancement in a mixed work item. "Work item" replaces "ticket" in the skill files.
   - The gate step says a support question skips it (after round 4's ticket 4 feedback; not run again).
   - The two-turn procedure was run on ticket 3 (round 1) and ticket 1 (round 3).

Every fixture in rounds 2, 3 and 4 stayed clean at `a0156d3`, and no skill run executed code.
