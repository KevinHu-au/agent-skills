# .NET projects

Where to look in a .NET project. These notes come from general knowledge of the platform. They are not yet checked on a customer project.

## Which kind of project

Read the target in each `.csproj`.

- .NET Framework: `<TargetFrameworkVersion>v4.8</TargetFrameworkVersion>` (an older project file that lists every source file), or `<TargetFramework>net48</TargetFramework>` and the other `net4*` values. It is usually ASP.NET MVC or Web API 2 on IIS.
- .NET Core: `net5.0`, `net6.0` and later, and the older `netcoreapp1.x` to `netcoreapp3.1`. A suffix such as `net8.0-windows` is still .NET Core. A project can list several in `<TargetFrameworks>`: it is each kind that the list names.
- Not every project is a web host. A `net4*` Windows service, a WinForms or WPF application and a console tool have no IIS, `Global.asax` or MVC. Read only the parts of the Framework section that fit what the project is.
- `netstandard2.0` and `netstandard2.1` are class libraries that either kind can load. Find the projects that reference the library (search `ProjectReference` and the package name), and read the part for each kind that runs it. A change in the library can break both hosts.

A solution can hold both kinds. Read the common part, then the part for each kind that the change touches or that runs the changed code.

## Common to both

### Wire shapes

- JSON names come from the serialiser settings and from attributes. Check `[JsonPropertyName]` for `System.Text.Json` and `[JsonProperty]` for Newtonsoft. A property rename changes the wire name unless an attribute pins it.
- Find which serialiser the project uses, and read its naming setting: `JsonSerializerOptions.PropertyNamingPolicy` for `System.Text.Json`, the contract resolver or `NamingStrategy` for Newtonsoft. Both libraries run on .NET Framework and in `netstandard` libraries too, not only on .NET Core.
- SOAP and XML: `[DataContract]` and `[DataMember]` names, `XmlSerializer` attributes, WCF service contracts and WSDL files. A schema or map in an integration platform such as BizTalk reads these names. That map is not in this repository: `unknown: ask <owner>`.
- Swagger or OpenAPI documents and generated clients (NSwag and similar) may need a regenerate. Find the command in the contract.

### Data

- DbUp or plain SQL scripts: an applied script is not edited. Look for the next script. Stored procedures that the project re-runs on each deploy are edited in place.
- Find the readers of a column: search the code for the name, then on SQL Server search `sys.sql_modules` where `definition` contains the name, and read `sys.sql_expression_dependencies`. Dynamic SQL built from strings is in neither: search for the name as a string.
- Raw SQL, Dapper queries and `.sql` files are strings. A compiler does not see them.

### Persisted names

- Background jobs: Hangfire stores the type name, the method name and the serialised arguments in its tables. A job that was queued before the deploy runs the old name after it. Check the Hangfire tables for queued, scheduled and retrying jobs, and for recurring jobs that name the method.
- Quartz with a database job store keeps the job and trigger type names in the `QRTZ_` tables. A renamed `IJob` class leaves stored triggers pointing at the old name.
- Message buses: NServiceBus and MassTransit store the message type name in the message and in the saga state. A queue can hold messages from the old version, and an old sender can still publish.
- Newtonsoft `TypeNameHandling` (other than `None`) writes assembly-qualified type names into JSON. Search for `TypeNameHandling` and for JSON columns, cache entries and queue bodies that carry `$type`.
- `BinaryFormatter`, `NetDataContractSerializer` and `DataContractSerializer` with known types tie stored bytes to type and assembly names.
- Entity Framework keeps the context type name: `__MigrationHistory.ContextKey` in EF6, and the model snapshot class name in EF Core. A renamed or moved `DbContext` class can make EF treat the migrations as not applied.
- A stored enum number, a discriminator value or a status string that other code compares. A reordered or renumbered enum changes the meaning of old rows.
- A cache or a session store that holds serialised objects (a distributed cache, session state in SQL Server or Redis) keeps old shapes until they expire.

### Performance reach

- Entity Framework: a changed `Where`, `OrderBy` or `Include` changes the SQL. Read the SQL it sends, not only the LINQ. Get it on a local copy or a local container database: `ToQueryString()` in EF Core, `ToString()` on the query in EF6 (the `DbQuery` prints its SQL), or the logging of the SQL commands. Do not attach a profiler to a shared server. A function or a conversion on a column in the query can stop an index from being used, and a parameter of another type (for example `nvarchar` against a `varchar` column) forces an implicit conversion.
- A change that runs in memory instead of in SQL (a call the provider cannot translate, or `AsEnumerable()` before the filter) reads the whole table.
- Migrations: an `ALTER COLUMN` or a new index on a large table can lock it. Size the table from `sys.partitions` (the `rows` column of the heap or clustered index), not `count(*)`. A migration step can run inside one transaction, and then a backfill in it holds its locks to the end. Whether it does depends on the EF version, the provider and the step (a hand-written `Sql(...)` call, `suppressTransaction`, an online index). Read the migration and mark what you could not run `inferred:`.

