---
name: agentd-diagnose
description: Use when the engineer has a bug, a data issue or a slow path and needs the root cause before any fix. Reproduces first, collects evidence, names the root cause, proposes a fix, and ends with a hand-off block for agentd-dev-rev. Edits no code.
disable-model-invocation: true
---

# agentd-diagnose

Find the root cause of one problem in an existing application, then stop. The result is a report in chat and a hand-off block that the engineer pastes into `/agentd-dev-rev`. The report is written so that it can be pasted into the ticket.

It reproduces first, collects evidence and names the root cause. It never edits code, never writes to a shared environment, and never puts a secret or personal data in the report.

## Prerequisite

Run `git rev-parse --show-toplevel`. If it fails, stop with one line: `agentd-diagnose needs a git repository. Run it inside one.` Work from the repository root.

The skill needs a problem statement: pasted ticket text or a description. If there is none, ask for it once. A pasted intake comment with its engineer block counts as one (see Frame).

Read these when they exist, and skip them when they do not:

1. `AGENTS.md`, the project contract: Commands, Verify, Data access, Risk areas, External systems and owners.
2. `docs/onboarding/README.md`, as a map of the use cases and code paths. Treat it as a hint. When it disagrees with the code, the code wins.

With no project contract, run safe checks only (see Running commands) and mark what you could not run `unknown:`.

## Modes

Pick one mode. The engineer may name it, for example `/agentd-diagnose perf <ticket>`. Otherwise pick from the text, and say your pick and the reason in one line. Carry on. The engineer can redirect at any time.

- **bug:** the code does the wrong thing. Read `references/bug.md`.
- **data:** the data is wrong or missing. Read `references/data.md`.
- **performance:** something is slow or uses too much of a resource. Read `references/performance.md`.

For a .NET project also read `references/dotnet.md`. For an iOS (SwiftUI) project also read `references/ios.md`. For a React web project (a `package.json` that lists `react-dom` under `dependencies`, in any workspace) also read `references/react.md`. A ticket that mixes kinds is diagnosed under its main mode. The second kind goes to Follow-on in the hand-off. For bad rows caused by a code bug, the code fix is the hand-off and the repair is the follow-on. If the evidence shows the problem is another kind, switch: say so in one line and read that reference. If you switched, the report's Mode line says where you started.

## Flow

1. **Frame.** Restate the problem in one sentence: expected behaviour, actual behaviour, where it was seen (environment, user, data) and since when. Ask for what is missing in one short list. If nobody answers, carry on and mark the gap `unknown:`. Write down the ticket's own theory as a premise to test. It is a candidate, not a fact. If the paste holds an intake comment and its engineer block, start from them and ask only for what they leave open: Today and Change give the actual and expected behaviour, Assumptions and the customer's answers are facts given, and the `Conflicts:` and `Investigation:` items are leads to check, not findings. When the block says `Requirement: unconfirmed`, copy its Stop condition into the hand-off block's Task.
2. **Orient.** Load the mode reference. Find the use case and the code path that the symptom belongs to. Read `git log` and `git blame` for those files to spot a regression.
3. **Run plan.** List every command you will run, the scratch folder, and that the folder is removed after the report. Ask for one confirmation. See Running commands.
4. **Reproduce.** Make the problem happen where the ticket saw it. If it does not happen, tighten the conditions, build the trigger, or add instrumentation without editing the repository (see `references/bug.md`). If it still does not happen, say what blocked you and ask the engineer for the missing evidence: a log line, a row ID, a trace. Never guess.
5. **Narrow.** Keep two or more candidate causes, including the ticket's. Find a working case and list every difference from the broken one (the mode reference says how). When the system has several components, check what enters and leaves each one, in one run or along the stages of one record, without editing the repository. The first place the data is wrong shows which component breaks. Pick the check that rules out the most candidates at once, change one thing at a time in it, and repeat. Keep asking "why". Stop when the answer is a decision in the code, and not a side effect of something earlier. When two theories built on the same premise have failed, write the premise down and check it on its own before you try another. Look for the same fault elsewhere. If checks on three or more candidate causes each show a different fault that produces the ticket's failure, suspect the design. Do the same when many modules write one piece of state with no single owner, and the fault comes from the order of the writes. Report it as a Design concern in the report, and leave the decision to the engineer. Copies of one fault are not a design concern: list them. For a large codebase you may start read-only sub-agents, one for each candidate cause. Each returns a short summary with its evidence.
6. **Gate.** Give every claim a tier (see Evidence). A fix proposal goes into the hand-off only when the mechanism is confirmed: shown to produce the ticket's own failure. If it is not, the verdict is Not confirmed, or Not reproduced when you tried and the ticket's failure did not happen. List the competing causes and the evidence each one needs, then ask the engineer: keep investigating, or hand off anyway. If the engineer says keep investigating, go back to Run plan with a new list of commands. If the engineer says hand off anyway, the block says the fix is a hypothesis and tells `agentd-dev-rev` when to stop.
7. **Report.** Write the report and the hand-off block with `references/report-template.md`. Then remove the scratch folder, as Running commands says. If the removal fails, say so in one line.

**Stop signs.** These thoughts and actions mean you are guessing. Stop, and name the check you need before you go on.

