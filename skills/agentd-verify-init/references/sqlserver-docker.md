# SQL Server in Docker

Load this file in Flow step 5, when the database is SQL Server. It says how the helpers start the database, import a bacpac and check the migration journal. These notes come from general knowledge of the platform. They are not yet checked on a project. Treat each row as a place to look first, not a guarantee. Mark a recipe built only from these notes `inferred:`. The `db-restore.ps1` helper and the state check lean on the migration runner contract in `references/dotnet.md` (`dbup-run.ps1`). With another runner, write the equivalent helper and mark it `inferred:`.

## Database in Docker

- Use the SQL Server image the integration tests use. Read its tag from the test fixture. Use `mssql/server`, which has `sqlcmd`, never `azure-sql-edge`.
- One container per ticket, with a unique name and its own host port. Do not use 1433.
- Make the `sa` password per container. Store it only in the container configuration, and read it back with `docker inspect`. Never write it to a file in the repository.
- On Apple Silicon, turn on Rosetta in Docker Desktop and pull the `linux/amd64` image. Put these steps in the Gotchas of the generated skill. Add the `--platform linux/amd64` flag to `docker run`.
- Wait until `sqlcmd` can run a query before starting the runner. An open port is not enough.

## Bacpac

Use a test-environment `.bacpac` only when the ticket needs specific data. Ask the engineer for its path at run time. Never write a path to a file in the repository.

1. Find `SqlPackage` by the `SQLPACKAGE_PATH` environment variable, then on `PATH`. If it is not on PATH, ask the engineer to set the variable. An agent shell does not load the profile that adds the tool.
2. Import the bacpac into the container with `SqlPackage /Action:Import`.
3. Before the upgrade, run the journal check with a read-only SELECT on the journal table. Read the journal's name format from the runner code (embedded scripts are often journalled as `<Project>.<Folder>.<file>.sql`, not as paths), and map each branch script path to that name before the compare. Build the base script list with `git ls-tree -r --name-only <merge-base sha> <scripts folder>`. If the journal already lists a branch script (a script the branch adds or changes), the test environment ran an earlier version of it and the runner would skip it. The result is `blocked`. The engineer picks an older bacpac or another data source.
4. List journal entries that are on neither the base nor the branch under Environment and under Not verified.
5. Run the runner in upgrade mode, never reset. A reset flag (`--reset`) drops the database and the imported data with it.

## db-start.ps1

Parameters: ticket, data source (`empty`, or the bacpac file name and its date), merge-base sha, scripts folder, and the
switch `-ConfirmRestore`.
Starts the SQL Server container for the ticket, or reuses the one in `state.json`, and does the state check. Prints the
container name, image tag, host port, the container ID, and one of `database: new`, `database: reused` or
`database: dropped`.

- Use the same SQL Server image the integration tests use, and never azure-sql-edge. It must have `sqlcmd`.
- One container per ticket, with a unique container name and a host port other than 1433. The container is kept between
  runs. Containers for several tickets may exist side by side.
- Make the password per container. Read it back with `docker inspect`. Never write it to a file.
- Wait until `sqlcmd` can run a query. An open port is not enough.
- State check: compare the container ID, the branch-script hashes (`Get-BranchScripts`, which needs the scripts folder),
  the app-code fingerprint and the data source with `state.json`. This helper owns the check. When it forces a fresh
  restore, print `fresh restore needed: <reason>`, so the report can say that a restore happened and why. The helper
  writes `containerId` and `createdAt` when it creates the container, and writes `dataSource` only after the state check
  passes or after a confirmed drop, never on a `blocked` exit.
- Fresh restore: drop and recreate the per-ticket database. The helper then clears `branchScripts` and `recipes` in
  `state.json`. It never drops any other database. It never imports a bacpac: `db-restore.ps1` does. The migration
  upgrade is `dbup-run.ps1`.
- In a terminal, the helper prompts the engineer before it drops. An agent without a terminal asks the engineer and runs
  the helper again with `-ConfirmRestore`. Without the switch and without a terminal, the helper refuses with `blocked`
  and never drops: it ends with `blocked: fresh restore needed: <reason>`. With `-ConfirmRestore` and no forced reason,
  the helper drops and recreates the database on request.
- Data made by SQL, not through the app, needs the engineer's approval for each insert, and the report marks it "made by
  SQL, not through the app".

## db-restore.ps1

Parameters: ticket, bacpac path (asked at run time, never stored in a file), merge-base sha, scripts folder. Used only
when the data source is a bacpac and `db-start.ps1` printed `database: new` or `database: dropped`. Imports the bacpac
and checks the journal. Prints the number of journal entries and each entry that is neither the base nor the branch.

- Find `SqlPackage` by the `SQLPACKAGE_PATH` environment variable, then on `PATH`.
- Do the journal check with a read-only SELECT after the import and before the upgrade. Find the branch scripts with
  `Get-BranchScripts`, from the merge-base sha and the scripts folder, and map each path to the journal's name format
  (the Bacpac section above). If the journal already lists a branch script, stop with `blocked`: the test environment ran an earlier version, and the upgrade would skip it. The
  engineer picks an older bacpac or another data source.
- List journal entries that are on neither the base nor the branch: the entries on neither the base nor the branch go
  under Environment and under Not verified in the report ("the test environment ran scripts not on this branch").
- Never reset. The upgrade always follows in `dbup-run.ps1`.

