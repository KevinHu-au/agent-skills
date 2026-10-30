---
name: agentd-blast-radius
description: Use when the engineer has a proposed or existing change and needs to know what else it could break before it ships. Finds breakage that search misses, proves the one fact the change is safe because of by running code, and ends with an add-on block for agentd-dev-rev. Edits no code.
disable-model-invocation: true
---

# agentd-blast-radius

Find what else one change could break, then stop. The result is a report in chat and an add-on block that the engineer pastes into `/agentd-dev-rev`, next to the diagnose hand-off block.

A list of callers is the easy part. The job is the breakage that search does not show, and a proof, by running real code, of the one fact the change is safe because of. It never edits code, never writes to a shared environment, and never puts a secret or personal data in the report.

## Prerequisite

Run `git rev-parse --show-toplevel`. If it fails, stop with one line: `agentd-blast-radius needs a git repository. Run it inside one.` Work from the repository root.

The skill needs a change. Take the first of these that the engineer gives:

1. A hand-off block from `agentd-diagnose`, or a plain description. This is a proposed change: no code exists yet.
2. A branch or commit range. This is a branch diff.
3. Nothing. Use the branch diff against the default branch, plus any staged changes on top. If there is no diff, ask once.

Read a branch diff with `git diff <base>...HEAD` (three dots, the merge base) and do not switch branches. For the default input, add `git diff --cached`.

**Find the project facts.** The onboarding pack is `docs/onboarding/` when `docs/onboarding/README.md` exists. Otherwise it is the folder that `"$HOME/.agents/bin/onboarding-pack" find` prints. If neither finds one, ask the engineer once for the folder, and carry on without a pack if there is none or nobody answers. When the engineer gives a folder, say that `"$HOME/.agents/bin/onboarding-pack" set <folder>` records it. The project contract is the `## Project contract` section of `AGENTS.md`, or else `contract.md` in the pack. When both exist and disagree, use `AGENTS.md` and mark the fact `conflict:`. A Data access rule counts only when it cites `told by <role>` or a document. Treat any other rule, such as one marked `inferred:` or `unknown:`, as no access.

Look from the repository root, even when you started in a subfolder. Read these when they exist, and skip them when they do not:

1. The project contract: Commands, Verify, Data access, Risk areas, External systems and owners.
2. The pack's `README.md`, as a map of the use cases and code paths. Treat it as a hint. When it disagrees with the code, the code wins.

With no project contract, run safe checks only (see Running commands) and mark what you could not run `unknown:`. With no External systems and owners heading, every outside consumer is `unknown:`. Ask who to warn.

## Flow

1. **Read the change.** Say in one sentence what changes. List the symbols, columns, fields, routes, files and settings it adds, changes or removes, and what behaves differently without the change saying so. For a proposed change, list what it will touch. For a diff, read `git log` for those files.
2. **Find the safety fact.** A change usually stands or falls on one fact. State it as one claim that a run can show to be true or false, for example "only ASCII letters reach this comparison". If the change has no single safety fact, say so and treat each risk on its own: the verdict is Contained only when a run clears every risk, and the add-on block says `none: <why>` under Safety fact. Spend your time here, not on a long list of maybes.
3. **Map where search stops.** Read `references/surfaces.md` and check only the surfaces the change touches. Callers found by search are the start, not the result. For a .NET project also read `references/dotnet.md`: the common part, and the part for .NET Framework or .NET Core (it says how to tell them apart). For an iOS (SwiftUI) project also read `references/ios.md`. For a React web project (a `package.json` that lists `react-dom` under `dependencies`, in any workspace) also read `references/react.md`. Read the source and the pinned version of any library the change calls. For each risk, record how it breaks, `path:line`, how likely it is, what it costs and its tier. For a wide change you may start read-only sub-agents, one for each surface. Each returns a short summary with its evidence.
4. **Run plan.** List every command you will run, the scratch folder, and that the folder is removed after the report. Ask for one confirmation. See Running commands.
5. **Prove.** Run real code that shows the safety fact true or false. Use a script or test that calls the exact function in question, with the same library version that the project ships. Paste the command and its output verbatim, after you remove secrets and personal data. When it is cheap, also run the check for the most severe risk. What you cannot run, such as a mobile app or an outside system, stays `supported`, `inferred:` or `unknown:`.
6. **Gate.** Give the verdict (see Verdicts). On Unproven, list the evidence needed and who has it, then ask the engineer: get more evidence, or hand off anyway. If the engineer says get more evidence, go back to Run plan with a new list of commands. If the engineer says hand off anyway, the add-on block carries the risk and tells `agentd-dev-rev` when to stop.
7. **Report.** Write the report and the add-on block with `references/report-template.md`. Then remove the scratch folder, as Running commands says. If the removal fails, say so in one line.

