# agent-skills

Agent skills, a global guide and safety hooks. The skills are suitable for digital
application support developers or engineers to do application maintenance and bug fixes
with confidence. One repository sets up Claude Code and GitHub Copilot CLI on a new
machine.

## What is here

```
skills/         General skills, one folder each. Each holds a SKILL.md.
global/         The global guide (AGENTS.md), the Claude Code CLAUDE.md that imports it, bin/rm-scratch and bin/onboarding-pack.
hooks/copilot/  Copilot CLI safety hooks. git-safety.json.tmpl is a template.
harness/        One script per tool: claude-code.sh, copilot-cli.sh.
lib/common.sh   Link, backup and conflict logic shared by the scripts.
setup.manifest  Plugins and marketplaces to reinstall by hand.
install.sh      The setup script. Dry run by default.
tests/          test-install.sh runs the installer against throwaway home folders. One folder per skill.
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

Claude Code reads `$CLAUDE_CONFIG_DIR` when it is set. Some setups use a second
folder, for example `~/.claude-work` for a company account. Set the same variable
when you run the installer, once per folder:

```bash
CLAUDE_CONFIG_DIR=~/.claude-work ./install.sh --harness claude-code
CLAUDE_CONFIG_DIR=~/.claude-work ./install.sh --harness claude-code --apply
```

Use an absolute path or one that starts with `~/`. The installer skips a relative path with a warning.
Without the variable, the installer uses `~/.claude`. The folder must already
exist; start Claude Code once with the variable set to create it.

## How the links work

```
repo/skills/<name>  <-  ~/.agents/skills/<name>  <-  ~/.claude/skills/<name>
repo/global/AGENTS.md  <-  ~/.agents/AGENTS.md  <-  ~/.copilot/copilot-instructions.md
repo/global/claude/CLAUDE.md  <-  ~/.claude/CLAUDE.md   (imports ~/.agents/AGENTS.md)
repo/global/bin/rm-scratch  <-  ~/.agents/bin/rm-scratch
repo/global/bin/onboarding-pack  <-  ~/.agents/bin/onboarding-pack
repo/hooks/copilot/block-dangerous-shell.sh  <-  ~/.copilot/hooks/block-dangerous-shell.sh
repo/hooks/copilot/git-safety.json.tmpl  ->  ~/.copilot/hooks/git-safety.json   (rendered copy)
```

- `rm-scratch` removes one scratch file or folder that an agent made with `mktemp`, and refuses anything else: a
  path outside the system temp folders, a symlink, or a path you do not own. The global guide tells agents to
  remove an approved scratch path with this script and no other removal command. `--dry-run` runs every check
  and removes nothing.
- `onboarding-pack` records where a repository's onboarding pack lives when the customer allows no file in the
  repository (see [Where the onboarding pack lives](#where-the-onboarding-pack-lives)). `set <folder>` writes one line
  to `~/.agents/onboarding-packs.tsv`, keyed by the repository's origin URL in one normal form, or by the path of its
  main checkout when it has no origin. `find` prints the folder, `key` prints the key, and `suggest` prints a default
  folder made from the key and a short hash of it, so two repositories do not share one. `set` refuses a relative
  path, a folder that does not exist, a folder inside any working tree of the repository (in any letter case), and a
  folder that another repository has recorded. It cannot see a separate clone of the same repository, so do not point
  it at a folder inside one. Exit
  status: 0 success, 1 no pack recorded, 2 bad usage, 3 the recorded folder is gone, 4 refused.
- `block-dangerous-shell.sh` checks each Copilot shell command. It denies `git push`, `git reset --hard`, a
  forced `git clean`, `git branch -D` or a forced branch delete, a forced `git checkout` or `git switch`, and
  `git checkout .` or `git restore .`. It also catches forms such as `git -C "<path>" push`, `/usr/bin/git push`,
  `(git push)`, `bash -c 'git push'` and a line continuation. It asks before `rm`, `rmdir`, `unlink`, `trash`,
  `shred`, `find -delete`, and the PowerShell `Remove-Item`, `ri`, `del`, `erase` and `rd`. It prints nothing for
  any other command, so Copilot applies its default. It denies when `jq` is missing or it cannot read the command.
  A command word inside a quoted message can cause a false deny or ask, which is accepted as safe. A regex cannot
  catch every shell form, so treat it as a guard rail, not a sandbox.

- `~/.agents/skills` is the shared home. Copilot CLI reads it from version 1.0.11. Claude Code does not, so it gets links in `~/.claude/skills` (or `$CLAUDE_CONFIG_DIR/skills`).
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
result. It also checks the rules of the Copilot shell hook. It never touches your real home. It deletes nothing,
so it prints the temp folders it used. The operating system clears them later.

```bash
tests/test-rm-scratch.sh
```

This test checks that `rm-scratch` removes only a scratch path that you own under a system temp folder, and
refuses everything else.

```bash
tests/test-onboarding-pack.sh
tests/test-shared-text.sh
```

The first checks the keys, `find` and `set` of `onboarding-pack` in a throwaway home folder, so your real registry is
never read or written. The second checks that the "Find the project facts" paragraph is word for word the same in
every skill that reads the onboarding pack. It reads files and writes nothing.

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

`tests/blast-radius/EVAL.md` explains how to run the skill on the fixture and records the results.

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

The `agentd-verify-init` skill has a structure test in `tests/verify-init/`. It reads the skill files, `agentd-dev-rev`,
`agentd-pr-prep`, this README and `tests/verify-init/EVAL.md`, and writes nothing. It uses the same git-ignored name
list as the explain test.

```bash
tests/verify-init/test-skill-structure.sh
```

`tests/verify-init/EVAL.md` explains the real check of the generated skill and records a summary of the results.

The `agentd-pr-review` skill has its own tests in `tests/pr-review/`. They check the skill files, this README and a
synthetic Python fixture: a repository with one PR branch that leaves an acceptance criterion unmet, misses a screen
that needs the same change, filters more statuses than the work item asks for, breaks one unit test, and keeps one old
integration failure and a test command that runs 0 tests. They need `git` and Python 3, use throwaway folders in the
system temp folder, and delete nothing. The structure test uses the same git-ignored name list as the explain test.

```bash
tests/pr-review/test-skill-structure.sh
tests/pr-review/test-make-fixture.sh
```

`tests/pr-review/EVAL.md` explains how to run the skill on the fixture and on a real PR, and records the results.

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

`agentd-onboard` asks these two questions once per project. It records the answers in the brief header as the
`Repo policy:` line, so a later session reads them and does not ask again:

1. Which tools does the customer allow? Claude Code, Copilot CLI, or both.
2. Which agent files may sit in the customer repository? Committed, local only (never committed), or none.

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

A local-only skill is lost when you clone again on a new machine. Regenerate the
project skills from the onboarding pack.

`agentd-verify-init` does not support the policy `none` yet: it writes the project skill into the repository.

### Where the onboarding pack lives

The second answer sets the pack folder. The pack holds the brief (`README.md`), the project contract (`contract.md`),
`feature-to-code.md`, `open-questions.md` and any side files.

| Files allowed in the repository | Pack folder | How other skills find it |
|---|---|---|
| Committed | `docs/onboarding/`, committed through the normal pull request | They look for `docs/onboarding/README.md`. |
| Local only | `docs/onboarding/`, listed in `.git/info/exclude` | The same. |
| None | A folder outside the repository, by default the one `onboarding-pack suggest` prints | `onboarding-pack find` prints the folder that `onboarding-pack set` recorded. |

With the policy `none`, nothing is written into the repository, not even `.git/info/exclude`. The registry line lives
in `~/.agents/onboarding-packs.tsv` on your machine. A second clone of the same repository finds the same pack. On a
new machine, a skill that finds no pack asks you for the folder once and tells you the `onboarding-pack set` command.
A clone by SSH and a clone by HTTPS of an Azure DevOps repository can get two different keys, because the two URLs
have different paths. Record the folder once for each.

Known limit: a repository on a network mount (for example a Windows drive mounted on a Mac) may need git to run on
the other machine. The skills run git where they start. Follow that repository's own `AGENTS.md` for its git rules.

## What stays out of this repository

- Credentials, tokens, licence keys and login state.
- Plugin cache folders. Reinstall from `setup.manifest`.
- Session history and per-project memory.
- Live settings files such as `~/.claude/settings.json` and `~/.copilot/config.json`. They can hold machine paths and permissions.
- Client project knowledge, such as the onboarding pack. That lives in each client repository, or in a folder outside
  it that `onboarding-pack` records in `~/.agents/onboarding-packs.tsv`.
- The `copilot` shell alias that adds `--allow-all`. It removes permission prompts, so set it up on purpose on each machine.

## Credits

Many ideas in these skills come from two sources: pstack (the Cursor official plugin)
and the Superpowers plugin skills. We borrowed their patterns, such as the structure of
the skills and the habit of reproducing before fixing. We wrote the skill text in our
own words. Superpowers is also listed in `setup.manifest`.

## Skills

| Skill | Purpose |
|---|---|
| `agentd-blast-radius` | Find what else one change could break, including what search misses. Proves the one fact the change is safe because of by running code, edits no code, and ends with an add-on block for `agentd-dev-rev`. |
| `agentd-data-fix` | Turn a work item into a safe, re-runnable data fix: look queries, a guarded script, a capture query, a reverse script and check queries, all written in chat. Never runs anything against a database; edits no code. |
| `agentd-dev-rev` | Build a change with TDD, stage it, and get two independent review rounds. Never commits. |
| `agentd-diagnose` | Find the root cause of a bug, a data issue or a slow path. Reproduces first, edits no code, and ends with a report and a hand-off block for `agentd-dev-rev`. |
| `agentd-explain` | Explain a business term, a figure, a status or a whole domain to the engineer, with the code path from the screen to the database or external system. Read only, apart from an export you ask for; edits no code. |
| `agentd-intake` | Turn a vague work item into an actionable one, written as an Azure DevOps comment, or into the questions and investigation needed first. Checks the work item against the code and edits no code. |
| `agentd-onboard` | Onboard to an existing customer project, or refresh the onboarding. Asks the repo policy once, then writes a short brief, the project contract and side files in the onboarding pack: `docs/onboarding/`, or a folder outside the repository. Never writes `AGENTS.md`. |
| `agentd-pr-prep` | Write a PR title and description from the branch diff. |
| `agentd-pr-review` | Review a teammate's PR against its work item when you are the approver. Builds the requirement, looks for places the PR missed, checks breakage and runs the tests, then writes paste-ready markdown comments marked Block, Major or Minor. Edits no code and posts nothing. |
| `agentd-prompt` | Rewrite a rough prompt into a clearer one without running it. |
| `agentd-verify-init` | Generate a project-local skill `verify-<app>` that drives the app like a user. Asks which tool the customer allows and writes to the matching folder. Also updates the skill later. |

Every skill sets `disable-model-invocation: true`. The model never starts one on its own, so run a skill by
typing `/skill-name`. This field is a Claude Code feature.

Tested on Copilot CLI 1.0.102 on 2026-10-26, in a throwaway repository. Copilot's skill tool does not load a skill
with the field. This matches the open issue
([github/copilot-cli#4438](https://github.com/github/copilot-cli/issues/4438)). The same skill without the field
loads, also from a subfolder, and a nested `metadata:` marker is accepted. A Copilot task agent also cannot run a
flagged skill. Claude Code runs a flagged skill.

So the flagged skills in this repository do not load in Copilot CLI 1.0.102. Use them in Claude Code. The generated
project skill `verify-<app>` is written without the field for this reason.

Skills that belong to the separate AgentKit repository are not stored here.
`setup.manifest` lists them as reminders, and `install.sh` prints the reminder.
Install them from that repository into `~/.agents/skills/`.

## Flow

```
onboard (once per project) -> intake -> diagnose -> blast-radius -> dev-rev -> verify -> pr-prep

