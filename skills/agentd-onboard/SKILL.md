---
name: agentd-onboard
description: Use when the engineer is onboarding to an existing project, taking over support for a customer application, or refreshing a project's onboarding pack. Writes one short brief, a project contract and side files in the onboarding pack, which is docs/onboarding/ or a folder outside the repository when the customer allows no file in it.
disable-model-invocation: true
---

# agentd-onboard

Learn an existing project in phases, then write one short brief, `README.md` in the pack folder (see Repo policy and the pack folder). A brand-new engineer reads the brief and can start a simple ticket. The brief covers the business (who uses the application, the typical use cases) and the technical picture (architecture, data, external systems, how to run and check a change). It leads from a feature to its code: the key concept, the first files in each layer, and how to search for the rest. It also writes the project contract, `contract.md`, next to the brief, so other skills can read the project's commands and rules. It never writes to `AGENTS.md`. When the brief already exists, this skill refreshes it.

It never writes to customer systems, never changes code, and never copies a secret value. Name the key only.

## Prerequisite

Run `git rev-parse --show-toplevel`. If it fails, stop with one line: `agentd-onboard needs a git repository. Run it inside one.` Work from the repository root, even when started in a subfolder. Run `git rev-parse HEAD`. If it fails, the repository has no commits: stop with one line: `agentd-onboard needs at least one commit.` The skill must run with no input at all: every question is optional, and with no answer it carries on as Flow says.

Check for a linked worktree: compare the output of `git rev-parse --path-format=absolute --git-dir` with that of `git rev-parse --path-format=absolute --git-common-dir`. The flag is needed because the common folder can print as a relative path from a subfolder. It needs git 2.31 or later; with an older git, resolve both paths with `cd` and `pwd -P`. If they differ, this is a linked worktree, and the repository root is the main checkout, not the worktree folder. Find the main checkout with `git worktree list --porcelain`: its first `worktree` entry. If that entry says `bare`, the main repository has no checkout to write to: stop with one line. Warn that output in a removed worktree is lost, then write to the main checkout, or ask which. If nobody can answer, write to the main checkout, and put the warning in your final reply and in `open-questions.md`. From then on, read the code, run git commands and write the pack in the main checkout, so the pack and the commit it records sit together. With the files policy `none` the pack sits outside every checkout, so the worktree check only sets where you read the code and run git.

## Repo policy and the pack folder

Customers differ in what they allow in their repository. Ask these two questions once per project, in Flow step 1, and record the answers in the brief header as the `Repo policy:` line. Other skills read that line instead of asking again.

1. Which tools does the customer allow: Claude Code, Copilot CLI, or both?
2. Which agent files may sit in the repository: committed, local only (in the working tree, never committed), or none?

The second answer sets the pack folder:

- **committed:** `docs/onboarding/` at the repository root. The engineer commits it through the normal pull request.
- **local only:** `docs/onboarding/`. Add the line `docs/onboarding/` to the file that `git rev-parse --git-path info/exclude` prints, unless that file already holds it. Do not edit `.gitignore`. An exclude line has no effect on files git already tracks: when `git ls-files docs/onboarding` prints anything, say so, and leave it to the engineer whether to stop tracking them. Never run that change yourself.
- **none:** a folder outside the repository. Propose the folder that `"$HOME/.agents/bin/onboarding-pack" suggest` prints: a name made from the repository's key and a short hash of it, so two repositories do not share it. The engineer may name another folder. If the folder exists and holds files, check whether it is this repository's lost pack: its `README.md` has the scan header lines and its `Scanned commit:` exists here (`git cat-file -e <commit>^{commit}`). If so, record it with `set` and use Update mode. Otherwise do not write into it: ask for another folder, and with nobody to answer, stop with one line. Create the folder, then record it with `"$HOME/.agents/bin/onboarding-pack" set <folder>`, so that other skills find the pack. `set` refuses a folder that another repository has recorded. If the script is missing or refuses, say so in one line, give the engineer the command, and carry on.

Write the line as `Repo policy: tools <Claude Code | Copilot CLI | both>; files <committed | local only | none>`. Write `unknown` for a part nobody answered, and list it in `open-questions.md`. With no answer to question 2, use `none` and the proposed folder, because it writes nothing into the repository. In the rest of this skill, the pack folder means the folder that this section chose or that Modes found.

## Modes

Find the pack first. It is `docs/onboarding/` when `docs/onboarding/README.md` exists at the repository root. Otherwise run `"$HOME/.agents/bin/onboarding-pack" find`: it prints the folder of a pack kept outside the repository. Exit 1 means none is recorded: use Create mode. If the script is missing (the shell reports it is not found), say so in one line, give the engineer `./install.sh --apply` from the agent-skills repository, and carry on as for exit 1. Exit 3 means the recorded folder is gone: say so, and ask whether to build a new pack or where the pack moved to; with nobody to answer, stop with one line and write nothing. Any other exit, such as 4 when the repository cannot be read, stops the skill with the script's message, and nothing is written.

