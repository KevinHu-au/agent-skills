# .NET backends

Load this file in Flow step 5, for a .NET project (the stack signals in Flow step 1 of `SKILL.md`). A Web Site project (no project file) has no `dotnet` build: ask the engineer how it starts, and mark each recipe `inferred:`. It says how the helpers start the API and run the migrations for a .NET project. For a SQL Server database, `references/sqlserver-docker.md` says how the database starts. The `dbup-run.ps1` and `api-start.ps1` contracts and the Doctor section assume the database from the database reference (today, SQL Server in a container). For another database, write these checks for that database and mark them `inferred:`. These notes come from general knowledge of the platform. They are not yet checked on a project. Treat each row as a place to look first, not a guarantee. Mark a recipe built only from these notes `inferred:`.

## Environment variables

- Pass connection strings and roles to the app as environment variables. Never edit a settings file. A double underscore stands for a colon, so `ConnectionStrings__<Name>` sets `ConnectionStrings:<Name>`.
- Environment variables override `appsettings*.json` and user secrets. Find the real source of the value in the startup code (`Program.cs`) before you rely on a file.
- User secrets override `appsettings.Development.json` in the Development environment. Never read, copy or change the user secrets. They may hold client secrets. Doctor reports the database the running process uses, not what a file says.
- A role override list is an array in the configuration, for example `<Section>__RoleClaimOverrides__<i>`. Setting one array index replaces only that index. The rest of the array stays as the files define it.
- For k wanted roles and N entries in the JSON files, set indexes 0..max(N,k)-1, cycling through the k roles. An index past N-1 adds an entry. Read N from the JSON files only, never from user secrets.
- Roles are often a set, so a repeated role collapses. A change of roles restarts the API.
- Compare the role set the API reports with the wanted set exactly. An extra or a missing role is `blocked`. Say that another configuration source may hold more entries, and ask the engineer for their count.
- Check that any switch that turns authorisation off is off before an authorisation feature.

## Migrations

- Find the runner: DbUp (`dbup-sqlserver`, a project with embedded `*.sql` scripts) or EF Core (`Migrations/` folders, `dotnet ef`). The runner code, not the tool name, says whether a script runs inside a transaction.
- The runner may need its settings file in the current directory. Start it from its own project folder.
- DbUp keeps a journal table. The default is `dbo.SchemaVersions`. A script that the journal lists is skipped, even when its text changed. Check the journal setting in the runner code, because a runner may use a null journal for some scripts and run them every time.
- Record the hash of a branch script only after the runner log shows that script ran.
- Run the runner with the connection string of the container as an environment variable.

## Doctor

- A project may have no health endpoint and no anonymous route. Say so in the Gotchas.
- With no health endpoint, check four things: the ports answer, the signed-in API user and its roles, the container is running, and the database target.
- Run `SELECT DB_NAME(), @@SERVERNAME` through the API's own connection or the container, and report both values. Do not report what a settings file says.
- Refuse to drive an API or UI this run did not start. Say which process holds the port.

## dbup-run.ps1

Parameters: ticket, scripts project folder, merge-base sha, scripts folder. Runs the migration tool in upgrade mode from
its own project folder and prints the log lines that name each script that ran. It runs on every run, after
`db-start.ps1`, and after `db-restore.ps1` when that ran. It never takes the place of the bacpac journal check.

- Rule: it must refuse to run unless the connection environment variable is set and names the container's host and
  port. It must never fall back to a settings file, because a settings file can name the engineer's own database.
- Pass the connection string as an environment variable. Never read or print its value.
- After the log shows a branch script ran, record its hash in `state.json`. Not before. Find the branch scripts with
  `Get-BranchScripts`. The helper drops the entries of removed scripts, and writes `appFingerprint` after a successful run.
- Scripts the tool re-runs on every run are not hashed.
- The "DbUp scripts applied" number in the Environment line is the journal row count, read from the database with
  `SELECT COUNT(*)` on the journal table after the run. It is not a count of lines in the log that the helper printed.

## api-start.ps1

Parameters: ticket, roles (a list, or `default`). Starts the API with the container's connection string and the wanted
roles in environment variables. Prints the port and the process ID, and saves the process ID in `state.json`.

- Rule: it must refuse to run unless the connection environment variable is set and names the container's host and
  port. It never falls back to a settings file.
- Roles: for k wanted roles and N entries in the settings JSON, set indexes 0..max(N,k)-1, cycling through the k roles.
  Read N from the JSON files only. A role change restarts the API.
- Refuse to start when something this run did not start already holds the port. Name the process.
- It must not require the plain-HTTP port when the UI only calls the secure port. Pass `--urls` for the secure port
  only. When it refuses, it names the process that holds a port. Some systems hold a fixed port: macOS holds port 5000
  for AirPlay Receiver. Put this port rule in the Gotchas of the generated skill.