explain: a side tool, run any time
pr-review: a side tool, run when you are the approver of a teammate's PR
data-fix: after intake or diagnose, for a work item that needs a data fix; a live cause goes on to dev-rev
blast-radius: only when the change touches a contract, schema, shared code or an external system
```

In the flow, `verify` means the project skill `/verify-<app>`, which `agentd-verify-init` generates for a project.

Start at any step. Small changes skip `diagnose`. A support question stops at `intake`: it gives the code facts and
you answer.

## Project contract

General skills read facts from the project contract. It is the `## Project contract` section of the project's own
`AGENTS.md` when that exists, or else `contract.md` in the onboarding pack. When both exist and disagree, the skills
use `AGENTS.md` and mark the fact `conflict:`. The headings are:

- Commands: build, test, lint, and how to confirm the test count is real.
- Verify: how to run and drive the app.
- Data access: how to query safely, and which environments are read-only.
- Risk areas: contracts, schema, authorisation, generated files.
- External systems and owners: each outside system, which endpoints and features depend on it, and who owns it.

`agentd-onboard` fills these in for a new project, in `contract.md`. It never writes `AGENTS.md`. An access rule under
Data access counts only when it cites its source (`told by <role>` or a document). The skills treat any other rule,
such as one marked `inferred:` or `unknown:`, as no access, and run no query on that environment.
