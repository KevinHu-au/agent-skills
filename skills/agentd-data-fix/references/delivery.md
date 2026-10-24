# Delivery tools

Load at step 4. It says how to find the tool that ships a data fix, and what to read in the code. Each section is a
place to start, not a guarantee: the project's own code decides. Cite `path:line` for every fact from the code.

## Find the tool

Look in this order: the onboarding pack, the contract (`AGENTS.md`), then the code. The code shows a DbUp project, an
EF migrations folder, a custom migration runner, or a folder of scripts.

- When the project has two ways, copy the newest earlier data fix: its folder, its name pattern, its layout. A schema
  change in a migration folder does not count as a data fix.
- When it is unclear which way is the data-fix way, ask the engineer. Never pick the way by guessing.
- Read the pipeline for the release order. When the migration tool runs before the app deploy, a code fix that goes out
  with the script leaves the old app running against a script that has already run once, so the code fix ships in an
  earlier release. Otherwise plan a follow-up script and a check query after the deploy.
- Say once when the pack or the contract is missing, and carry on from the code.

## DbUp

How to spot it: a package reference to DbUp, and a call to `DeployChanges`.

- Scripts are embedded resources. Find the embed pattern in the project file. A wildcard such as `Scripts\*.sql` embeds
  the root folder only, so a script in a subfolder never runs. Then no registration step is needed.
- DbUp records each script name in a journal and runs a script once. Local runs of the script text must bypass the
  journal, or the second run proves nothing. - By default there is no transaction. A script is wrapped when the code
  calls `.WithTransactionPerScript()` (one transaction per script) or `.WithTransaction()` (one for the whole run).
  Cite the line. If it is missing, the script opens its own.
- `PRINT` output is not logged unless the code calls `LogScriptOutput()`. Assume the output is lost.
- DbUp splits scripts on `GO`, and variables do not survive across it. Unless the code calls `.WithVariablesDisabled()`,
  DbUp does variable substitution on `$name$` tokens and fails on an undefined one, so keep `$` pairs out of the text.
- Find any script set that has no journal (a `NullJournal`, for example a folder of stored procedures). Such a set runs
  on every deploy, so never put a data fix there.
- The file name sorts with the other scripts. Pick a name that sorts after every existing one, in the project's pattern.
  It also sorts after every script that creates the tables and columns it uses, or a fresh database runs it too early.

## EF migration

How to spot it: a migrations folder with classes that have `Up()` and `Down()` methods.

- A data fix is a new, empty migration with a `Sql(...)` call. In EF Core the call is `migrationBuilder.Sql(...)`.
- `Down()` stays empty or throws, with a comment that points to the pull request notes. The reverse never lives in the
  repository.
- Give the engineer the command to make the migration: `add-migration <Name>` in the Package Manager Console, or
  `dotnet ef migrations add <Name>` for EF Core. The skill does not run it.
- Tell the engineer to check two things. The new `Up()` must hold only the `Sql()` call. The model snapshot must not
  have changed (EF6 keeps the model in the migration's resource file, so check that the generated `Up()` and `Down()`
  were empty before you added the `Sql()` call). If either changed, stop: the model and the database have drifted,
  and that is a schema question.
- No `GO` inside the `Sql()` text. Read how the migration is applied (a transaction per migration is the usual default,
  so check) and when it runs compared with any data scripts.

## Custom runner

How to spot it: a small program that reads `.sql` files from a folder and sends them to the database.

- Check how the runner finds its files. If the project file lists each script with `CopyToOutputDirectory` set to
  `Always`, a file without that block is never copied and never runs.
- Scripts run in text order, not number order: `2000-` sorts before `900-`. Warn when the new script depends on an
  earlier one.
- Read whether the runner sends the whole file as one command. If it does, `GO` fails, and one timeout covers the whole
  script. Read the timeout value.
- Read whether a transaction wraps the script. If not, the script opens its own `BEGIN TRAN` and `COMMIT`.
- A history table records the script only after it succeeds, so a half-run script runs again on the next deploy. Every
  statement must be guarded.
- When the runner also applies schema migrations first, a data script that times out fails the release after the
  schema change already ran.

## Plain script

No tool found: write a plain script. Ask the engineer how it reaches production (a ticket to a database team, a
release step, a manual run), then write the placement steps for that path. State plainly that the safety of the run
rests on the guards in the script, because nothing records that it ran.

## Read the runner

Open the runner code and cite `path:line` for each of these, so the script fits the way it runs:

- The transaction mode: wrapped per script, wrapped per run, or none.
- The output: whether `PRINT` text or a row count is logged or shown, or dropped.
- The run order: how scripts are sorted, and where a new file name falls.
- The timeout, and whether the whole file is one command.
- When the journal or history table is written: before the script, or only after it succeeds.
- The pipeline order: whether the migration tool runs before the app deploy.