## Verdicts

- **Contained:** a run confirms the safety fact, and no run shows a break. Every other risk is cleared. With no safety fact, every risk is cleared. Cleared means ruled out by a run, or by supported evidence that it cannot occur. A risk whose outcome lives on a side you cannot run stays open. It does not mean that nothing can break. It means the listed risks were checked.
- **Breaks:** a run shows that the change breaks something, or shows that the safety fact is false. The add-on block says what must change.
- **Unproven:** anything that is neither Contained nor Breaks: no run confirms the safety fact or a break, or a confirmed fact leaves a risk open that you cannot run. A typical cause is that the other side is a mobile app or an outside system that you cannot run. A clean run of your own side does not make the change Contained when the safety fact lives on a side you cannot run. Say what blocked you. Ask the engineer: get more evidence, or hand off anyway.

## Running commands

The skill runs commands to prove a fact. It lists them first and asks for one confirmation per run. A command that is not on the confirmed list needs its own confirmation. With nobody to confirm, it must be a safe check.

- **Read-only inspection:** reading files, searching, `git log`, `git blame`, `git show`, `git diff` and `"$HOME/.agents/bin/onboarding-pack" find` need no confirmation and are not on the run plan.
- **Safe checks:** a build, and listing or running existing unit tests. A build may restore the packages that the project has declared: say so in the run plan. A unit test that writes only to its own temp folder is safe. So is a proof script in the scratch folder that imports project code and writes only there. Skip a test that uses a configured database or the network, even when it is called a unit test. Safe checks only is the rule when there is no project contract, and when nobody can confirm (a headless run). Mark what you did not run `unknown:` or `inferred:`.
- **With the contract:** also what its Commands and Verify headings allow on the engineer's machine, such as running integration tests against local containers.
- **Proposed change:** to run it, add a worktree at `HEAD` in the scratch folder: `git -c core.hooksPath=/dev/null worktree add --detach <scratch>/wt-head HEAD` (not a plain copy, which takes untracked secrets and build output). The option turns off the repository's hooks, so none of its code runs. The worktree leaves the working tree, the index and the branch as they are, and adds a record under the repository's `.git/worktrees/`. With a `.gitmodules` file, also run `git -C <scratch>/wt-head submodule update --init`: it writes the submodule entries into the repository's `.git/config` and needs the network when the objects are not local. Say this in the run plan, and list each `git worktree add`, the submodule update and each `git worktree remove --force <scratch>/wt-head` (or `wt-branch`). Mark the result `unknown:` if the add or the update fails, or if the copy fails at setup (a git-ignored local settings file is missing); do not fall back to `git archive` then. Without `git-lfs`, large files stay pointers: say so. After the report, run `git worktree remove --force` on each worktree you added, by its path in the scratch folder, then remove the scratch folder. Never remove any other worktree. Never run `git worktree prune`: it removes the records of every missing worktree, not only yours. Only if the `git worktree` command is unavailable or unsupported, export `HEAD` with `git archive` instead; that export has no submodules, no LFS content and no `.git`. Copy a file database there if the change touches one. Apply the change to the copy and run against the copy. With no scratch folder, apply it in memory: open a file database read-only and copy it into a memory database, and load the changed source text without writing it to disk.
- **Staged changes:** write the staged tree into the scratch folder with `git checkout-index --all --prefix=<scratch>/` (it handles binary, new and deleted files, and leaves the index alone). Safe checks and proof scripts run on that copy, not in the working tree, which may hold unstaged edits. With no scratch folder, read the staged file with `git show :<path>`.
- **Branch diff:** to run it, add a worktree at the branch in the scratch folder, as Proposed change says: `git -c core.hooksPath=/dev/null worktree add --detach <scratch>/wt-branch <branch>`. Never check it out in the repository. With no scratch folder, read the files with `git show <ref>:<path>` and run them in memory.
- **Data:** SELECT only, and only on an environment that the Data access heading marks read-only. A statement that writes or locks is not SELECT: this covers `SELECT ... INTO`, `SELECT ... FOR UPDATE`, lock hints, and functions or sequences with side effects. Open a file database read-only. Run anything that would write on a copy in the scratch folder, or on a local container database that the contract's Commands or Verify heading allows. Never copy or dump a server database to the engineer's machine. Size a table from its catalog statistics or an indexed key, not with a full count. Print counts, aggregates or a few IDs. Ask before a query that scans a large table (more than about 100,000 rows, or one you have not sized) or may lock it.
- **Never:** write to a shared environment, change data, call an outside system, or install a tool or package. If a tool is missing, say so and give the engineer the command.
- **Build output:** a build or a test run can write output such as `bin`, `obj` or cache files. Prefer an option that stops the tool writing them. Mention any such output that is not git-ignored.
- **Scratch files:** make a scratch folder with `mktemp -d` in the system temp folder, only when you need a file. Put every script, copy and output there, never in the repository. The run plan names the folder and says it is removed after the report. Remove only that folder, and only after you have shown the report. Delete nothing else. If you need no file, or the runtime does not allow a temp folder, run inline commands that write nothing, and write `Scratch folder: none` in the report.