### Libraries

- Pinned versions are in the `.csproj`, `Directory.Packages.props`, `packages.config` or `packages.lock.json`. Read the source of the library at that version. A behaviour can change between a major version and the next.
- Regular expressions: `RegexOptions.IgnoreCase` and `RegexOptions.CultureInvariant` change what a pattern matches. Culture changes string comparison and number formats.

### Authorisation

- `[Authorize]` attributes (on Framework, `System.Web.Mvc` and `System.Web.Http` have separate ones), roles, policies and handlers. Check where the rule is enforced, and whether the change moves it.

### Run and count tests

- A test filter that matches zero tests can still exit 0, with only a warning. Check the total in the output, or list the tests with the same filter. Compare with the count in the Commands heading of the contract.

## .NET Framework (ASP.NET MVC and Web API 2)

### Wire shapes

- Web API 2 uses Newtonsoft by default. Look for `JsonFormatter.SerializerSettings` in `WebApiConfig.cs`: a naming policy there changes every name. An MVC `JsonResult` uses a different serialiser (`JavaScriptSerializer`) with other date and naming rules.
- A change to a model class changes model binding too. A renamed property stops binding from old form fields and query strings.

### Data

- Entity Framework 6: the `Migrations/` folder with `Configuration.cs`, the `__MigrationHistory` table, and an EDMX model with generated code. Automatic migrations and a database initializer (`Database.SetInitializer`) can change the schema on start-up. A rename can be scaffolded as a drop and an add, which loses data. Read the generated migration.

### Indirection

- Start-up code is in `Global.asax.cs` (`Application_Start`), `App_Start/*.cs` (`RouteConfig`, `WebApiConfig`, `FilterConfig`, `BundleConfig`) or an OWIN `Startup.cs`.
- Dependency injection is usually Autofac, Unity, Ninject, Castle Windsor or Simple Injector. Find the registration in the bootstrapper. Look for assembly scanning and registration by convention.
- Routes can be attribute routes (`[Route]`, `[RoutePrefix]`) or convention routes in `RouteConfig`. Filters, message handlers (`DelegatingHandler`) and HTTP modules and handlers in `web.config` run for requests without a call site.
- Background work: Hangfire or Quartz, a Windows service, a scheduled task, `HostingEnvironment.QueueBackgroundWorkItem`, or a WCF service.

### Configuration

- `web.config`, `app.config`, the `appSettings` and `connectionStrings` sections, and custom configuration sections. Per-environment values come from transforms (`Web.Release.config`) or from tokens that the deploy replaces. A change to `web.config` restarts the application. Name the key, never the value.
- Packages: an older project lists them in `packages.config`, with the files in a `packages` folder and a `HintPath` in the `.csproj`. A newer one uses `PackageReference`. Check which, before you read the pinned version.
- Binding redirects for assemblies are in `web.config`. A package update with no matching redirect fails at run time, not at build time.

### Deploy

- The application runs in IIS. A deploy recycles the application pool, and in-process state is lost: in-memory cache, in-process session, static fields. On a web farm the instances are updated one by one, so old and new code run together. The `machineKey` in `web.config` signs forms-authentication cookies, ViewState and anti-forgery tokens. When the key is missing or generated per instance, a request that crosses instances fails validation, or users are signed out. Name the element, never the key.

## .NET Core and later

### Wire shapes

- `System.Text.Json` is the default, with a camelCase naming policy in ASP.NET Core. A project can switch to Newtonsoft with `AddNewtonsoftJson`. Find the setting in `Program.cs` or `Startup.cs`, then read its naming: `JsonSerializerOptions.PropertyNamingPolicy` for `System.Text.Json`, and the contract resolver or `NamingStrategy` for Newtonsoft. A property rename changes the wire name unless an attribute pins it.

### Data

- Entity Framework Core: the migration and the model snapshot (`*ModelSnapshot.cs`). A property rename can be generated as a drop and an add, which loses data. Read the generated migration before you trust it.

### Indirection

- Dependency injection: find the registration in `Program.cs` or `Startup.cs`. Look for assembly scanning (Scrutor and similar), decorators and open generics.
- MediatR and similar: handlers are found by type. A new or removed handler changes behaviour without a call site.
- Background services, hosted services and scheduled jobs call code at times that a request trace does not show.

### Configuration

- `appsettings.json` and `appsettings.<Environment>.json`, user secrets, environment variables and a key vault. A binding by section name breaks silently when the key is renamed. Name the key, never the value.

### Deploy

- A container or an app service replaces instances. During a rolling update, old and new instances run together. The data protection key ring (cookies, anti-forgery tokens) must be shared between them, or users are signed out.
- ASP.NET Core can also run behind IIS (the ASP.NET Core Module) or as a Windows service. A deploy then recycles the process, and in-process state is lost: in-memory cache, in-process session, static fields. On IIS, the module settings and environment variables sit in `web.config`.
