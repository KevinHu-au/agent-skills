# .NET projects

Where to look in a .NET project. These notes come from general knowledge of the platform. They are not yet checked on a customer project.

## Run and count tests

- Run one test: `dotnet test --filter "FullyQualifiedName~<TestName>"`.
- A filter that matches zero tests can still exit 0, with only a warning. Check the total in the output, or run `dotnet test --list-tests` with the same filter. Compare with the count in the Commands heading of the contract.

## Bug candidates

- Calls hidden behind dependency injection or events: find the registration in `Program.cs` or `Startup.cs`. A call you cannot trace is `inferred:`.
- Time and culture: `DateTime.Now` against `DateTime.UtcNow`, time zones, `CultureInfo` in number and date formats.
- Money: `decimal` rounding and `MidpointRounding`, and rounding done per line instead of per order.
- Entity Framework: tracking against `AsNoTracking`, lazy loading, a query that runs in memory instead of in SQL.
- Async: a blocked `.Result` or `.Wait()`, and a task nobody awaits.
- Configuration: `appsettings.<Environment>.json`, user secrets and environment variables differ between machines. Name the key, never the value.

## Production dumps

The engineer takes a dump and runs the tools. Install nothing, and run nothing against a live process. If a tool is missing, say so and give the engineer the command. A dump can hold secrets and personal data in memory. Ask for the findings, and never repeat a value from the dump in the report.

- **Crash or hang dump:** ask the engineer to run `dotnet-dump analyze <file>` and paste the output of these commands: `clrthreads`, `pe` (the last exception), `clrstack` for the failing thread, and `dumpheap -stat` for memory problems. For a hang, add `syncblk` and `clrstack -all`.
- **A Windows dump of a .NET Framework process** opens in WinDbg or Visual Studio. Ask for the same facts: the exception, the stack of each thread and the locked objects.
- **What to write down:** the exception type, the top frames with `path:line` when symbols exist, and the runtime and the app version. Write the message only after you remove names, emails, IDs and user paths from it, or describe it in your own words.
- **Tier:** a dump shows what the process did. It is `supported` until a local run built from the same inputs produces the failure.

## Data candidates

- Find the writers of a table: the entity mapping, stored procedures, triggers, DbUp or migration scripts, and jobs. On SQL Server, `SELECT` from `sys.sql_modules` where `definition` contains the table name lists the procedures and triggers that mention it. To size a table without scanning it, read `sys.partitions` (the `rows` column of the heap or clustered index), not `count(*)`.
- A table fed by an integration such as BizTalk: the other side is `unknown: ask the <system> owner`.

## Performance candidates

- Measure a Release build. A Debug build is not tuned.
- Entity Framework logs the SQL it sends at the `Microsoft.EntityFrameworkCore.Database.Command` category. Raise that category to `Information` with an environment variable (for example `Logging__LogLevel__Microsoft.EntityFrameworkCore.Database.Command=Information`) or with a copy of the settings file in the scratch folder. Do not edit a tracked configuration file, and do not change code. Do not enable sensitive data logging: it writes parameter values, which can be personal data.
- N+1: the log shows the same query many times with one changed parameter. The cost is the query count.
- On SQL Server: the actual execution plan, Query Store, a missing index, parameter sniffing.
- `dotnet-counters` shows CPU, GC and thread pool counters. `dotnet-trace` records a trace. Do not install either one. If one is missing, say so and give the engineer the command.