- **Create:** no pack was found. First ask whether a pack for this repository already exists in another folder, for example after a move to a new machine. If the engineer names one that passes the lost-pack check under **none**, record it with `set` and use Update mode. Otherwise ask the questions in Repo policy and the pack folder, then build the pack.
- **Update:** a pack was found, and this skill wrote its `README.md`. Check it against the latest code and rewrite only what is outdated. Follow `references/update-mode.md` instead of Flow steps 2 to 4, except the path and term check in Flow step 4, which still runs on every block you touch. Ask the optional questions only when an `unknown:` from the last run may now be answerable. A pack with no `Repo policy:` line is from an older version: ask the two questions once and add the line. With no answer, write `unknown` and leave the pack where it is. Never move or delete a pack. When the answer does not fit where the pack sits, say so and act as follows. `none` with the pack in `docs/onboarding/`: stop, write nothing, and ask the engineer to move the pack out of the repository and run this skill again. `local only` with a pack in `docs/onboarding/`: follow the **local only** rule in Repo policy. It adds the exclude line once, and says so when git already tracks the pack. `committed` or `local only` with the pack outside the repository: keep it there and record the answer. Show the engineer any new or changed use case. Run the check in Flow step 5 (the nine questions) on the sections you changed.

If `docs/onboarding/README.md` exists but was not written by this skill (it has none of the three scan header lines and no `## First-ticket checklist` heading), stop with one line: `docs/onboarding/README.md exists and was not written by agentd-onboard. Move it, or say where to write the pack.` Do not change it.

## Flow

1. **Ask the optional questions.** In Create mode, the two repo policy questions first. Then handover notes, what the engineer already knows, DevOps facts. Every question is optional. If nobody answers, carry on.
2. **Explore.** Start one read-only sub-agent for each angle, in parallel: UI and routes; API and permissions; domain model and schema; data-flow tracer; integrations and dependencies; documentation and tests. Prompts, the report template and the synthesizer prompt are in `references/explorer-prompts.md`. If you cannot start sub-agents, run the angles one after another. Keep explorer output out of the main context: each report is bounded and one synthesizer merges them. A .NET project has `*.sln`, `*.csproj` or `*.vbproj` files, or is a Web Site project (a `web.config` with `*.aspx` or `*.cshtml` pages and no project file). An iOS (SwiftUI) project has a `*.xcodeproj` or `*.xcworkspace`, or a `Package.swift` whose sources import SwiftUI. A React web project has a `package.json`, in the repository or in any workspace folder, that lists `react-dom` under `dependencies`, or under `devDependencies` when the same file lists a bundler or dev server (`vite`, `webpack`, `next`, `react-scripts` or `parcel`) and has no `main`, `module` or `exports` field. A file that also lists `react-native`, a peer-only entry, or a dev entry that fails those conditions is a mobile app or a library, not a web project. A project, or a part of one, that matches none of these is a stack with no reference. For .NET projects also load `references/dotnet.md`: it says how to tell .NET Framework from .NET Core, and which rows fit each. For iOS (SwiftUI) projects also load `references/ios.md`. For React web projects also load `references/react.md`. For a stack with no reference, the explorers work from the code alone, mark every fact `inferred:`, and ask the engineer for what the code does not show. For external systems follow `references/external-systems.md`.
3. **Show the drafts.** Show the drafted use cases and journeys, with the key concept chosen from the explorer reports. Ask the engineer to correct them. A draft works better than a blank question. If there is no answer, carry on: write the use cases as `inferred:` and put them first in `open-questions.md`.
4. **Write.** Write the brief with `references/brief-template.md`. Write `feature-to-code.md` with `references/feature-to-code-template.md`. Write `contract.md` with `references/contract-fill.md`. Add side files only when a section outgrows its share. Then check the drafted text with read-only commands from the repository root, before any file is written. Run the commands on the values in your draft, one value at a time; no file is needed for this, and if the draft is only in your head, check each value as you write it down. Count lines with `awk 'END { print NR }'`, not `wc -l`, so a last line without a final newline counts. Every path (the `Open:` and `Pattern:` lines, and the two path columns) must exist by `test -e <root>/<path>`. A folder passes only without `:N`. An untracked file passes. For `:N` or `:N-M`, the file must have at least that many lines. Read values this way: strip a leading `./`; skip cells that start with `none` as a whole word, `unknown:` or `inferred:`, and a `changed:` prefix is read through; read only backticked values. A term goes to `git grep` as one quoted argument, so write a single quote inside it as `'\''` in the shell. Every search term in a Search terms table must be found outside the pack by `git grep --untracked -F -q -- '<term>' -- . ':(exclude)docs/onboarding'`. The pack is excluded because, once it is committed, every term would match inside `feature-to-code.md` and the check would prove nothing. Never check `Run:` lines or Business term cells. Fix a miss before the pack is written. Mark a miss that cannot be fixed `unknown:`.
5. **Check.** Check the brief against the nine questions under Output. List every gap in the brief and in `open-questions.md`.

