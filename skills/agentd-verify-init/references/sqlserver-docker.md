# SQL Server in Docker

Load this file in Flow step 5, when the database is SQL Server. It says how the helpers start the database, import a bacpac and check the migration journal. These notes come from general knowledge of the platform. They are not yet checked on a project. Treat each row as a place to look first, not a guarantee. Mark a recipe built only from these notes `inferred:`. The `db-restore.ps1` helper and the state check lean on the migration runner contract in `references/dotnet.md` (`dbup-run.ps1`). With another runner, write the equivalent helper and mark it `inferred:`.

## Database in Docker

- Use the SQL Server image the integration tests use. Read its tag from the test fixture. Use `mssql/server`, which has `sqlcmd`, never `azure-sql-edge`.
- One container per ticket, with a unique name and its own host port. Do not use 1433.
- Label each container when it is created, with the exact ticket: `--label <app>-verify.ticket=<ticket>`. A container is this ticket's only when that label and the container ID in `state.json` both match (the resource ownership rule in `templates/helpers.md`). A container made without the label is refused, even when its ID matches. This includes every container made before this rule: the `blocked:` message prints `docker rm <container ID>` for the engineer, and the next run makes a new one.
- Make the `sa` password per container. Store it only in the container configuration, and read it back with `docker inspect`. Never write it to a file in the repository. Never put it on a command line: `docker create` and `docker exec` take it by name from the helper's own environment (`-e MSSQL_SA_PASSWORD`, `-e SQLCMDPASSWORD`, with no value).
- Read-only queries: a query the agent writes runs only against the per-ticket database, as a database user that is a member of `db_datareader` only. Create that user (`CREATE USER <reader> WITHOUT LOGIN`, then add it to `db_datareader`) when the database has none, which is the case after every drop and every import. After every create, drop and import, check that the user is a member of `db_datareader` only and holds no permission other than `CONNECT`, because a bacpac can bring a user with the same name and more rights. Any other result is `blocked:`, naming the user. Start the query batch with `EXECUTE AS USER = N'<reader>' WITH NO REVERT`, so the query cannot switch back to `sa`. Run `sqlcmd` with `-x`, so `$(NAME)` reads no environment variable, and with `-X`, which turns off `!!` and `ED`. Refuse a query that holds `$(`, or a line whose first characters after any spaces or tabs are `:` or `!!`: these are `sqlcmd` commands, and `:connect` opens a new session outside `EXECUTE AS`. `inferred:`
- This user cannot call a scalar function or a procedure. A procedure that a feature file marks read-only runs through its own helper call as `sa`, inside a transaction that the helper always rolls back. It never runs through the read-only query route. `inferred:`
- On Apple Silicon, turn on Rosetta in Docker Desktop and pull the `linux/amd64` image. Put these steps in the Gotchas of the generated skill. Add the `--platform linux/amd64` flag to `docker run`.
- Wait until `sqlcmd` can run a query before starting the runner. An open port is not enough.

## Bacpac

Use a test-environment `.bacpac` only when the ticket needs specific data. Ask the engineer for its path at run time. Never write a path to a file in the repository.

1. Find `SqlPackage` by the `SQLPACKAGE_PATH` environment variable, then on `PATH`. If it is not on PATH, ask the engineer to set the variable. An agent shell does not load the profile that adds the tool.
2. Import the bacpac into the container with `SqlPackage /Action:Import`. SqlPackage takes the password only in its arguments (`/TargetPassword` or `/TargetConnectionString`), so prefer an import that keeps it off every command line. In PowerShell, load DacFx (`Microsoft.SqlServer.Dac.dll`, in a build that matches the PowerShell runtime) and call `DacServices.ImportBacpac` in the helper's own process, with the connection string built in memory. `inferred:` no project has run this route. When the helper cannot load DacFx (bash, for example), SqlPackage gets the password in its arguments while the import runs. Put that exposure in the Gotchas of the generated skill.
3. Before the upgrade, run the journal check with a read-only SELECT on the journal table. Read the journal's name format from the runner code (embedded scripts are often journalled as `<Project>.<Folder>.<file>.sql`, not as paths), and map each branch script path to that name before the compare. Build the base script list with `git ls-tree -r --name-only <merge-base sha> <scripts folder>`. If the journal already lists a branch script (a script the branch adds or changes), the test environment ran an earlier version of it and the runner would skip it. The result is `blocked`. The engineer picks an older bacpac or another data source.
4. List journal entries that are on neither the base nor the branch under Environment and under Not verified.
5. Run the runner in upgrade mode, never reset. A reset flag (`--reset`) drops the database and the imported data with it.

