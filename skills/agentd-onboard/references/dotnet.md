# .NET projects

Load this file for a .NET project (the stack signals in `SKILL.md`). It says where a .NET project keeps the things the explorers look for. Treat each row as a place to look first, not a guarantee.

## Which kind of project

Read the target in each project file (`.csproj` or `.vbproj`).

- .NET Framework: `<TargetFrameworkVersion>v4.8</TargetFrameworkVersion>` (an older project file that lists every source file), or `<TargetFramework>net48</TargetFramework>` and the other `net4*` values. It is usually ASP.NET MVC or Web API 2 on IIS.
- .NET Core: `net5.0`, `net6.0` and later, and the older `netcoreapp1.x` to `netcoreapp3.1`. A suffix such as `net8.0-windows` is still .NET Core. A project can list several in `<TargetFrameworks>`: it is each kind that the list names.
- Not every project is a web host. A `net4*` Windows service, a WinForms or WPF application and a console tool have no IIS, `Global.asax` or MVC. Read only what fits the project.
- A Web Site project has no project file. Read `targetFramework` on the `compilation` element in `web.config`. It is .NET Framework.
- `netstandard2.0` and `netstandard2.1` are class libraries that either kind can load. Find the projects that reference the library (search `ProjectReference` and the package name), and read the guidance for each kind that runs it. A change in the library can break both hosts.

A solution can hold both kinds. The tables below lean on .NET Core. The last section lists what differs on .NET Framework: read it for every `net4*` project.

## Runtime and layout

| Fact | Where to look |
|---|---|
| Runtime version | `TargetFramework` in each `*.csproj` or `*.vbproj`; `global.json` for the SDK; `Directory.Build.props`. A README often disagrees. The project file wins. |
| Projects and layers | `*.sln`, `ProjectReference` entries in `*.csproj` or `*.vbproj` |
| Startup and registrations | `Program.cs` or `Startup.cs`: `AddScoped`, `AddHttpClient`, `AddHostedService`, authentication and authorisation set-up |
| Configuration | `appsettings*.json`, `*.config`, `launchSettings.json`, `UserSecretsId`. Name keys only. |

## Behaviour

| Fact | Where to look |
|---|---|
| Endpoints | `[ApiController]`, `[Route(...)]`, `[HttpGet]` and the other verbs; minimal APIs `MapGet` and `MapPost` |
| Screens | `*.cshtml`, Razor pages, Blazor `@page`, or a single-page app's router |
| Roles and policies | `[Authorize(Roles = ...)]`, `[Authorize(Policy = ...)]`, `AddAuthorization`, claims |
| Background work | `IHostedService`, `BackgroundService`, Hangfire or Quartz jobs, Azure Functions with timer or queue triggers |
| Data loading | Query handlers, repositories, and the `SELECT` logic in stored procedures |
| Calculations | Calculation classes, validators, and the stored procedures or query handlers that compute a value before it is returned |
| Business rules | Service classes that controllers call, validators, calculation classes |

## Data

| Fact | Where to look |
|---|---|
| Entities | Classes in a domain or models project; `DbContext` and `DbSet<...>`; Dapper queries |
| Schema scripts | Numbered `*.sql` files; DbUp (`DeployChanges`, embedded or file scripts); EF `Migrations/` folders |
| Stored procedures | `*.sql` in a procedures folder, and the code that calls them by name |
| Generated files | `*.g.cs`, `Reference.cs`, NSwag or OpenAPI clients, EF model snapshots. Find the command that regenerates each. |

## External systems

| Fact | Where to look |
|---|---|
| HTTP clients | `AddHttpClient`, classes that take an `HttpClient`, Refit interfaces, generated API clients |
| SOAP and WCF | `Connected Services`, `ServiceReference`, `*.svcmap`, `*.wsdl`, `*.asmx`; BizTalk adapters often appear as SOAP or WCF endpoints |
| Queues and buses | Service Bus, RabbitMQ, MassTransit senders and consumers |
| Addresses | Configuration keys for endpoints, queue names and credentials. Name keys only. |
| Inbound callers | Controllers with an API key filter, a client certificate check, or an XML or SOAP body |

## Tests

| Fact | Where to look |
|---|---|
| Test projects | `*Tests.csproj` (or `*Tests.vbproj`), `*.Tests` folders; `[Fact]`, `[Theory]`, `[Test]`, `[TestMethod]` |
| Filters | `Category` traits and `--filter` in the pipeline. A filter can match zero tests and still exit 0, so list the tests (see `safe-checks.md`) to confirm the count. |
| Integration tests | Tests that need a database, Docker or a network service. Never run them from this skill. |

## What differs on .NET Framework

Where a row above names a .NET Core file, a .NET Framework project keeps the same fact in a different place. Treat each row as a place to look first, not a guarantee.

| Fact | Where to look |
|---|---|
| Runtime version and packages | `TargetFrameworkVersion` or `TargetFramework` in each `*.csproj` or `*.vbproj`; `packages.config` (with a `packages` folder and a `HintPath`) or `PackageReference`; `AssemblyInfo.cs`; binding redirects in `web.config` |
| Startup and registrations | `Global.asax.cs` (`Application_Start`), `App_Start/*.cs` (`RouteConfig`, `WebApiConfig`, `FilterConfig`), or an OWIN `Startup.cs`. Registrations are in an Autofac, Unity, Ninject or Castle Windsor bootstrapper. |
| Configuration | `web.config`, `app.config`, the `appSettings` and `connectionStrings` sections, transforms such as `Web.Release.config`. Name keys only. |
| Endpoints | Web API 2 classes that derive from `ApiController`, MVC classes that derive from `Controller`, `[Route]` and `[RoutePrefix]`, and convention routes in `RouteConfig` |
| Screens | `*.cshtml` (Razor), `*.aspx` and `*.ascx` (Web Forms), and the bundles in `BundleConfig` |
| Roles and policies | `[Authorize]` from `System.Web.Mvc` or `System.Web.Http`, `<authorization>` and `<location>` in `web.config`, role providers |
| Background work | Hangfire or Quartz jobs, a Windows service (`ServiceBase`), a scheduled task, `HostingEnvironment.QueueBackgroundWorkItem` |
| Entities and schema | EF6 `DbContext` and `DbSet<...>`, an `*.edmx` model, `Migrations/` with `Configuration.cs`, the `__MigrationHistory` table |
| Outbound calls | `new HttpClient()`, `HttpWebRequest`, `WebClient`, RestSharp, and generated service references. There is no `AddHttpClient`. |
| Inbound callers and authentication | OWIN middleware, `<authentication mode="...">` in `web.config`, `DelegatingHandler`, `ActionFilterAttribute` and `AuthorizationFilterAttribute` classes (an API key or client certificate check) |
| Generated files | `*.tt` (T4 templates) and the code they write, the generated code of an `*.edmx` model, `Reference.cs`, NSwag or other generated clients. Find the command or the template that regenerates each. |
| SOAP and WCF | `system.serviceModel` in `web.config` or `app.config`, `*.svc`, `*.asmx`, `Service References` |
| Tests | MSTest, NUnit or xUnit projects. The pipeline may call `vstest.console.exe` or the NUnit console runner; `dotnet test` works only for an SDK-style project. List the tests with the project's own runner (see `safe-checks.md`). |
