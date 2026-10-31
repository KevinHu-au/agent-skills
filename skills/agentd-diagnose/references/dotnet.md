# .NET projects

Where to look in a .NET project. These notes come from general knowledge of the platform. They are not yet checked on a customer project.

## Which kind of project

Read the target in each project file (`.csproj` or `.vbproj`).

- .NET Framework: `<TargetFrameworkVersion>v4.8</TargetFrameworkVersion>` (an older project file that lists every source file), or `<TargetFramework>net48</TargetFramework>` and the other `net4*` values. It is usually ASP.NET MVC or Web API 2 on IIS.
- .NET Core: `net5.0`, `net6.0` and later, and the older `netcoreapp1.x` to `netcoreapp3.1`. A suffix such as `net8.0-windows` is still .NET Core. A project can list several in `<TargetFrameworks>`: it is each kind that the list names.
- Not every project is a web host. A `net4*` Windows service, a WinForms or WPF application and a console tool have no IIS, `Global.asax` or MVC. Read only what fits the project.
- A Web Site project has no project file. Read `targetFramework` on the `compilation` element in `web.config`. It is .NET Framework.
- `netstandard2.0` and `netstandard2.1` are class libraries that either kind can load. Find the projects that reference the library (search `ProjectReference` and the package name), and read the guidance for each kind that runs it. A change in the library can break both hosts.

A solution can hold both kinds. A note below that names a kind applies to that kind only. A note with no kind applies to both.

## Run and count tests

- Run one test: `dotnet test --filter "FullyQualifiedName~<TestName>"`. This works for an SDK-style project, on both kinds.
- A classic .NET Framework project (the older project file) may have no working `dotnet test`. Use the runner that the project already uses, from the contract's Commands heading: `vstest.console.exe <test dll> /TestCaseFilter:"FullyQualifiedName~<TestName>"`, or the NUnit console runner (`--where`).
- A filter that matches zero tests can still exit 0, with only a warning. Check the total in the output, or list the tests with the same filter: `dotnet test --list-tests`, `vstest.console.exe /ListTests`, or `--explore` for the NUnit console. Compare with the count in the Commands heading of the contract.

## Bug candidates

- Calls hidden behind dependency injection or events: find the registration. On .NET Core it is in `Program.cs` or `Startup.cs`. On .NET Framework it is in `Global.asax.cs`, `App_Start` or an OWIN `Startup.cs`, usually with Autofac, Unity, Ninject or Castle Windsor. A call you cannot trace is `inferred:`.
- Time and culture: `DateTime.Now` against `DateTime.UtcNow`, time zones, `CultureInfo` in number and date formats.
- Money: `decimal` rounding and `MidpointRounding`, and rounding done per line instead of per order.
- Entity Framework: tracking against `AsNoTracking`, a query that runs in memory instead of in SQL. Lazy loading is on by default in EF6 but only works through proxies: a navigation property must be `virtual` and the entity class public and not sealed. In EF Core it is off unless the project turns it on. A property that loads in one kind can return null or nothing in the other.
- Async: a blocked `.Result` or `.Wait()`, and a task nobody awaits. On .NET Framework (ASP.NET) a blocked `.Result` on a request thread can deadlock when the awaited code resumes on the request context, that is, when it does not use `ConfigureAwait(false)` on the way. The blocked thread holds the context that the continuation waits for. Check the whole awaited path, including libraries. ASP.NET Core has no such context, so the same call completes, but a blocked `.Result` there can still starve the thread pool and slow the service. A WPF or WinForms app has a UI context on both kinds, so a blocked `.Result` on the UI thread can deadlock on .NET Core as well.
- .NET Framework: `HttpContext.Current` is null on a background thread or after an `await` that left the request context. A `static` field or an in-memory cache is lost when IIS recycles the application pool.
- Configuration: on .NET Core, `appsettings.<Environment>.json`, user secrets and environment variables. On .NET Framework, `web.config` or `app.config` with transforms (`Web.Release.config`), and tokens that the deploy replaces. Values differ between machines. Name the key, never the value.

## Production dumps

The engineer takes a dump and runs the tools. Install nothing, and run nothing against a live process. If a tool is missing, say so and give the engineer the command. A dump can hold secrets and personal data in memory. Ask for the findings, and never repeat a value from the dump in the report.

- **Crash or hang dump of a .NET Core process:** ask the engineer to run `dotnet-dump analyze <file>` and paste the output of these commands: `clrthreads`, `pe` (the last exception), `clrstack` for the failing thread, and `dumpheap -stat` for memory problems. For a hang, add `syncblk` and `clrstack -all`.
- **A Windows dump of a .NET Framework process** (taken with Task Manager, `procdump -ma <process>` or the IIS worker process page) opens in WinDbg with the SOS extension, or in Visual Studio. Ask for the same facts: `!threads`, `!pe` (the last exception), `!clrstack` for the failing thread, `!dumpheap -stat` for memory problems. For a hang, add `!syncblk` and `~*e !clrstack`. For a dump of a 32-bit process, use the 32-bit debugger.
- **What to write down:** the exception type, the top frames with `path:line` when symbols exist, and the runtime and the app version. Write the message only after you remove names, emails, IDs and user paths from it, or describe it in your own words.
- **Tier:** a dump shows what the process did. It is `supported` until a local run built from the same inputs produces the failure.

## Data candidates

- Find the writers of a table: the entity mapping, stored procedures, triggers, DbUp or migration scripts, and jobs. On SQL Server, `SELECT` from `sys.sql_modules` where `definition` contains the table name lists the procedures and triggers that mention it. To size a table without scanning it, read `sys.partitions` (the `rows` column of the heap or clustered index), not `count(*)`.
- A table fed by an integration such as BizTalk: the other side is `unknown: ask the <system> owner`.

## Performance candidates

- Measure a Release build. A Debug build is not tuned. On .NET Framework, a `web.config` with `debug="true"` also turns off request optimisations; check it on the machine you measure.
- Entity Framework Core logs the SQL it sends at the `Microsoft.EntityFrameworkCore.Database.Command` category. Raise that category to `Information` with an environment variable (for example `Logging__LogLevel__Microsoft.EntityFrameworkCore.Database.Command=Information`) or with a copy of the settings file in the scratch folder. Do not edit a tracked configuration file, and do not change code. Do not enable sensitive data logging: it writes parameter values, which can be personal data.
- EF6 has no such category. `Database.Log` is set in code, and you do not change code. Two ways that change no tracked file: call `ToString()` on the query (a `DbQuery` prints its SQL) in a proof script in the scratch folder, or trace a local database with Extended Events or SQL Profiler. Never trace a shared server. A trace records parameter values, which can be personal data: keep it in the scratch folder and never repeat a value in the report. (An `<interceptors>` entry in a copy of the configuration file is read only by a host that starts from the folder with that copy, so it does not work for the project's own host.)
- N+1: the log shows the same query many times with one changed parameter. The cost is the query count.
- On SQL Server: the actual execution plan, Query Store, a missing index, parameter sniffing.
- .NET Core: `dotnet-counters` shows CPU, GC and thread pool counters. `dotnet-trace` records a trace. Do not install either one. If one is missing, say so and give the engineer the command.
- .NET Framework: Performance Monitor shows the `.NET CLR` counters (memory, exceptions, locks) for the process. PerfView records a trace. Do not install either one. If one is missing, say so and give the engineer the command.
