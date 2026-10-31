# .NET Framework backends (IIS Express)

Load this file in Flow step 5, when the project is .NET Framework: a `web.config`, a `Global.asax`, or a `TargetFrameworkVersion` of `v4.x` in a `*.csproj`. It says how the helpers build and start the API on IIS Express. It replaces the `api-start.ps1` contract in `references/dotnet.md`; the `dbup-run.ps1` contract there still applies when the migration runner takes its connection string from an environment variable. When the runner reads a settings file instead, `dbup-run.ps1` asks for the same confirmation as `api-start.ps1` and ends with `blocked: connection string not set for this ticket` without it. For the database, see `references/sqlserver-docker.md` or `references/sqlserver-localdb.md`. These notes come from general knowledge of the platform. The lines marked checked were checked in one Windows 11 virtual machine with Visual Studio. They are not yet checked on a customer project. Treat each row as a place to look first, not a guarantee. Mark a recipe built only from the unchecked notes `inferred:`.

## Build and tools

- Checked: MSBuild and `vstest.console.exe` are not on PATH in a plain command prompt. Find them with `vswhere.exe`, which sits under `%ProgramFiles(x86)%\Microsoft Visual Studio\Installer`: `vswhere -latest -products * -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe`, and `vswhere -latest -products * -find Common7\IDE\CommonExtensions\Microsoft\TestWindow\vstest.console.exe`. Never write a found path to a file in the repository.
- Restore packages with the tool the project already uses (`nuget restore`, or `msbuild -t:restore`), then build the solution with that MSBuild before the first start.
- After a build, run `git status --porcelain`. A changed tracked file (a `packages.config` or a binding redirect, for example) is `blocked`, and you tell the engineer.

## Configuration

- A .NET Framework app reads `web.config` and, in some projects, its own local settings file. An environment variable does not override them unless the project adds a configuration builder. Find the real source in the startup code (`Global.asax`, a `Startup` class, a custom configuration class). Name keys only.
- Never read, print or copy a connection string. Never edit `web.config` or any settings file, and never edit a user's local settings file.
- A local settings file that holds the engineer's own values (for example `appsettings.local.json`) belongs to the engineer. List it in `LocalOnlyFiles`. The agent never reads or edits it. Before the first start, the engineer points its connection string at the per-ticket database. Say so as a one-time step, and wait.
- When the only source of the connection string is a file the engineer has not yet pointed at the per-ticket database, `api-start.ps1` ends with `blocked: connection string not set for this ticket`. It never falls back to the file's current value, which may name the engineer's own database.

## Start with IIS Express

- Checked: `iisexpress.exe` is under `C:\Program Files\IIS Express\` (64-bit) and `C:\Program Files (x86)\IIS Express\`. Its options are `/config:<file>` with `/site:<name>`, or `/path:<folder>` with `/port:<n>`.
- Checked: Visual Studio keeps a site's `applicationhost.config` under the solution folder: `<solution folder>\.vs\<solution name>\config\applicationhost.config`. That file belongs to the engineer. Never edit it.
- Make a scratch copy in the scratch folder, and edit only the copy: the site binding (the port, and the address that another machine or a simulator must reach). The site name is in the copy's `sites` element. Start with `iisexpress /config:<scratch copy> /site:<site name>`.
- IIS Express serves `localhost` only until a binding names another address. That needs a URL reservation and a firewall rule: see the next section.
- Record the process ID in `state.json`. Wait until the port answers an HTTP request, not only until it is open.

## One-time administrator steps

A request to a binding that is not `localhost` fails with "access denied" until an administrator runs these once. The agent never runs them. It prints them with the real values, stops with `blocked:`, and waits for the engineer. Both are `inferred:`: no run has checked them.

- Reserve the URL: `netsh http add urlacl url=http://<address>:<port>/ user=<the engineer's Windows user>`.
- Allow the port through the firewall: `netsh advfirewall firewall add rule name="<name>" dir=in action=allow protocol=TCP localport=<port>`.

## Sign-in

- Never type credentials. The engineer signs in with their own account.
- A Debug build may accept a debug token in place of a real sign-in. The startup code says whether it does and how the token is given. The engineer provides any token. Never save or print it.
- Roles: a .NET Framework app gets its roles from the sign-in and from the engineer's own settings, not from an environment variable. `api-start.ps1` ignores `roles`. When Doctor sees a role set that differs from the wanted one, nothing is restarted: the helper stops with `blocked: roles differ`, says which role the ticket needs, and waits for the engineer to change their own settings or account. The generated skill's steps that restart the API with other roles are the engineer's step for a Framework app.

## Doctor

- The ports answer, and the process that holds each one is the process this run started.
- Database target: after an API call that needs the database, run a read-only `SELECT session_id, host_process_id FROM sys.dm_exec_sessions WHERE database_id = DB_ID('<the per-ticket database>')`. A row whose `host_process_id` is the IIS Express process ID in `state.json` means the API uses that database. `program_name` is generic for a .NET client, so do not use it. No row proves nothing, because of connection pooling and a lazy first connection: make one more call, and then report `blocked: database target not shown`. This is `inferred:`. Report what you found. Do not report what a settings file says.

## api-start.ps1

Parameters: ticket, roles (a list, or `default`). Starts the API on IIS Express from the scratch copy of `applicationhost.config`. Prints the URL and the process ID, and saves the process ID in `state.json`.

- Rule: it refuses to start when a process this run did not start holds the port. It names the process.
- Rule: it starts only when `connectionConfirmedFor` in `state.json` equals the current `containerId` value. The agent asks the engineer to confirm, in the conversation, that their local settings file points at the per-ticket database, and then runs the helper with `-ConnectionConfirmed`, which records the value. A new database gives a new `containerId`, so the confirmation lapses. Without it the helper ends with `blocked: connection string not set for this ticket`.
- It never edits a settings file and never reads a connection string.
- A role change that needs a settings change is the engineer's step: say which role the ticket needs, and wait.