## Safe checks

You may run safe checks, with one confirmation per run. List the commands first, then ask once.

- Allowed: a build, and listing or counting unit tests.
- Never: start the app, run integration tests, run DbUp or migrations, or touch a database or a network service. The one exception is the package restore that a build may do. The confirmation says so.
- Headless, with nobody to confirm: run nothing. Behave as read-only and mark those facts `unknown:` or `inferred:`.

The lists and the confirmation wording are in `references/safe-checks.md`.

## Markers

- `unknown:` not found. Say who to ask.
- `inferred:` worked out from the code, not confirmed.
- `changed:` updated in the last refresh.
- `conflict:` two sources disagree. The code wins. List the stale source as a finding in Unknowns and in `open-questions.md`. A committed secret, or any problem with no second source, is a finding, not a `conflict:`. Put it in Unknowns and in `open-questions.md`, not in Risks and delivery. A search count (for example a grep of test attributes) is a reading of the code and is not a run. When it disagrees with a document, mark `conflict:` with both. The count is the code's value, so it wins, but write it as `inferred:` and name the command that would settle it.

Cite sources as `path:line`.

## Output

Everything goes in the pack folder.

- `README.md` is the brief and the entry point. The headings are fixed in `references/brief-template.md`. Aim for about 2,000 words, about four pages. The 2,000-word target is for `README.md` only. Side files hold only detail the brief summarises: keep the whole pack under about 5,000 words, not counting `open-questions.md` and `contract.md`. The header records the scanned commit, the date, whether the working tree was clean or dirty, and the repo policy. A checklist of the nine questions sits at the top. Each item links to its section or says `unknown:`. Each section ends with a `Sources:` line.
- `open-questions.md` is always written. It collects every gap, grouped by who to ask, with why each matters. `feature-to-code.md` is always written too: it maps each use case to its code. `contract.md` is always written too: the project contract that other skills read, with the five fixed headings of `references/contract-fill.md`. Add the other side files, in the same folder, only when a section outgrows its share: `use-cases.md`, `data-model.md`, `integrations.md`, `glossary.md`. The brief keeps a short summary and a link. Each side file starts with the same `Scanned commit:` and `Scanned on:` lines as the brief.
- Diagrams are small Mermaid blocks.

The success test is nine questions. A brand-new engineer must answer them from the brief alone, and question 9 from the brief and `feature-to-code.md`:

1. What is the app for, and who uses it?
2. What are the three to five main use cases, and where are they in the code?
3. How do I run it, sign in, load test data and check my change?
4. What pattern do I copy to change something, and what are the house rules?
5. What are the main data entities, and how do I change the schema safely?
6. Which external systems do we depend on, and which endpoints and features break if one fails?
7. What must I never do or commit?
8. How does a finished ticket get delivered, and who do I ask?
9. Given a feature, where does its code load the data and do the calculation in each layer, and how do I search for one that is not in the map?

A gap marked `unknown:` with who to ask is a pass. A silent gap is a failure.

## Rules

- Read, do not write, in customer systems. Never change code. Never copy a secret value.
- Do not read Azure DevOps. For delivery and DevOps facts, read the pipeline and infrastructure files in the repository, then ask the engineer. A paste is the fallback.
- Do not read everything. Trust the code over configuration and documents. Trace one request for each use case.
- One repository per run. List several applications in one repository in the brief. A part in another repository is `unknown:` plus the path to ask for, and goes under External systems.
- Never create or edit `AGENTS.md` or `CLAUDE.md`, and never propose a section for them. Read them as sources only. Put the project contract in `contract.md` in the pack folder, and the build, run and test commands in the brief as well, in full.
- With the files policy `none`, write nothing in the repository, not even `.git/info/exclude`. The pack folder and the registry line that `onboarding-pack` writes are the only writes.
- If the working tree has uncommitted changes outside `docs/onboarding/`, the scanned commit does not describe what you read. Record `Working tree: dirty` in the header and list the changed files under Unknowns. The pack itself and build output from safe checks never count.
- In update mode the code is the source of truth. Replace what disagrees with it. Keep facts the code cannot contradict: owners, business meaning, customer answers. If nothing changed, change nothing.
- Day-2 follow-up questions belong to `agentd-explain`. This skill keeps no status file and has no resume step.