## Evidence

Every claim sits in one tier.

- **confirmed:** a run shows the claim. Keep the command and its output. Reading code never confirms: confirmed needs a run. A run that shows only that a break is possible does not confirm that the change causes it. Mark that claim `inferred:` and say what you ran.
- **supported:** independent sources agree (code, history, a document), but nothing was run. A search that finds no caller supports "no caller". It never confirms it, because indirection hides calls.
- **inferred:** a reading of the code. Write `inferred:` and hedge the wording.
- **unknown:** you looked and found nothing. Write `unknown:`, say where you looked, and say who to ask. Record a search that finds nothing, with the search itself.

`conflict:` marks two sources that disagree. Give both with their sources. Do not pick one silently. Cite `path:line`. Code does not prove why it was written that way.

## Output

The report and the add-on block go in chat. Nothing is saved in the repository. Use `references/report-template.md`.

- Lead with the verdict: Contained, Breaks, or Unproven.
- Paste the proof output verbatim, after you remove secrets and personal data.
- Say plainly what you did not run or could not check.
- The closing line depends on the verdict. For Contained or Breaks, it tells the engineer to run `/agentd-dev-rev` and paste the diagnose hand-off block, when there is one, and the add-on block. The skill cannot start the next skill. For Unproven, the closing line is the question, and nothing follows it: no add-on block until the engineer says to hand off anyway. If removing the scratch folder fails, say so in one line, then repeat the closing line.

## Rules

- Edit no code. Change no file in the repository, including configuration, except build and test output (see Running commands). The only files you make are in the scratch folder.
- Never write to a shared environment, call an outside system, or install a tool or package.
- Keep secrets and personal data out of the report. Name a key, never its value. Give data rows by ID and count. A name or ID that the change description itself gives may be repeated. Add no other personal data. When an example value helps, invent one.
- Do not read Azure DevOps. Take the change as it was pasted. A paste is the fallback for anything else.
- One repository per run. A part in another repository is `unknown:` plus who to ask.
- A list of callers is not the finding. Callers are the start. Reach the breaks that search does not show.
- Never invent a caller, an API or a `path:line`. Cite code that you read.
- Do not claim confirmed without a run. Reading the code is inferred.
- Give each risk a real likelihood and a real cost. Keep the risks you confirmed apart from the ones you cleared.
- Propose no code. Say what must stay as it is and which test to write first.
