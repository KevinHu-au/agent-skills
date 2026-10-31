---
name: agentd-verify-init
description: Use when the engineer wants a project skill that drives the real application the way a user does and returns an evidence report for a ticket. Run it once per project to create the skill, and again later to update it.
disable-model-invocation: true
---

# agentd-verify-init

Generate the project skill `verify-<app>`. The engineer runs it after `/agentd-dev-rev`, in a fresh session, to get a
second check of a change that does not depend on the developer's own reasoning. The generated skill starts the app,
lets the engineer sign in, drives the changed feature through the user interface, and writes an evidence report. This
skill never verifies a ticket itself. Read the references and templates named in the Flow when you reach that step.

## Prerequisite

- The current folder is inside a git repository. Find its root with `git rev-parse --show-toplevel`.
- **Find the project facts.** The onboarding pack is `docs/onboarding/` when `docs/onboarding/README.md` exists.
  Otherwise it is the folder that `"$HOME/.agents/bin/onboarding-pack" find` prints. If neither finds one, ask the
  engineer once for the folder, and carry on without a pack if there is none or nobody answers. When the engineer
  gives a folder, say that `"$HOME/.agents/bin/onboarding-pack" set <folder>` records it. The project contract is
  the `## Project contract` section of `AGENTS.md`, or else `contract.md` in the pack. When both exist and disagree,
  use `AGENTS.md` and mark the fact `conflict:`. A Data access rule counts only when it cites `told by <role>` or a
  document. Treat any other rule, such as one marked `inferred:` or `unknown:`, as no access.
- Sources, in this order: the pack's `README.md`, the project contract, then the code. If the pack or the contract is
  missing, say so once and carry on from the code.
- Find the harness: how the app starts, the ports it uses, how a user signs in, and which scripting language the
  repository already uses. Helpers are written in that language.
- The engineer should be at the keyboard. The proof run in Flow step 7 needs a person to sign in.

## Modes

- **Create:** no marked `verify-*/SKILL.md` exists under a `.github/skills/` or `.claude/skills/` folder. Then look for `verify-*/SKILL.md` under the folder that `"$HOME/.agents/bin/onboarding-pack" verify-find` prints. Exit status 1 means none is recorded; for any other failure (the folder is gone, the tool is missing), say so in the reply and carry on without it. Run the Flow when neither place has one.
- **Update:** one exists, in either place, and its header carries the marker below, so this skill wrote it. Follow
  `references/update-mode.md` instead of the Flow. Edit only that skill's folder. Check the feature map against the
  code, drive every feature once, unless no code changed since the scan and the skill is not a draft (then stop and change nothing), and list
  product regressions apart from map corrections. The engineer commits through the normal pull request.
- An unmarked `verify-*` skill is the customer's own. Lookup ignores an unmarked skill. Update mode stops and changes
  nothing when it meets one. Create mode stops and asks for another name when its target folder exists without the
  marker. When several marked skills match in one place, list them and ask. A marked skill in the repository wins over one outside it; name the other one in the reply.

## Flow

1. **Read the project.** Read the sources and find the harness. Note the stack. With no
   reference for the stack, ask the engineer and mark each drive recipe `inferred:`.
2. **Ask where the skill lives.** Read the `Repo policy:` line in the pack's `README.md` first, and ask only for a
   part it does not give or gives as `unknown`: the customer's allowed tool (Copilot, Claude, or both) and whether the
   files may be committed.
   - With `files none`, write nothing in the repository, not even `.git/info/exclude`, and do not use the folders below.
     Write the skill to `verify-<app>/` under the folder that `onboarding-pack verify-find` prints. With none recorded,
     take the folder that `onboarding-pack verify-folder <app>` prints, run `mkdir -p` on it before `verify-set`, then
     record it with `onboarding-pack verify-set <folder>` once the engineer agrees. There is one folder per repository,
     and it holds every `verify-<app>/` of that repository: put a second app beside the first. When `verify-set`
     refuses (another repository has the folder), ask the engineer for another folder. When `verify-find` exits 3,
     the recorded folder is gone: say so, ask the engineer, and never write to the default folder instead.
   - If the files policy is not `none`: Copilot only goes in `.github/skills/`. Claude only, or both, goes in
     `.claude/skills/`. Not committed: add the folder to `.git/info/exclude` (the file
     `git rev-parse --git-path info/exclude` prints), never `.gitignore`.
3. **Pick the features.** Find the features from routes, menus and user documents. Rank them by recent change. Always
   include the entry feature. Show about five with a reason each. The engineer confirms, swaps or adds. Load `references/feature-map.md` for the rules
   that pick the features.
