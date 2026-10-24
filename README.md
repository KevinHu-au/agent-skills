# agent-skills

My personal agent skills, global guide and safety hooks. One repository sets up
Claude Code and GitHub Copilot CLI on a new machine.

## What is here

```
skills/         General skills, one folder each. Each holds a SKILL.md.
global/         The global guide (AGENTS.md) and the Claude Code CLAUDE.md that imports it.
hooks/copilot/  Copilot CLI safety hooks. git-safety.json.tmpl is a template.
harness/        One script per tool: claude-code.sh, copilot-cli.sh.
lib/common.sh   Link, backup and conflict logic shared by the scripts.
setup.manifest  Plugins and marketplaces to reinstall by hand.
install.sh      The setup script. Dry run by default.
tests/          test-install.sh runs the installer against throwaway home folders.
```

Skills in this repository are general. They work for any client and any stack.
A skill that only makes sense for one project belongs in that project's own
repository, not here. This keeps client details out of this repository. See
[Project skills in customer repositories](#project-skills-in-customer-repositories).

## Set up a new machine

1. Install Claude Code and Copilot CLI, and start each once so `~/.claude` and `~/.copilot` exist.
2. Clone this repository, for example to `~/Projects/agent-skills`.
3. Install `jq` (`brew install jq`). The Copilot shell hook needs it.
4. See the plan. This changes nothing:

   ```bash
   ./install.sh
   ```

5. Apply it:

   ```bash
   ./install.sh --apply
   ```

6. If the plan reports `CONFLICT`, an item already exists at that path. Read the
   conflict lines, then decide:

   ```bash
   ./install.sh --apply --adopt
   ```

   `--adopt` moves the existing item to `~/.agent-skills-backup/<time>/` and links
   the repository version in its place. It never deletes anything.

7. Install the plugins listed at the end of the plan by hand. The script prints
   them from `setup.manifest` and never installs them, because plugin commands
   change between versions.
8. Sign in to each tool again. Credentials are not stored here.

Options:

| Option | Effect |
|---|---|
| (none) | Show the plan. Change nothing. |
| `--apply` | Create the missing links and files. Leave conflicts alone. |
| `--adopt` | With `--apply`, move conflicting items to the backup folder and link ours. |
| `--harness LIST` | Limit to `claude-code`, `copilot-cli`, or both (comma separated). |

Exit status: `0` clean, `1` conflicts remain, `2` bad usage.

## How the links work

```
repo/skills/<name>  <-  ~/.agents/skills/<name>  <-  ~/.claude/skills/<name>
repo/global/AGENTS.md  <-  ~/.agents/AGENTS.md  <-  ~/.copilot/copilot-instructions.md
repo/global/claude/CLAUDE.md  <-  ~/.claude/CLAUDE.md   (imports ~/.agents/AGENTS.md)
repo/hooks/copilot/block-dangerous-shell.sh  <-  ~/.copilot/hooks/block-dangerous-shell.sh
repo/hooks/copilot/git-safety.json.tmpl  ->  ~/.copilot/hooks/git-safety.json   (rendered copy)
```

- `~/.agents/skills` is the shared home. Copilot CLI reads it from version 1.0.11. Claude Code does not, so it gets links in `~/.claude/skills`.
- `git-safety.json` holds an absolute path, so the script writes a rendered copy. It replaces `@HOME@` with your home folder.
- Edit skills in this repository, not through the links. `git pull` then updates both tools.

## Safety rules for the scripts

- Dry run by default.
- Safe to run twice. A second run changes nothing.
- No deletes. A conflicting item is only moved to the backup folder, and only with `--adopt`.
- The script checks that Copilot CLI is at least version 1.0.11 and that `jq` exists. It warns if not.
- It skips a tool whose folder does not exist and says so.

## Test

```bash
tests/test-install.sh
```

The test builds throwaway home folders, runs the installer in them, and checks the
result. It never touches your real home. It deletes nothing, so it prints the temp
folders it used. The operating system clears them later.

`shellcheck` is not run by the tests. Run it yourself if it is installed.

The `agentd-onboard` skill has its own tests in `tests/onboard/`. They check the skill files, the brief
checker, and a synthetic fixture project. They use throwaway folders in the system temp folder and delete
nothing.

```bash
tests/onboard/test-check-brief.sh
tests/onboard/test-make-fixture.sh
tests/onboard/test-skill-structure.sh
```

`tests/onboard/EVAL.md` explains how to run the skill on the fixture and records the results.

The `agentd-diagnose` skill has its own tests in `tests/diagnose/`. They check the skill files and a synthetic
Python and SQLite fixture with four seeded problems (a bug, bad data, a slow report, and a failure that cannot
be reproduced). They need `git`, Python 3 and `sqlite3`, use throwaway folders in the system temp folder, and
delete nothing.

```bash
tests/diagnose/test-skill-structure.sh
tests/diagnose/test-make-fixture.sh
```

`tests/diagnose/EVAL.md` explains how to run the skill on the fixture and records the results.

The `agentd-blast-radius` skill has its own tests in `tests/blast-radius/`. They check the skill files and a
synthetic Python and SQLite fixture with three seeded changes (a rename with readers that a caller search misses,
a change that is safe because of one provable fact, and a change that depends on a partner system that cannot be
run). They need `git`, Python 3 and `sqlite3`, use throwaway folders in the system temp folder, and delete nothing.

```bash
tests/blast-radius/test-skill-structure.sh
tests/blast-radius/test-make-fixture.sh
```

`tests/blast-radius/EVAL.md` (not written yet) will explain how to run the skill on the fixture and record the results.

The `agentd-intake` skill has its own tests in `tests/intake/`. They check the skill files and a fixture: the
diagnose fixture plus a small onboarding pack, with five work items (an enhancement that asks for the wrong fix, a bug
whose claim the code contradicts, a clear request, a support question, and a second run after the customer replies).
They need `git` and Python 3, use throwaway folders in the system temp folder, and delete nothing.

```bash
tests/intake/test-skill-structure.sh
tests/intake/test-make-fixture.sh
```

`tests/intake/EVAL.md` explains how to run the skill on the fixture and records the results.

The `agentd-explain` skill has a structure test in `tests/explain/`. It reads the skill files, this README and
`tests/explain/EVAL.md`, and writes nothing. It also checks that no customer or project name from your own git-ignored list `.git/info/customer-names`
appears in the skill files, this README or `tests/explain/EVAL.md`; without that list, the check is skipped.

```bash
tests/explain/test-skill-structure.sh
```

`tests/explain/EVAL.md` explains the real check on two customer projects and records a summary of the results.

The `agentd-data-fix` skill has a structure test in `tests/data-fix/`. It reads the skill files, this README and
`tests/data-fix/EVAL.md`, and writes nothing. It uses the same git-ignored name list as the explain test.

```bash
tests/data-fix/test-skill-structure.sh
```

`tests/data-fix/EVAL.md` explains the real check on copies of two customer projects and records a summary of the
results.

## Add a skill

1. Create `skills/<name>/SKILL.md` with `name`, `description` and `disable-model-invocation: true` in the frontmatter. Use lowercase and hyphens. The last field keeps the skill out of the model's context: it runs only when you type `/<name>`.
2. Keep the skill general. Read project facts from the project's `AGENTS.md`. Do not write `dotnet test` or any one stack's command in the skill.
3. Put stack-specific detail in `skills/<name>/references/<stack>.md`, and load it only when the stack is detected.
4. Run `./install.sh` to see the new links, then `./install.sh --apply`.
5. Test the skill in both Claude Code and Copilot CLI.

## Project skills in customer repositories

Some customers allow only Copilot, some allow Claude Code, and some do not want
extra files in their repository. Skills that generate project skills (such as
`agentd-verify-init`) must ask before they write.

Ask these two questions once per project:

1. Which tools does the customer allow? Claude Code, Copilot CLI, or both.
2. May the skills be committed to the customer repository?

Then write to the matching folder. Tested on Copilot CLI 1.0.101:

| Customer allows | Write project skills to | Why |
|---|---|---|
| Copilot CLI only | `.github/skills/<name>/` | The Copilot convention. Copilot also reads `.claude/skills/` and `.agents/skills/`. |
| Claude Code only | `.claude/skills/<name>/` | The Claude Code project folder. |
| Both | `.claude/skills/<name>/` | The one project folder both tools read. |

If the customer does not want the files committed, keep them local. Add the folder
to `.git/info/exclude` in your own clone, not to `.gitignore`:

```bash
echo '.github/skills/' >> .git/info/exclude
```

`.git/info/exclude` is private to your clone and cannot be committed by accident.
A shared `.gitignore` tells the whole team the folder exists.

A local-only skill is lost when you clone again on a new machine. If the project
keeps `docs/onboarding/`, regenerate the project skills from it. Record the two
answers above in `docs/onboarding/` so a later session does not ask again.

## What stays out of this repository

- Credentials, tokens, licence keys and login state.
- Plugin cache folders. Reinstall from `setup.manifest`.
- Session history and per-project memory.
- Live settings files such as `~/.claude/settings.json` and `~/.copilot/config.json`. They can hold machine paths and permissions.
- Client project knowledge, such as `docs/onboarding/`. That lives in each client repository.
- The `copilot` shell alias that adds `--allow-all`. It removes permission prompts, so set it up on purpose on each machine.

## Skills

| Skill | Purpose |
|---|---|
| `agentd-blast-radius` | Find what else one change could break, including what search misses. Proves the one fact the change is safe because of by running code, edits no code, and ends with an add-on block for `agentd-dev-rev`. |
| `agentd-data-fix` | Turn a work item into a safe, re-runnable data fix: look queries, a guarded script, a capture query, a reverse script and check queries, all written in chat. Never runs anything against a database; edits no code. |
| `agentd-dev-rev` | Build a change with TDD, stage it, and get two independent review rounds. Never commits. |
| `agentd-diagnose` | Find the root cause of a bug, a data issue or a slow path. Reproduces first, edits no code, and ends with a report and a hand-off block for `agentd-dev-rev`. |
| `agentd-explain` | Explain a business term, a figure, a status or a whole domain to the engineer, with the code path from the screen to the database or external system. Read only, apart from an export you ask for; edits no code. |
| `agentd-intake` | Turn a vague work item into an actionable one, written as an Azure DevOps comment, or into the questions and investigation needed first. Checks the work item against the code and edits no code. |
| `agentd-onboard` | Onboard to an existing customer project, or refresh the onboarding. Writes a short brief plus side files in `docs/onboarding/` and fills the project contract in `AGENTS.md`. |
| `agentd-pr-prep` | Write a PR title and description from the branch diff. |
| `agentd-prompt` | Rewrite a rough prompt into a clearer one without running it. |

Every skill sets `disable-model-invocation: true`. The model never starts one on its own, so run a skill by
typing `/skill-name`. This field is a Claude Code feature. In Copilot CLI an open issue
([github/copilot-cli#4438](https://github.com/github/copilot-cli/issues/4438)) says a skill with the field is
not found, even when you name it. That has not been tested on the version in use here. If a skill is not found
in Copilot CLI, remove the line from that skill.

Skills that belong to my separate AgentKit repository are not stored here.
`setup.manifest` lists them as reminders, and `install.sh` prints the reminder.
Install them from that repository into `~/.agents/skills/`.

## Planned

These are designs, not files yet.

| Skill | Purpose |
|---|---|
| `agentd-verify-init` | Generate a project-local skill that drives the app like a user. Asks which tool the customer allows and writes to the matching folder. |

Planned flow:

```
onboard (once per project) -> intake -> diagnose -> blast-radius -> dev-rev -> verify -> pr-prep

explain: a side tool, run any time
data-fix: after diagnose, for a work item that needs a data fix; a live cause goes on to dev-rev
```

Start at any step. Small changes skip `diagnose`. A support question stops at `intake`: it gives the code facts and
you answer.

### Project contract

General skills read facts from each project's `AGENTS.md`. The planned headings are:

- Commands: build, test, lint, and how to confirm the test count is real.
- Verify: how to run and drive the app.
- Data access: how to query safely, and which environments are read-only.
- Risk areas: contracts, schema, authorisation, generated files.
- External systems and owners: each outside system, which endpoints and features depend on it, and who owns it.

`agentd-onboard` fills these in for a new project.
