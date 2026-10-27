# .NET backends with SQL Server

Load this file in Flow step 5, when the repository has `*.sln` or `*.csproj` files. It says how the helpers start the API and the database for a .NET project. These notes come from general knowledge of the platform. They are not yet checked on a project. Treat each row as a place to look first, not a guarantee. Mark a recipe built only from these notes `inferred:`.

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

## Doctor

- A project may have no health endpoint and no anonymous route. Say so in the Gotchas.
- With no health endpoint, check four things: the ports answer, the signed-in API user and its roles, the container is running, and the database target.
- Run `SELECT DB_NAME(), @@SERVERNAME` through the API's own connection or the container, and report both values. Do not report what a settings file says.
- Refuse to drive an API or UI this run did not start. Say which process holds the port.
