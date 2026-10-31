# .NET backends

Load this file for a .NET project (the stack signals in `SKILL.md`). It covers ASP.NET Core (often with a command and
query split) and older .NET Framework MVC and Web API projects. Treat each row as a place to look first, not a
guarantee. A server-rendered screen (MVC view, Razor Pages, Blazor) is covered here. A separate frontend's layers come
from `react.md`, or from the generic order in `SKILL.md`.

## Detect

The stack signals in `SKILL.md` decide when to load this file. These lines say what to look for once it is loaded.

- ASP.NET Core: `TargetFramework` of `net6.0` or later in a `*.csproj`; `Program.cs` with `WebApplication` or
  `AddControllers`.
- .NET Framework: `TargetFrameworkVersion` (`v4.x`) in a `*.csproj`; `Global.asax`; `web.config`; `packages.config`.
- A command and query split: folders or types named `Commands`, `Queries`, `*Handler`, and a dispatcher or mediator.

## Layers

A server-rendered screen comes first: a view (`*.cshtml`, a Razor Page or a Blazor component). The controller action
or page handler that renders it is the endpoint. A value a job writes starts at the job's entry point instead.

1. Endpoint: a controller action, a Razor Page handler, or a minimal API route.
2. Dispatcher: a mediator or dispatcher that every request passes, often with an authoriser or validator. One line in
   the flow, not one per step.
3. Command or query: the request object the endpoint sends.
4. Handler: the class that handles that command or query.
5. Repository: the data access class the handler calls (EF Core, Dapper, ADO.NET).
6. Stored procedure, view or table. Procedures often call other procedures: follow them to the one that computes the
   value, then to its tables.

A project without a command and query split goes endpoint → service → repository. Its dispatcher, command and
handler layers are `none`.

## Where to look

| Layer | Where to look |
|---|---|
| View | `Views/**/*.cshtml` with `@model`; Razor Pages `Pages/**/*.cshtml` and their `*.cshtml.cs`; Blazor `*.razor` with `@page` |
| Endpoint | `[ApiController]`, `[Route(...)]`, `[HttpGet]` and the other verbs; `MapGet` and `MapPost` |
| Endpoint (.NET Framework) | Classes that inherit `ApiController` (Web API) or `Controller` (MVC); routes in `RouteConfig.cs` and `WebApiConfig.cs`; start-up in `Global.asax` |
| Dispatcher | Types named `*Dispatcher`, `*Mediator` or `IMediator`; pipeline behaviours; registrations in `Program.cs` |
| Command or query | The type passed to the dispatcher in the endpoint body |
| Handler | Classes that implement `ICommandHandler<>`, `IQueryHandler<>` or `IRequestHandler<>` for that type |
| Repository | Interfaces injected into the handler; `DbContext` and `DbSet<...>`; Dapper `Query` calls; the procedure name passed as a string |
| Stored procedure | `*.sql` files in a procedures folder; the name the repository passes; nested `EXEC` calls |
| Schema | Numbered `*.sql` scripts, DbUp scripts, EF `Migrations/` folders |
| Configuration | `appsettings*.json`; `web.config` in .NET Framework. Name keys only. |
| External systems | `AddHttpClient`, classes that take an `HttpClient`; WCF service references (`Connected Services`, `*.svcmap`, `*.wsdl`), where BizTalk often shows; queue senders |
| Background jobs | `IHostedService`, `BackgroundService`, Hangfire or Quartz jobs, timer or queue triggers |
