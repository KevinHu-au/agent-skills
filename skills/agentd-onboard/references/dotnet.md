# .NET projects

Load this file when the repository has `*.sln` or `*.csproj` files. It says where a .NET project keeps the things the explorers look for. Treat each row as a place to look first, not a guarantee.

## Runtime and layout

| Fact | Where to look |
|---|---|
| Runtime version | `TargetFramework` in each `*.csproj`; `global.json` for the SDK; `Directory.Build.props`. A README often disagrees. The project file wins. |
| Projects and layers | `*.sln`, `ProjectReference` entries in `*.csproj` |
| Startup and registrations | `Program.cs` or `Startup.cs`: `AddScoped`, `AddHttpClient`, `AddHostedService`, authentication and authorisation set-up |
| Configuration | `appsettings*.json`, `*.config`, `launchSettings.json`, `UserSecretsId`. Name keys only. |

## Behaviour

| Fact | Where to look |
|---|---|
| Endpoints | `[ApiController]`, `[Route(...)]`, `[HttpGet]` and the other verbs; minimal APIs `MapGet` and `MapPost` |
| Screens | `*.cshtml`, Razor pages, Blazor `@page`, or a single-page app's router |
| Roles and policies | `[Authorize(Roles = ...)]`, `[Authorize(Policy = ...)]`, `AddAuthorization`, claims |
| Background work | `IHostedService`, `BackgroundService`, Hangfire or Quartz jobs, Azure Functions with timer or queue triggers |
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
| Test projects | `*Tests.csproj`, `*.Tests` folders; `[Fact]`, `[Theory]`, `[Test]`, `[TestMethod]` |
| Filters | `Category` traits and `--filter` in the pipeline. A filter can match zero tests and still exit 0, so list the tests (see `safe-checks.md`) to confirm the count. |
| Integration tests | Tests that need a database, Docker or a network service. Never run them from this skill. |