4. **Write the feature map and data setup.** One file per feature with user steps only, an index, and named setup
   recipes. The map holds routes, labels and steps, never customer values. For React web projects (a `package.json` that lists `react-dom` under `dependencies`, in
   any workspace) also load `references/react.md`. For an iOS app (the repository has a `*.xcodeproj` or `*.xcworkspace`) also load `references/ios.md`, whose `ui-start.ps1` replaces the one in `references/react.md`. When the repository also has a web UI or an API that the ticket may drive, ask the engineer which one it drives, and load only that reference. Shape the files with `templates/feature-map.md`.
5. **Write the helpers.** Launch and stop the app, start the database, and run the Doctor check. First pick the language of the helpers: the language of the repository's existing scripts, else the shell of the machine that runs them (bash on a Mac, Windows PowerShell on Windows), and ask the engineer when both are possible. The `.ps1` names in the contracts are examples: use the extension of that language. Doctor reports the
   database the running process uses and refuses to drive an API or UI this run did not start. For .NET projects (the repository has `*.sln` or
   `*.csproj` files) also load `references/dotnet.md`. A .NET Framework project (a `web.config`, a `Global.asax`, or a `TargetFrameworkVersion` of `v4.x` in a `*.csproj`) also loads `references/dotnet-framework.md`, whose `api-start.ps1` replaces the one in `references/dotnet.md`. For a SQL Server database (a `dbup-sqlserver`, `Microsoft.EntityFrameworkCore.SqlServer`, `Microsoft.Data.SqlClient` or `System.Data.SqlClient` package, or a SQL Server image in the integration tests; never open a settings file or user secrets to look, and when no signal shows, ask the engineer) also load `references/sqlserver-docker.md`. Ask the engineer where the local database runs. For LocalDB, also load `references/sqlserver-localdb.md`, whose `db-start.ps1` replaces the one in `references/sqlserver-docker.md`. Helpers in PowerShell also load `references/host-powershell.md`; helpers in bash or zsh also load `references/host-shell.md`. Give each helper its contract: `templates/helpers.md` holds the core rules and an index of where the other contracts live. After the parse check, run each helper once with its
   prerequisites missing, except the shared file that is only sourced. It must stop with its own `blocked:` message, not a shell error.
6. **Write the verify skill.** Name it `verify-<app>`. Put this marker in its header, nested exactly:

   ```yaml
   metadata:
     generated-by: agentd-verify-init
   ```

   Build it from `templates/verify-skill.md`. Copy everything under `## Report` and `## Results` of
   `templates/report.md` into its Report section, including the notes and the Order of results. For an iOS app, also copy the section `Three-way match on iOS` of `references/ios.md` after the Order of results. The generated skill
   gets the Verify block, the evidence report and the six independence mechanisms below.
7. **Run the proof run.** With the engineer present: launch, sign-in, Doctor, drive one feature, capture evidence, run
   cleanup, then check the evidence folder still exists. With nobody to sign in, stop at sign-in. Mark the skill
   `draft: not proven` on the first line of the body, and list each step that did not run after `Not proven:`.
8. **Report.** List the files written, where they live, what the proof run showed, and anything marked `inferred:` or
   `unknown:`. Say that the engineer commits through the normal pull request. With `files none`, say instead that nothing is committed, and offer two links so the tools can load the skill. Run `mkdir -p` on each parent folder first, then `ln -s` from `~/.agents/skills/verify-<app>` to the skill folder, and from `~/.claude/skills/verify-<app>` (or `$CLAUDE_CONFIG_DIR/skills`) to the first link. Make them only after the engineer says yes, and never replace an existing path.

## Rules

- Committed files carry no personal paths: find tools on `PATH` or by an environment variable, and ask for a data file
  path at run time. They carry no secrets: no password is written to a file, and the database reference says how it is made. They
  carry no customer values in the feature map.
- The skill never types credentials. The engineer signs in with their own account.
- It must never read, print, copy or change user secrets or any connection string, and never edit a settings file.
  The stack reference says how the app gets its connection string and roles.
- Evidence goes to `~/.<app>-verify/<ticket>/<timestamp>/`, outside every repository. It is never committed and
  cleanup never removes it.
- Each ticket gets its own database, made by this skill, never the engineer's own. The database reference says how it
  starts (for SQL Server: one container per ticket, with its own host port).
- The generated skill names six independence mechanisms: expectations before evidence, a separate verifier in a fresh
  session, three-way match of screen, API and database, recompute the figures on calculation tickets, check the
  neighbours, and try the edges. Expectations never come from the diff.
- A calculation reference is an index to the code, never the oracle. A disagreement is a `conflict:` line, not a fail.
- Results are `fail`, `disagree`, `blocked` and `pass`, one per report, picked in that order.
- Cite `path:line` for every claim about code. Mark what you could not check `unknown:`.
- Always English. Do not start another skill, and do not edit `AGENTS.md`.