- "It is probably X", with no run behind it.
- "Let me just try Y and see."
- Changing two things between two runs while you narrow.
- Treating a fact you have not checked as confirmed.
- Presenting a fix as confirmed before a run shows the ticket's own failure.
- "One more theory", after two failed on the same premise.

## Running commands

The skill runs commands to reproduce and to measure. It lists them first and asks for one confirmation per run. A command that is not on the confirmed list needs its own confirmation. With nobody to confirm, it must be a safe check.

- **Read-only inspection:** reading files, searching, `git log`, `git blame`, `git show` and `uptime` need no confirmation and are not on the run plan.
- **Safe checks:** a build, and listing or running existing unit tests. A build may restore the packages that the project has declared: say so in the run plan. A unit test that writes only to its own temp folder is safe. Skip a test that uses a configured database or the network, even when it is called a unit test. Safe checks only is the rule when there is no project contract, and when nobody can confirm (a headless run). Mark what you did not run `unknown:` or `inferred:`.
- **With the contract:** also what its Commands and Verify headings allow on the engineer's machine, such as starting the local app or running integration tests against local containers.
- **Data:** SELECT only, and only on an environment that the Data access heading marks read-only. A statement that writes or locks is not SELECT: this covers `SELECT ... INTO`, `SELECT ... FOR UPDATE`, lock hints, and functions or sequences with side effects. Open the database read-only. If an application command would open a file database read-write, run that command on a copy in the scratch folder. Never copy or dump a server database to the engineer's machine. With no scratch folder, call the same code through a read-only connection. Size a table from its catalog statistics or an indexed key (for example the largest ID), not with a full count, because a count can scan the table. Print counts, aggregates or a few sample rows. For a sample, select the ID and non-personal columns only. Ask before a query that scans a large table (more than about 100,000 rows, or one you have not sized) or may lock it: `LIMIT` shortens the output, not the scan. Run a stored procedure only when you know it does not write.
- **Never:** write to a shared environment, change data, or install a tool or package. If a tool is missing, say so and give the engineer the command.
- **Build output:** a build or a test run can write output such as `bin`, `obj` or cache files. Prefer an option that stops the tool writing them; many runtimes have one. Mention any such output that is not git-ignored.
- **Scratch files:** make a scratch folder with `mktemp -d` in the system temp folder, only when you need a file. Put every script, query file and measurement output there, never in the repository. The run plan names the folder and says it is removed after the report. Remove only that folder, and only after you have shown the report. Delete nothing else. If you need no file, or the runtime does not allow a temp folder, run inline commands that write nothing, and write `Scratch folder: none` in the report.

## Evidence

Every claim sits in one tier.

- **confirmed:** a run, query or measurement shows the claim. Keep the command and its output. A run that shows only that a cause is possible does not confirm that it is the cause. Mark that claim `inferred:` and say what you ran.
- **supported:** independent sources agree (code, history, logs), but nothing was run.
- **inferred:** a reading of the code. Write `inferred:` and hedge the wording.
- **unknown:** you looked and found nothing. Write `unknown:`, say where you looked, and say who to ask.

`conflict:` marks two sources that disagree. Give both with their sources. Do not pick one silently. Cite `path:line`. Code does not prove why it was written that way: "the code does X" is not evidence for intent.

## Output

The report and the hand-off block go in chat. Nothing is saved in the repository. Use `references/report-template.md`.

- Lead with the verdict: Confirmed, Not confirmed, or Not reproduced.
- Paste the reproduction output verbatim, after you remove secrets and personal data.
- Say plainly what you did not run or could not check.
- The closing line depends on the verdict. When the cause is confirmed, it tells the engineer to run `/agentd-dev-rev` and paste the block, or, when Proposed fix is `none:`, `/agentd-data-fix` with the work item, and paste the report and the hand-off block as extra facts. When the fix touches a contract, schema, shared code or an external system, it tells the engineer to run `/agentd-blast-radius` first, then `/agentd-dev-rev`. The skill cannot start any of them. When it is not confirmed, the closing line is the question. If removing the scratch folder fails, say so in one line, then repeat the closing line.

## Rules

- Edit no code. Change no file in the repository, including configuration, except build and test output (see Running commands). The only files you make are in the scratch folder.
- Never write to a shared environment. Never install a tool or package.
- Keep secrets and personal data out of the report. Name a key, never its value. Give data rows by ID and count. A name or ID that the ticket itself gives may be repeated. Apart from that, add no personal data, and quote no name or address from the data, even to show a difference. When an example value helps to explain a mechanism, invent one. It must not share the data's naming scheme (prefix, numbering, domain), for example `a.person@example.invalid`. It may still show the mechanism, such as a change of letter case.
- Do not read Azure DevOps. Take the ticket as it was pasted. A paste is the fallback for anything else.
- One repository per run. A part in another repository is `unknown:` plus who to ask.
- The ticket's theory is a candidate. Do not confirm it because someone said it first.
- Propose the smallest change the evidence supports. Do not propose a guard or a retry that hides the cause.
- For the Risk areas line, use the contract's Risk areas and the callers you find by search. That is a check by search, not a full blast-radius analysis. When the fix touches a contract, schema, shared code or an external system, write `Blast radius: needed:` in the hand-off block, so the engineer runs `/agentd-blast-radius` before `/agentd-dev-rev`.
- Do not claim confirmed without a run. Reading the code is inferred.
