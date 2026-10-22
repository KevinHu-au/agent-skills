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

## Data candidates

- Find the writers of a table: the entity mapping, stored procedures, triggers, DbUp or migration scripts, and jobs. On SQL Server, `SELECT` from `sys.sql_modules` where `definition` contains the table name lists the procedures and triggers that mention it. To size a table without scanning it, read `sys.partitions` (the `rows` column of the heap or clustered index), not `count(*)`.
- A table fed by an integration such as BizTalk: the other side is `unknown: ask the <system> owner`.

## Performance candidates

- Measure a Release build. A Debug build is not tuned.
- Entity Framework logs the SQL it sends at the `Microsoft.EntityFrameworkCore.Database.Command` category. Raise that category to `Information` with an environment variable (for example `Logging__LogLevel__Microsoft.EntityFrameworkCore.Database.Command=Information`) or with a copy of the settings file in the scratch folder. Do not edit a tracked configuration file, and do not change code. Do not enable sensitive data logging: it writes parameter values, which can be personal data.
- N+1: the log shows the same query many times with one changed parameter. The cost is the query count.
- On SQL Server: the actual execution plan, Query Store, a missing index, parameter sniffing.
- `dotnet-counters` shows CPU, GC and thread pool counters. `dotnet-trace` records a trace. Do not install either one. If one is missing, say so and give the engineer the command.