## db-start.ps1

Parameters: ticket, data source (`empty`, or the bacpac file name and its date), merge-base sha, scripts folder, and the
switch `-ConfirmRestore`.
Starts the SQL Server container for the ticket, or reuses the one in `state.json` when the ownership check passes, and does the state check. Prints the
container name, image tag, host port, the container ID, and one of `database: new`, `database: reused` or
`database: dropped`.

- Use the same SQL Server image the integration tests use, and never azure-sql-edge. It must have `sqlcmd`.
- One container per ticket, with a unique container name and a host port other than 1433. The container is kept between
  runs. Containers for several tickets may exist side by side.
- Make the password per container. Read it back with `docker inspect`. Never write it to a file, and never put it on a
  command line.
- Wait until `sqlcmd` can run a query. An open port is not enough.
- Ownership check: before it reuses or connects to a container, the container must carry the ticket label with the
  exact ticket, and its ID must equal `containerId` in `state.json`. A container with the ticket's name that fails
  either check is left alone. The helper ends with `blocked:`, names the container, and never records its ID. It
  prints `docker rm <container ID>` for the engineer to run after they check that nothing else uses the container. One
  exception: when `state.json` records no container (the file was lost), the helper may take a container that carries
  this ticket's label, but only after a fresh restore that the engineer confirms. Every helper that connects to the
  container makes the same check, so put it in `common.ps1`.
- State check: compare the container ID, the branch-script hashes (`Get-BranchScripts`, which needs the scripts folder),
  the app-code fingerprint and the data source with `state.json`. This helper owns the check. When it forces a fresh
  restore, print `fresh restore needed: <reason>`, so the report can say that a restore happened and why. The helper
  writes `containerId` and `createdAt` when it creates the container, and writes `dataSource` only after the state check
  passes or after a confirmed drop, never on a `blocked` exit. With a bacpac data source on a new or dropped database,
  it writes `pending: <bacpac file name and date>`, because the import has not run yet. `db-restore.ps1` replaces it
  with the plain value when it ends with `ok`. A `pending:` value at the next start forces a fresh restore
  (`fresh restore needed: an earlier import did not finish`).
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

- Find `SqlPackage` by the `SQLPACKAGE_PATH` environment variable, then on `PATH`. Keep the password off its command
  line when the helper can (step 2 of the Bacpac section).
- The import counts only when it exits with 0. The journal check counts only when its query exits with 0. A failed
  query ends with `blocked:`, never with an empty journal.
- When the import and the journal check both pass, it writes `dataSource` as the plain value and ends with `ok`. On
  any `blocked:` exit it leaves the `pending:` value, so `dbup-run.ps1` refuses to run and the next `db-start.ps1` drops
  the database again.
- Do the journal check with a read-only SELECT after the import and before the upgrade. Find the branch scripts with
  `Get-BranchScripts`, from the merge-base sha and the scripts folder, and map each path to the journal's name format
  (the Bacpac section above). If the journal already lists a branch script, stop with `blocked`: the test environment ran an earlier version, and the upgrade would skip it. The
  engineer picks an older bacpac or another data source.
- List journal entries that are on neither the base nor the branch: the entries on neither the base nor the branch go
  under Environment and under Not verified in the report ("the test environment ran scripts not on this branch").
- Never reset. The upgrade always follows in `dbup-run.ps1`.

