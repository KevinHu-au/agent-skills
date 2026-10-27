# Filling the project contract

The project contract is a section of the project's own `AGENTS.md`. It has five fixed headings. General skills read the project's facts from those exact headings, so never rename or reorder them. The fields below repeat the template (`templates/project-contract.md` in the agent-skills repository), so this skill works without that file. If you can read the template and the two differ, the template wins. Tell the engineer.

## Where to write

- Write the section `## Project contract` in `AGENTS.md` at the repository root.
- If `AGENTS.md` does not exist, ask before creating it.
- If `CLAUDE.md` only imports `AGENTS.md` (it holds a line such as `@AGENTS.md` and little else), still write to `AGENTS.md`.
- Ask before any edit. Show the proposed section, or the changes in update mode, and wait for a yes. Change nothing else in the file.
- If `AGENTS.md` already states contract facts under its own headings (for example a Commands or Architecture section) but has no `## Project contract`, keep those sections as they are. Add the contract section with all five headings. For a fact that is already there, write one line that points to it (`see AGENTS.md, <heading>`), and fill in only what is missing.
- Headless, with nobody to ask: do not touch `AGENTS.md`. Put the facts in the brief, and list "contract not written, nobody to confirm" in `open-questions.md`, after the unconfirmed use cases. Below that line, add the proposed `## Project contract` section in a fenced block, ready to paste, so the facts you found are not lost.
- In update mode, when `## Project contract` already exists, refresh the facts the code can check (commands, versions, paths, endpoints, script locations) and keep the rest: owners, access rules, and anything the engineer told you. If an earlier run did not write the contract and you can ask now, ask now.

## How to fill each fact

- Cite a source for each fact: `path:line`, a URL, or "told by <role>".
- Write `unknown: ask <role or name>` when you cannot find a fact. Never guess.
- Write `inferred:` before a fact you worked out but could not confirm, for example a command read from a pipeline file and never run.
- When two sources disagree, write both with their sources and mark it `conflict:`. Prefer the source closest to the running code: a project file beats a README.
- Never write a secret. Write where it is kept, for example the name of the vault folder.
- Keep each answer short. Point to the brief or another document instead of copying it.
- Run a command only under the rules in `safe-checks.md`.

## The five headings

### Commands

Run from: the directory the commands run from.

- **Prerequisites:** runtime versions, tools, Docker, VPN, licences. Read the project files, `global.json`, the README and the pipeline.
- **Build:** the command the pipeline uses.
- **Unit tests:** the command the pipeline uses.
- **Integration tests:** the command, and what it needs (Docker, a database, services). Never run it from this skill.
- **Run one test:** the command with a filter.
- **Lint and format:** the commands, or `unknown:`.
- **Run locally:** the commands for each part: API, UI, database.
- **Count check:** how to confirm that tests really ran. Give the expected count and any filter that matches zero tests but still exits 0. List the tests when safe checks are allowed.
- **Known failing on a clean main:** what fails and why, or `unknown:`.

### Verify

- **Start the app:** the steps.
- **Sign in:** how a local user gets in and gets roles, without secrets.
- **Test data:** how to load it and where the files are.
- **Key flows to drive** (three to five, one row each: flow, start at, expected result). Take them from the use cases in the brief.
- **Automated checks of the running app:** UI or API test commands, or "none".

### Data access

A table with one row for each environment. The columns are Environment, URL, Database, Access rule (read-write, read-only or none) and Who approves access. Use `unknown: ask <role>` for a rule you cannot read.

- **Network:** VPN, firewall rules, IP allow list.
- **Query safely:** a read-only login, the tool, and how to avoid locks.
- **Never do:** for example writes to Prod, or a reset against a shared database.
- **Schema changes:** where the scripts live, their naming, and which scripts run once and which re-run on every deploy. A script that runs once is never edited after it is applied. A script the tool runs again on every deploy (for example a stored procedure kept as a create-or-alter script) is edited in place. Take this from the Data model section of the brief.
- **Sensitive data:** personal or financial data, and masking rules.

### Risk areas

- **Public contracts:** the HTTP API, DTOs, serialised shapes and configuration keys, and who depends on them.
- **Database:** schema, stored procedures and migrations.
- **Authorisation:** where it is enforced, and the rule that it must not move.
- **Generated files:** each file and the exact command that regenerates it.
- **Business-critical calculations:** where the rules are documented and tested.
- **Never commit:** the files that hold secrets or local settings.

### External systems and owners

A table with one row for each system outside this repository that the application calls or that calls the application. The columns are System, Direction, Our endpoints and services that depend on it, Features that depend on it, Owner and Test environment. Fill each row from the record described in `external-systems.md`.

- **Failure behaviour:** timeouts, retries, queues, and what the user sees when the system is down.
- **Other side of the boundary:** the logic inside an external system is not in this repository. Write `unknown: ask <owner>` for anything you cannot read here.
