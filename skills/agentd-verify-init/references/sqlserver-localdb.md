# SQL Server LocalDB

Load this file in Flow step 5, when the engineer says the local database runs in LocalDB (Windows). It replaces the `db-start.ps1` contract in `references/sqlserver-docker.md`. The rest of that file still applies where the Bacpac section below says so. These notes come from general knowledge of the platform. The checked lines were checked in one Windows 11 virtual machine. They are not yet checked on a customer project. Treat each row as a place to look first, not a guarantee. Mark a recipe built only from the unchecked notes `inferred:`.

## Instance and database

- Checked: `sqllocaldb versions` lists the installed SQL Server versions, and `sqllocaldb info` lists the instances. An instance has an owner, and its state may be `Stopped`. It starts on the first connection when auto-create is on. `sqlcmd` is found on PATH or by `where sqlcmd`.
- Use an instance the engineer already has. Never create, stop, delete or change an instance the engineer made. Starting an instance that is stopped is allowed.
- Connect with `sqlcmd -S "(localdb)\<instance>" -E`. LocalDB accepts only the Windows user that owns the instance, so run the helpers as that user. Prefer the instance whose version matches the project's SQL Server version.
- Checked: a command that `prlctl exec` runs in a Parallels virtual machine runs as SYSTEM unless the call has `--current-user`, and SYSTEM does not see the user's instances.
- One new database per ticket, named `<app>_verify_<ticket>`. Create it with `CREATE DATABASE`. Never use a name that already exists without the state check. Never touch any other database in the instance.
- LocalDB has no password, so nothing secret is made or stored.

## Bacpac

Follow the Bacpac section of `references/sqlserver-docker.md`, with these changes. They are `inferred:`.

- The target is the instance, not a container: `SqlPackage /Action:Import /TargetServerName:"(localdb)\<instance>" /TargetDatabaseName:<the per-ticket database>`. Start the instance first.
- The journal check, the upgrade in upgrade mode and never reset, and the list of journal entries that are on neither the base nor the branch are the same.
- No Rosetta or image step applies.

## db-start.ps1

Parameters: the same as `db-start.ps1` in `references/sqlserver-docker.md`. Starts the instance if it is stopped, creates the per-ticket database or reuses the one in `state.json`, and does the state check. Prints the instance name, the SQL Server version, the database name, the `containerId` value, and one of `database: new`, `database: reused` or `database: dropped`.

- `containerId` keeps its name, because `state.json` has one contract. For LocalDB it holds `<instance>\<database>` and the database's `create_date` from `sys.databases`, so the value changes whenever the database is dropped and created again. The state check then clears the stored state, as it does for a new container. `createdAt` holds the time the database was created.
- The state check, the fresh-restore rules, the `-ConfirmRestore` switch and the `fresh restore needed: <reason>` message are the same as in `references/sqlserver-docker.md`. A fresh restore means `DROP DATABASE` and `CREATE DATABASE` on the one per-ticket name. It never drops any other database.
- Wait until `sqlcmd` can run a query. A started instance is not enough.
- Where `dbup-run.ps1` and `api-start.ps1` say "the container's host and port", read "the instance and the per-ticket database".
- Where `doctor.ps1` checks that "the container" is running, check that the instance is running (`sqllocaldb info <instance>` shows `Running`) and that the per-ticket database exists. A Doctor that runs `docker inspect` on the `containerId` value is wrong for LocalDB.
- Where `cleanup.ps1` prints a `docker rm` command, it prints the `DROP DATABASE` statement for the per-ticket database instead. It never runs it.
- Data made by SQL, not through the app, needs the engineer's approval for each insert, and the report marks it "made by SQL, not through the app".
