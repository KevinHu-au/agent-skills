# agent-skills

Skills for engineers who support and fix live web and mobile apps. A work item comes in, often vague. The skills help
you make it clear, find the root cause, check what else a fix could break, build the fix with tests and review, and
write the PR. They work in Claude Code, GitHub Copilot CLI and Codex. One install sets up all three.

Skills in this repository are general across clients. They are written for .NET (Framework and Core) with SQL Server,
React web and SwiftUI iOS projects, so they are not for every stack. Each skill that has stack references detects a
stack by the same signals. For any other stack, or for a part of a project that matches none of the signals (a Python
API behind a React frontend), `agentd-diagnose` and `agentd-blast-radius` read their `references/generic.md`,
`agentd-explain` uses a generic layer order, `agentd-onboard` works from the code alone, and `agentd-verify-init` asks
the engineer. Every fact the agent works out for such a stack is marked `inferred:`.

## What the agent never does in these skills

- Start a skill on its own. You start each one by typing its name.
- Commit, push or open a PR on its own. You do that, or tell the agent to.
- Post a comment, a review or a vote. `agentd-intake`, `agentd-pr-prep` and `agentd-pr-review` write text in chat for
  you to paste.
- Run a query on an environment that the [project contract](#project-contract) does not allow, with a cited source.
  `agentd-diagnose` never runs anything against production. `agentd-data-fix` never runs anything against a database:
  it writes the scripts, and you run them.
- Write the project's `AGENTS.md`.
- Force-push, `git reset --hard` or force-delete a branch. The [shell safety hook](#shell-safety-hook) denies these.
  It also asks you before a file removal, a history rewrite or a `sqlcmd` database write. In Codex an ask is a deny,
  and Codex on Windows gets no hook. The hook is a guard rail, not a sandbox: see [Rules](#rules) for what it does not
  catch.

## Quick start

Start Claude Code, Copilot CLI and Codex once each, so their home folders exist. Then:

```bash
git clone <repository URL> ~/Projects/agent-skills
cd ~/Projects/agent-skills
brew install jq        # on Windows, see Set up a new machine
./install.sh           # dry run: shows the plan and changes nothing
./install.sh --apply
```

Read `global/AGENTS.md` before you apply. The installer makes it the global guide of all three tools.

In Codex, run `/hooks` once and trust the two agentd entries. Codex skips a hook until you trust it.

Then open a customer project and run `/agentd-onboard` (`$agentd-onboard` in Codex).
[Set up a new machine](#set-up-a-new-machine) has the full steps, Windows and conflicts.

### What the installer changes

- It adds links in `~/.agents` and in each tool's folder. They point into this clone, so the clone holds the one
  copy of each skill.
- It makes `global/AGENTS.md` the global guide of each tool, through `CLAUDE.md` in each Claude Code folder,
  `~/.copilot/copilot-instructions.md` and `~/.codex/AGENTS.md`.
- It writes two hook files from templates: `~/.copilot/hooks/git-safety.json` and `~/.codex/hooks.json`. With
  `--always-on-guard`, it also writes `~/.agents/always-on-guard`.
- It never deletes a file and never edits a `settings.json`. When a different file already exists at one of these
  paths, it reports a `CONFLICT` and leaves the file alone. `--adopt` moves that file to
  `~/.agent-skills-backup/<time>/`, under the same path relative to your home folder, and puts ours in its place. To
  keep rules from your own global guide, copy them into your clone's `global/AGENTS.md` first.
- It is safe to run twice: a second run changes nothing. It skips a tool whose folder does not exist, and warns when
  `jq` is missing or Copilot CLI is older than 1.0.11.

There is no uninstall script yet. See [Remove the setup](#remove-the-setup).

## Skills

Run a skill by typing `/<name>` in Claude Code or Copilot CLI, or `$<name>` in Codex.

### Flow

```
onboard (once per project) -> intake -> diagnose -> blast-radius -> dev-rev -> verify -> pr-prep

explain: a side tool, run any time
pr-review: a side tool, run when you are the approver of a teammate's PR
handoff: a side tool, run when you stop a task and want to continue later
resume: run first in the new session to continue a handoff
data-fix: after intake or diagnose, for a work item that needs a data fix; a live cause goes on to dev-rev
blast-radius: only when the change touches a contract, schema, shared code or an external system
```

In the flow, `verify` means the project skill `/verify-<app>`, which `agentd-verify-init` generates for a project.

Start at any step. Small changes skip `diagnose`. A support question stops at `intake`: it gives the code facts and
you answer.

### Flow skills

In flow order. Each skill's `SKILL.md` has the full detail.

| Skill | Purpose |
|---|---|
| `agentd-onboard` | Onboard to an existing customer project, or refresh the onboarding. Writes a short brief, the project contract and side files to the [onboarding pack](#where-the-onboarding-pack-lives). Never writes `AGENTS.md`. |
| `agentd-intake` | Turn a vague work item into an actionable one, written as an Azure DevOps comment, or into the questions and investigation needed first. Edits no code. |
| `agentd-diagnose` | Find the root cause of a bug, a data issue or a slow path. Reproduces first, edits no code, and ends with a hand-off block for `agentd-dev-rev`. |
| `agentd-blast-radius` | Find what else one change could break, including what search misses. Runs code to prove the fact that makes the change safe, edits no code, and ends with an add-on block for `agentd-dev-rev`. |
| `agentd-dev-rev` | Build a change with TDD and get up to two independent review rounds. Reads the earlier blocks and the project's review rubric, and reports a risk tier (T0 to T3). Never commits. |
| `agentd-verify-init` | Generate a project skill `verify-<app>` that drives the app like a user, and update it later. It has references for .NET Core and .NET Framework (on IIS Express), SQL Server in Docker or LocalDB, React web apps and iOS apps, with helpers in PowerShell or bash. Only the .NET Core, Docker and React path has been run end to end. The rest is written from general knowledge and one iOS prototype. |
| `agentd-pr-prep` | Write a PR title and description from the branch diff. Follows the repository's PR template, and adds Root cause and Risks only from a pasted diagnose or blast-radius block. |

### Side tools

| Skill | Purpose |
|---|---|
| `agentd-explain` | Explain a business term, a figure, a status or a whole domain, with the code path from the screen to the database or external system. Read only, apart from an export you ask for. |
| `agentd-data-fix` | Turn a work item into a safe, re-runnable data fix, written in chat: look queries, a guarded script, a reverse script and check queries. Never runs anything against a database. |
| `agentd-pr-review` | Review a teammate's PR when you are the approver, against the work item or the PR's inferred intent. Runs the tests and writes paste-ready comments marked Block, Major or Minor. Edits no code and posts nothing. |
| `agentd-review-rubric` | Write or refresh a project's review rubric, `review-rubric.md`, from the repository's own norms and your answers. `agentd-pr-review` and `agentd-dev-rev` cite its criteria. Never edits `AGENTS.md`. |
| `agentd-handoff` | Stop a long task and continue later. Writes one dated file with the status, the next steps and a resume prompt. Edits no code and never commits. |
| `agentd-resume` | Continue a task that `agentd-handoff` stopped. Checks the branch, commit and working tree against the hand-off file, and starts the next steps only after you agree. Never commits. |
| `agentd-prompt` | Rewrite a rough prompt into a clearer one without running it. |

Older Copilot CLI versions cannot load these skills; see [Known limits](#known-limits).

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

## Project skills in customer repositories

A skill that only makes sense for one project belongs in that project's own repository, not here. This keeps client
details out of this repository.

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

With the policy `none`, `agentd-verify-init` writes the project skill to `~/.agents/verify/<app>/` and records the
folder in `~/.agents/verify-skills.tsv`, keyed like the onboarding pack. `agentd-dev-rev` and update mode look there
after the repository folders. The skill offers two links, in `~/.agents/skills` and `~/.claude/skills`, and makes them
only if you agree.

### Where the onboarding pack lives

The second answer sets the pack folder. The pack holds the brief (`README.md`), the project contract (`contract.md`),
`feature-to-code.md`, `open-questions.md` and any side files.

| Files allowed in the repository | Pack folder | How other skills find it |
|---|---|---|
| Committed | `docs/onboarding/`, committed through the normal pull request | They look for `docs/onboarding/README.md`. |
| Local only | `docs/onboarding/`, listed in `.git/info/exclude` | The same. |
| None | A folder outside the repository, by default the one `onboarding-pack suggest` prints (`~/.agents/projects/<name>-<hash>/onboarding`) | `onboarding-pack find` prints the folder that `onboarding-pack set` recorded. |

With the policy `none`, nothing is written into the repository, not even `.git/info/exclude`. The registry line lives
in `~/.agents/onboarding-packs.tsv` on your machine. A second clone of the same repository finds the same pack. On a
new machine, a skill that finds no pack asks you for the folder once and tells you the `onboarding-pack set` command.
Do not record a folder inside another clone of the same repository: `onboarding-pack set` cannot see that clone.
A clone by SSH and a clone by HTTPS of an Azure DevOps repository can get two different keys, because the two URLs
have different paths. Record the folder once for each.

## Set up a new machine

Tested on macOS. On Windows 11 in Git Bash, the installer and the skills were tested in Claude Code, Copilot CLI and
Codex. Linux is not tested.

> **On Windows, Codex gets no shell safety hook.** Use Claude Code or Copilot CLI for the agentd skills there. See
> [Known limits](#known-limits).

1. Install Claude Code, Copilot CLI and Codex, and start each once so `~/.claude`, `~/.copilot` and `~/.codex`
   exist. A tool you do not use is skipped.
2. Clone this repository, for example to `~/Projects/agent-skills`.

   Read `global/AGENTS.md` before you install. The installer makes it the global guide of all three tools, for
   every project. It holds one engineer's working rules, such as asking before any delete and never committing
   without being told. Change it in your clone if your rules differ.
3. Install `jq` (`brew install jq`). The shell hook needs it.

   On Windows, run every step in Git Bash, and install `jq` with `winget install jqlang.jq`. Turn on Developer Mode
   first (Settings > System > For developers). Git Bash can then make real symlinks. Without it, `ln -s` makes copies,
   a copy goes stale after `git pull`, and Claude Code does not get the skills. So the installer stops and asks for
   Developer Mode. If an earlier run made copies, the installer reports each one as a `CONFLICT (identical copy)`.
   Run `./install.sh --apply --adopt` to replace them with links.
   If `./install.sh` stops with `/usr/bin/env: 'bash\r': No such file or directory`, the clone has CRLF line endings.
   Commit any changes you made in the clone, then run `git rm -r --cached -q . && git reset --hard` in its top folder.
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

   `--adopt` moves the existing item to `~/.agent-skills-backup/<time>/` and puts
   the repository version in its place. It never deletes anything.

7. In Codex, run `/hooks` once and trust the two agentd entries. Codex skips a new or changed hook until you trust
   it, so the shell safety hook does not run in Codex before this step.
8. Install the plugins listed at the end of the plan by hand. The script prints
   them from `setup.manifest` and never installs them, because plugin commands
   change between versions.
9. Sign in to each tool again. Credentials are not stored here.

Options:

| Option | Effect |
|---|---|
| (none) | Show the plan. Change nothing. |
| `--apply` | Create the missing links and files. Leave conflicts alone. |
| `--adopt` | With `--apply`, move conflicting items to the backup folder and put ours in their place. |
| `--harness LIST` | Limit to some of `claude-code`, `copilot-cli` and `codex-cli` (comma separated). |
| `--always-on-guard` | Opt in to the [always-on guard](#always-on-guard-optional). Off by default. |

Claude Code reads `$CLAUDE_CONFIG_DIR` when it is set. Some setups use a second
folder, for example `~/.claude-work` for a company account. Each folder needs its
own links, so a skill you add later is missing from any folder the installer did not
link. To link every folder in one run, list them once in `~/.agents/claude-config-dirs`,
one absolute path per line (`~/` works; blank lines and lines starting with `#` are skipped):

```
~/.claude
~/.claude-work
```

Then `./install.sh --apply` links all of them. A folder that does not exist yet is skipped with a warning.
The installer also warns about any `~/.claude*` folder that holds a `skills` folder or a `CLAUDE.md` and is not on
the list. It links nothing there until you add the folder to the list.

`CLAUDE_CONFIG_DIR` (one folder) and `CLAUDE_CONFIG_DIRS` (folders separated by colons) add folders to the list too.
Use absolute paths or paths that start with `~/`. Without the file or either variable, the installer uses `~/.claude`.

## Shell safety hook

`block-dangerous-shell.sh` is the shell safety hook for the agentd skills. By design, it checks shell commands only
in a session that has started an agentd skill. An ordinary session uses the tool's own permission prompts, unless
you turn on the [always-on guard](#always-on-guard-optional). Each tool gets the hook a different way:

| Tool | Where the hook is set | When it checks commands |
|---|---|---|
| Claude Code | The `hooks:` block in each agentd `SKILL.md`. Nothing is added to `settings.json`. | From the moment an agentd skill starts until the session ends |
| Copilot CLI | `~/.copilot/hooks/git-safety.json` | From the moment an agentd skill starts (see below) |
| Codex | `~/.codex/hooks.json` | From the moment an agentd skill starts (see below) |

### When Copilot and Codex check commands

Copilot and Codex cannot attach a hook to a skill, so their hook file runs in every session. It stays dormant until
you start an agentd skill, by typing `/agentd-<name>` or `$agentd-<name>`, or through Copilot's skill tool. From then
on it checks every shell command in that session, also after you resume the session. A skill from another kit with an
`agentd-` name does not wake it.

### Rules

**Denied:**

- A `git push` that overwrites or deletes remote branches: `-f`, `--force`, `--force-with-lease`,
  `--force-if-includes`, `-d`, `--delete`, `--mirror`, `--prune`, or a refspec that starts with `+` or `:<name>`.
- `git reset --hard`.
- A forced `git clean`.
- `git branch -D`, `-M` or `-f` (force delete, rename or move).
- A forced `git checkout` or `git switch`.
- `git checkout .` and `git restore .`.

The deny rules also catch common disguised forms, such as `git -C <path> push -f`, `bash -c 'git push -f'` or a
quoted flag.

**Asks first** (in Codex, a deny that tells the agent to leave the command to you):

- Removing files: `rm`, `rmdir`, `unlink`, `trash`, `shred`, `find -delete`, and the PowerShell `Remove-Item`, `ri`,
  `del`, `erase` and `rd`.
- Rewriting history or dropping a stash: `git rebase`, `git filter-branch`, `git stash drop` and `git stash clear`.
- Discarding changes: `git checkout -- <path>` and `git restore`.
- Writing to a database: `sqlcmd` or `Invoke-Sqlcmd` with an `INSERT`, `UPDATE`, `DELETE`, `DROP`, `TRUNCATE`,
  `ALTER`, `MERGE`, `CREATE`, `EXEC` or `EXECUTE` in the command.

**Passes** (no deny and no ask):

- A plain `git push`, including a bare `:` refspec, which pushes the matching branches.
- `git commit`.
- The pull request commands: `gh pr create`, `gh pr merge`, `az repos pr create`, `az repos pr update` and `gh api`.
- Any other command. The hook prints nothing, so the tool applies its default.

**Not caught:**

- A SQL script passed with `-i`, which is not read. Nor `bcp ... in` or `dotnet ef database update`.
- A command in a variable (`g=git; $g push -f`) or a git alias (`git -c alias.p=push p -f`).
- A force or mirror push set in git config (`git -c remote.origin.mirror=true push`, or a `+` refspec in
  `remote.<name>.push`).
- A quote inside a flag (`git push -""f`), brace expansion (`git push {-f,}`), or a flag after a quoted `;`, `&` or
  `|` (`git push -o 'a|b' --force`).
- A script run with `bash script.sh`, or a Python one-liner that calls `subprocess` or `shutil.rmtree`.
- `mv` to a temp folder, truncation with `: >`, `rsync --delete`, and `git reflog expire` with `git gc --prune`.
- `git worktree remove --force`, `git stash`, `sqlpackage` and `osql`.

In a checked session the hook denies when `jq` is missing or it cannot read the command. In a dormant session it
stays silent then too. A command word inside a quoted message can cause a false deny or ask, which is accepted as
safe. A regex cannot catch every shell form, so treat the hook as a guard rail, not a sandbox.

### Always-on guard (optional)

By default, the shell safety hook checks commands only inside an agentd skill. The installer adds no hook that
acts in an ordinary session. The strongest protection against an unwanted push does not depend on any agent:
turn on branch protection for the main branches on the remote server.

If you also want the agent stopped in every session, opt in to the always-on guard:

```bash
./install.sh --apply --always-on-guard
```

What it does:

- It writes one empty file, `~/.agents/always-on-guard`. The hook checks for this file on every shell command.
- While the file exists, every Copilot CLI and Codex session gets the deny rules. So does every Claude Code session,
  once you merge the snippet below. The deny rules are: a forced or deleting `git push`; `git reset --hard`; a forced `git clean`;
  `git branch -D`, `-M` or `-f`; `git checkout -f`, `-B` or `.`; `git switch -C`, `--force`, `--force-create` or
  `--discard-changes`; and `git restore .`.
- The ask rules (removing files, rewriting history, discarding changes, SQL writes) still run only inside an
  agentd skill.
- Outside an agentd skill, the guard stays silent when it cannot read the command, for example when `jq` is
  missing. So it never blocks an ordinary session for that reason, but it then checks nothing. The installer warns
  when `jq` is missing, and the hook writes a line to the tool's hook log.

Per tool:

- **Copilot CLI and Codex:** nothing more to do. Their hook files already run in every session and read the file.
- **Claude Code:** the installer never edits `settings.json`, so it prints a snippet. Merge it into the `"hooks"` of
  the `settings.json` in each Claude Code configuration folder the installer names. These are the folders it links:
  `~/.claude`, `$CLAUDE_CONFIG_DIR`, `$CLAUDE_CONFIG_DIRS` and `~/.agents/claude-config-dirs`. A later run with the
  flag reports `ok` for a folder that holds the entry, and prints the snippet only for a folder that lacks it. The
  snippet is also in `hooks/claude/always-on.settings.json`.

**To turn the guard off, delete the file yourself:**

```bash
rm ~/.agents/always-on-guard
```

The guard stops at once in all three tools. Then remove the Claude Code snippet from each `settings.json` too. A
leftover snippet does nothing while the file is gone, and it stays silent if the hook script is missing, for example
after you remove this repository. Running `./install.sh` again without the flag does not turn the guard off. The
installer never deletes anything, and while the file exists it prints a note that the guard is on.

The guard can also deny a harmless command. A command word inside quoted text counts, so a commit message, a pull
request body or an `echo` that names `git push --force` is denied too. Inside agentd skills this was always the case; with
the guard it happens in every session. Reword the text, or run that command yourself.

The same limits apply as for the hook inside agentd skills: a regex cannot catch every shell form (see
[Rules](#rules)), and on Windows Codex cannot start the hook (see [Known limits](#known-limits)).

## How the links work

```
repo/skills/<name>  <-  ~/.agents/skills/<name>  <-  ~/.claude/skills/<name>
repo/global/AGENTS.md  <-  ~/.agents/AGENTS.md  <-  ~/.copilot/copilot-instructions.md
repo/global/AGENTS.md  <-  ~/.agents/AGENTS.md  <-  ~/.codex/AGENTS.md
repo/global/claude/CLAUDE.md  <-  ~/.claude/CLAUDE.md   (imports ~/.agents/AGENTS.md)
repo/global/bin/rm-scratch  <-  ~/.agents/bin/rm-scratch
repo/global/bin/onboarding-pack  <-  ~/.agents/bin/onboarding-pack
repo/hooks/copilot/block-dangerous-shell.sh  <-  ~/.agents/hooks/block-dangerous-shell.sh
repo/hooks/copilot/git-safety.json.tmpl  ->  ~/.copilot/hooks/git-safety.json   (rendered copy)
repo/hooks/codex/hooks.json.tmpl  ->  ~/.codex/hooks.json   (rendered copy)
```

- `~/.agents/skills` is the shared home. Copilot CLI reads it from version 1.0.11. Claude Code does not, so it gets
  links in `~/.claude/skills` (or `$CLAUDE_CONFIG_DIR/skills`).
- `git-safety.json` and the Codex `hooks.json` hold an absolute path, so the script writes rendered copies. It replaces
  `@HOME@` with your home folder. Codex reads only one `hooks.json`, so an existing, different file is a `CONFLICT`.
  Merge our two entries into it by hand, or use `--adopt` to move it aside. `--adopt` moves your other Codex hooks
  aside too, so merge by hand when the file has hooks of your own. A file that holds both agentd entries, with the
  same command and matcher, is reported as `ok`, whatever other hooks it has. This check needs `jq`.
- An existing `~/.codex/AGENTS.md` that is not the link, such as one with an `@` import, is a `CONFLICT` too. Codex
  does not follow `@` imports, so use `--adopt` to move it aside and link the guide.
- `rm-scratch` removes one temp file or folder that an agent made with `mktemp`, and refuses anything else. The
  global guide tells agents to use it.
- `onboarding-pack` records where a project's onboarding pack, or its generated verify skill, lives when the customer
  allows no agent files in the repository. See [Where the onboarding pack lives](#where-the-onboarding-pack-lives).
- Edit skills in this repository, not through the links. `git pull` then updates all three tools.

## Remove the setup

There is no uninstall script yet. The installer adds only links and a few files, so you can remove them by hand.
Work in this order, so no hook file is left calling a script that is gone.

1. If the always-on guard is on, delete `~/.agents/always-on-guard` and remove the snippet from each Claude Code
   `settings.json`.
2. Remove `~/.copilot/hooks/git-safety.json` and `~/.codex/hooks.json`. If you merged our two entries into a
   `hooks.json` of your own, remove only those two entries.
3. Remove the links (see [How the links work](#how-the-links-work)). Remove each one with `rm <path>`, with no `-r`
   and no trailing `/`, so `rm` removes the link and not the files it points to:
   - in `~/.agents/skills` and in the `skills` folder of each Claude Code folder: one link for each folder in your
     clone's `skills/`. Another kit may add its own `agentd-` skills there, so do not remove by name pattern.
   - in each Claude Code folder: `CLAUDE.md`
   - `~/.agents/AGENTS.md`, `~/.agents/bin/rm-scratch`, `~/.agents/bin/onboarding-pack` and
     `~/.agents/hooks/block-dangerous-shell.sh`
   - `~/.copilot/copilot-instructions.md` and `~/.codex/AGENTS.md`
   - any `verify-<app>` links that `agentd-verify-init` made with your agreement, in `~/.agents/skills` and
     `~/.claude/skills`
4. If you ran `--adopt`, your earlier files are in `~/.agent-skills-backup/<time>/`, under the same path relative to
   your home folder (for example `~/.agent-skills-backup/<time>/.claude/CLAUDE.md`). Move back the ones you want.

The skills and scripts also make files as you work. You can keep them or remove them:

- `~/.agents/hook-state/`, `~/.agents/onboarding-packs.tsv` and `~/.agents/verify-skills.tsv`
- onboarding packs outside a repository, by default in `~/.agents/projects/<name>-<hash>/onboarding`
- verify skills outside a repository, in `~/.agents/verify/<app>/`
- verify evidence, in `~/.<app>-verify/<ticket>/<timestamp>/`
- `~/.agents/claude-config-dirs`, if you made it

Packs and verify skills hold project knowledge, and verify evidence may hold customer data. Check them before you
delete them.

## Known limits

- **No shell safety hook in Codex on Windows.** Codex runs the hook, but cannot start the script there, so it lets
  every command through, even in an agentd session. The hook works in Claude Code and Copilot CLI on Windows. Until
  this is fixed, use Claude Code or Copilot CLI for the agentd skills on Windows.
- **Keep your clone where it is.** The installed links point into it. If you move or delete the clone while the setup
  is installed, Copilot CLI denies every shell command and every skill call in every session until you fix the link,
  and Codex lets every command through. Claude Code should block the command, but this is not yet checked live (see
  below).
- **Home folder path.** The installer writes no hook file when your home folder path holds a `"`, `$`, `` ` `` or
  `\`, because the hook command cannot quote it. It warns instead.
- **Copilot CLI versions.** Tested on Copilot CLI 1.0.110 on 2026-11-16: Copilot's skill tool reports that a flagged
  skill exists and that the model cannot start it, and a skill you type yourself loads. Copilot CLI 1.0.102 could not
  load a flagged skill at all ([github/copilot-cli#4438](https://github.com/github/copilot-cli/issues/4438)), so
  update Copilot if a skill is not found. The generated project skill `verify-<app>` is written without the field, so
  older Copilot versions load it too.
- **Shell safety hook, not yet checked live:**
  - whether a subagent that an agentd skill starts is checked. Claude Code may not carry a skill's hook into a
    subagent, and Codex may give the subagent its own session ID;
  - whether Claude Code keeps a skill's hook after `claude --resume` or after the conversation is compacted;
  - whether Claude Code blocks a command when the hook script cannot run (`onFailure: block`) for a hook in a
    skill's frontmatter.
- **Repositories on a network mount.** A repository on a network mount (for example a Windows drive mounted on a
  Mac) may need git to run on the other machine. The skills run git where they start. Follow that repository's own
  `AGENTS.md` for its git rules.
- **Linux** is not tested.

## Credits

Most ideas in these skills come from my day-to-day work as a sustained engineering consultant, supporting and fixing
live customer applications. I also took some patterns from two other sources:

- [pstack](https://github.com/cursor/plugins/tree/main/pstack), the official Cursor plugin.
- [Superpowers](https://github.com/obra/superpowers), a skills plugin for Claude Code.

I borrowed patterns from them, such as the structure of a skill and the habit of reproducing a bug before fixing it.
The skill text is written in my own words. Superpowers is also listed in `setup.manifest`.

## License

MIT. See [LICENSE](LICENSE).
