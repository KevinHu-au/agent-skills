---
name: agentd-onboard
description: Use when the engineer is onboarding to an existing project, taking over support for a customer application, or refreshing a project's onboarding pack. Writes one short brief plus side files in docs/onboarding/ and fills the project contract.
disable-model-invocation: true
---

# agentd-onboard

Learn an existing project in phases, then write one short brief, `docs/onboarding/README.md`. A brand-new engineer reads the brief and can start a simple ticket. The brief covers the business (who uses the application, the typical use cases) and the technical picture (architecture, data, external systems, how to run and check a change). It leads from a feature to its code: the key concept, the first files in each layer, and how to search for the rest. It also fills the project contract in `AGENTS.md`. When the brief already exists, this skill refreshes it.

It never writes to customer systems, never changes code, and never copies a secret value. Name the key only.

## Prerequisite

Run `git rev-parse --show-toplevel`. If it fails, stop with one line: `agentd-onboard needs a git repository. Run it inside one.` Work from the repository root, even when started in a subfolder. Run `git rev-parse HEAD`. If it fails, the repository has no commits: stop with one line: `agentd-onboard needs at least one commit.` The skill must run with no input at all: every question is optional, and with no answer it carries on as Flow says.

Check for a linked worktree: compare the output of `git rev-parse --path-format=absolute --git-dir` with that of `git rev-parse --path-format=absolute --git-common-dir`. The flag is needed because the common folder can print as a relative path from a subfolder. It needs git 2.31 or later; with an older git, resolve both paths with `cd` and `pwd -P`. If they differ, this is a linked worktree, and the repository root is the main checkout, not the worktree folder. Find the main checkout with `git worktree list --porcelain`: its first `worktree` entry. If that entry says `bare`, the main repository has no checkout to write to: stop with one line. Warn that output in a removed worktree is lost, then write to the main checkout, or ask which. If nobody can answer, write to the main checkout, and put the warning in your final reply and in `open-questions.md`. From then on, read the code, run git commands and write the pack in the main checkout, so the pack and the commit it records sit together.

## Modes

- **Create:** `docs/onboarding/README.md` does not exist at the repository root. Build the pack.
- **Update:** the file exists and this skill wrote it. Check it against the latest code and rewrite only what is outdated. Follow `references/update-mode.md` instead of Flow steps 2 to 4, except the path and term check in Flow step 4, which still runs on every block you touch. Ask the optional questions only when an `unknown:` from the last run may now be answerable. Show the engineer any new or changed use case. When `update-mode.md` step 5 or step 8 calls for it, refresh the project contract as Flow step 4 says, with `references/contract-fill.md`. Run the check in Flow step 5 (the nine questions) on the sections you changed.

If `docs/onboarding/README.md` exists but was not written by this skill (it has none of the three header lines and no `## First-ticket checklist` heading), stop with one line: `docs/onboarding/README.md exists and was not written by agentd-onboard. Move it, or say where to write the pack.` Do not change it.

If the engineer says the customer does not want the pack committed, add `docs/onboarding/` to the file that `git rev-parse --git-path info/exclude` prints. Do not edit `.gitignore`.

## Flow

1. **Ask the optional questions.** Handover notes, what the engineer already knows, DevOps facts. Every question is optional. If nobody answers, carry on.
2. **Explore.** Start one read-only sub-agent for each angle, in parallel: UI and routes; API and permissions; domain model and schema; data-flow tracer; integrations and dependencies; documentation and tests. Prompts, the report template and the synthesizer prompt are in `references/explorer-prompts.md`. If you cannot start sub-agents, run the angles one after another. Keep explorer output out of the main context: each report is bounded and one synthesizer merges them. For .NET projects also load `references/dotnet.md`. For iOS (SwiftUI) projects also load `references/ios.md`. For React web projects (a `package.json` that lists `react-dom` under `dependencies`, in any workspace) also load `references/react.md`. For external systems follow `references/external-systems.md`.
3. **Show the drafts.** Show the drafted use cases and journeys, with the key concept chosen from the explorer reports. Ask the engineer to correct them. A draft works better than a blank question. If there is no answer, carry on: write the use cases as `inferred:` and put them first in `open-questions.md`.
4. **Write.** Write the brief with `references/brief-template.md`. Write `feature-to-code.md` with `references/feature-to-code-template.md`. Add side files only when a section outgrows its share. Fill the project contract with `references/contract-fill.md`. Ask before creating or editing `AGENTS.md`. Then check the drafted text with read-only commands from the repository root, before any file is written. Run the commands on the values in your draft, one value at a time; no file is needed for this, and if the draft is only in your head, check each value as you write it down. Count lines with `awk 'END { print NR }'`, not `wc -l`, so a last line without a final newline counts. Every path (the `Open:` and `Pattern:` lines, and the two path columns) must exist by `test -e <root>/<path>`. A folder passes only without `:N`. An untracked file passes. For `:N` or `:N-M`, the file must have at least that many lines. Read values this way: strip a leading `./`; skip cells that start with `none` as a whole word, `unknown:` or `inferred:`, and a `changed:` prefix is read through; read only backticked values. A term goes to `git grep` as one quoted argument, so write a single quote inside it as `'\''` in the shell. Every search term in a Search terms table must be found outside the pack by `git grep --untracked -F -q -- '<term>' -- . ':(exclude)docs/onboarding'`. The pack is excluded because, once it is committed, every term would match inside `feature-to-code.md` and the check would prove nothing. Never check `Run:` lines or Business term cells. Fix a miss before the pack is written. Mark a miss that cannot be fixed `unknown:`.
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

Everything goes in `docs/onboarding/`.

- `README.md` is the brief and the entry point. The headings are fixed in `references/brief-template.md`. Aim for about 2,000 words, about four pages. The 2,000-word target is for `README.md` only. Side files hold only detail the brief summarises: keep the whole pack under about 5,000 words, not counting `open-questions.md`. The header records the scanned commit, the date, and whether the working tree was clean or dirty. A checklist of the nine questions sits at the top. Each item links to its section or says `unknown:`. Each section ends with a `Sources:` line.
- `open-questions.md` is always written. It collects every gap, grouped by who to ask, with why each matters. `feature-to-code.md` is always written too: it maps each use case to its code. Add the other side files, in the same folder, only when a section outgrows its share: `use-cases.md`, `data-model.md`, `integrations.md`, `glossary.md`. The brief keeps a short summary and a link. Each side file starts with the same `Scanned commit:` and `Scanned on:` lines as the brief.
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
- Ask before creating or editing `AGENTS.md`. If `CLAUDE.md` only imports `AGENTS.md`, write to `AGENTS.md`.
- If the working tree has uncommitted changes outside `docs/onboarding/`, the scanned commit does not describe what you read. Record `Working tree: dirty` in the header and list the changed files under Unknowns. The pack itself, the contract section this skill wrote, and build output from safe checks never count.
- In update mode the code is the source of truth. Replace what disagrees with it. Keep facts the code cannot contradict: owners, business meaning, customer answers. If nothing changed, change nothing.
- Day-2 follow-up questions belong to `agentd-explain`. This skill keeps no status file and has no resume step.
