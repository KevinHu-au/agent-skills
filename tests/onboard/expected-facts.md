# Expected facts for the Shop fixture

What a correct brief says about the synthetic project built by `make-fixture.sh`. Score a fresh
reader's answers against this file (see `EVAL.md`). A gap marked `unknown:` with who to ask counts as a
pass. A silent gap, or a claim that is not backed by the code, counts as a fail.

Paths are relative to the fixture root. The fixture has no `*.csproj` except `src/Shop.Api/Shop.Api.csproj`,
so it cannot be built. A correct brief must not claim that a build or a test run succeeded.

## Q1 What is the app for, and who uses it?

- Shop is an order and invoicing service for a small wholesaler (`README.md`).
- Three roles, defined in `src/Shop.Domain/AppRole.cs`: Clerk, Manager, Admin.
- Clerks create and submit orders. Managers read invoices. Admins manage customers. The Admin rule comes
  from `src/Shop.Api/Controllers/CustomersController.cs` only, so a brief that cites the user guide for
  Admin is wrong. The user guide (`docs/userGuide/orders.md`) covers clerks and managers only.

## Q2 What are the main use cases, and where are they in the code?

| Use case | Entry point | Path to the bus |
|---|---|---|
| Clerk creates an order | `POST /api/orders`, `OrdersController.Create` | none |
| Clerk submits an order | `POST /api/orders/{id}/submit`, `OrdersController.Submit` | `OrderSubmissionService.Submit` then `LegacyBusClient.PostOrderAsync` |
| Manager reads an invoice | `GET /api/orders/{id}/invoice`, `OrdersController.Invoice` | `InvoiceService.Fetch` then `LegacyBusClient.GetInvoiceAsync` |
| Admin lists customers | `GET /api/customers`, `CustomersController.List` | none |
| Orders sync (no user) | `NightlySyncJob` (`src/Shop.Api/Jobs/NightlySyncJob.cs`) | `LegacyBusClient.SyncOrdersAsync` |

Use cases that come only from code, such as the Admin one, are marked `inferred:`.

## Q3 How do I run it, sign in, load test data and check my change?

- Run: `dotnet run --project src/Shop.Api` (`README.md`). Build and test commands in the pipeline:
  `dotnet build src/Shop.Api`, `dotnet test tests/Shop.Tests` (`azure-pipelines.yml`). Marked `inferred:`
  unless the brief ran them (it cannot: no project file for the tests or for the other folders).
- Runtime: the README says .NET 6, the project file says `net8.0`. This is a `conflict:`. The code wins:
  `net8.0` (`src/Shop.Api/Shop.Api.csproj`). The README note is listed as a stale document.
- Sign in: `unknown:`. `Program.cs` configures no authentication scheme, only role attributes. Ask the team.
- Test data: `unknown:`. No seed script or sample data exists.
- Checking a change: `tests/Shop.Tests/OrderSubmissionTests.cs` holds three tests
  (`Submit_order_posts_to_legacy_bus`, `Invoice_requires_manager_role`, `Customers_list_is_admin_only`).

## Q4 What pattern do I copy, and what are the house rules?

- Pattern: controller, then service, then `LegacyBusClient`, all injected through the constructor and
  registered in `src/Shop.Api/Program.cs` (`AddScoped`, `AddHttpClient<LegacyBusClient>`). Each action has
  `[Authorize(Roles = "...")]`.
- House rules found: never edit a SQL script that has been applied (`README.md`).
- `unknown:` for coding conventions. There is no `.editorconfig`, contribution guide or code owners file.

## Q5 What are the main data entities, and how do I change the schema safely?

- Entities: Customer, Order (with `Status`, added by script 003) and Invoice, in `src/Shop.Domain`.
  Tables: Customers and Orders (`001_create_orders.sql`), Invoices (`002_create_invoices.sql`).
  Order belongs to a Customer. Invoice belongs to an Order.
- Stored procedure `GetOrderTotals` (`src/Shop.Data/StoredProcedures/GetOrderTotals.sql`). No caller was
  found, so say so (`unknown:` or `inferred: unused`).
- Change the schema: add the next numbered script (`004_...`) to `src/Shop.Data/Scripts`. Never edit an
  applied script. The pipeline runs the scripts with DbUp on deploy (`README.md`, `azure-pipelines.yml`).
- `unknown:` how stored procedures are deployed (not in the numbered folder) and which code reads the
  tables (no data access code in the fixture).

## Q6 Which external systems do we depend on, and what breaks if one fails?

One system: the legacy order bus.

- Direction: outbound. We call it over HTTP through `src/Shop.Integration/LegacyBusClient.cs`.
- Setting: the key `LegacyBus:Endpoint` in `src/Shop.Api/appsettings.json`.
- Calls: `orders/{id}` (post), `invoices/{id}` (get), `orders/sync` (post).
- Depends on the bus: `POST /api/orders/{id}/submit`, `GET /api/orders/{id}/invoice`, and `NightlySyncJob`.
  `NightlySyncJob` is the hidden caller: it has no endpoint and takes the client by constructor injection.
- Does not depend on the bus: `POST /api/orders` and `GET /api/customers`.
- Features that break: submitting an order, reading an invoice, the orders sync.
- `NightlySyncJob` calls the bus once, in `StartAsync`, when the host starts. The name says nightly and no
  schedule exists. The brief says so (`inferred:` or `conflict:`), not "runs every night".
- Owner: `unknown: ask the bus team`. The user guide says to ask the bus team when submitting fails.
- Failure behaviour: no retry or error handling in the code. Users are told to try again later.
- Local test possible: `unknown:`. No stub or mock was found.

## Q7 What must I never do or commit?

- Never copy or commit credentials. `src/Shop.Api/appsettings.json` holds a connection string with a
  password. The brief names the key `ConnectionStrings:Default` and never the value. The text
  `FIXTURE-NOT-A-SECRET` and the word `Password=` must not appear anywhere in the pack. A committed
  password is itself a finding.
- Never edit an applied SQL script.
- `unknown:` data access rules (which environments are read-only).

## Q8 How does a finished ticket get delivered, and who do I ask?

- Azure Pipelines (`azure-pipelines.yml`): trigger on `main`; stage Build (build and unit tests), then
  Deploy Dev, Deploy Test, Deploy Prod. The environments are `shop-dev`, `shop-test` and `shop-prod`.
  Every deploy stage runs the DbUp scripts and then deploys `Shop.Api`.
- `unknown:` who approves a Prod deployment (approvals live on the Azure DevOps environment, not in the
  repository), the ticket source, the branch and pull request rules, and who owns the project.

## Q9 Where does each feature live, layer by layer?

- The layer chain is controller, service, bus client. There is no UI layer. The data scripts and
  procedures are not on the request path.
- Submit: data loads and rules sit in `OrdersController.Submit` and `OrderSubmissionService.Submit`. The
  order goes to `LegacyBusClient.PostOrderAsync`.
- Invoice: `OrdersController.Invoice`, `InvoiceService.Fetch`, then `LegacyBusClient.GetInvoiceAsync`. The
  invoice amount is computed outside the repository: `unknown: ask the bus owner`.
- The search term "order value" (`docs/userGuide/orders.md`) maps to `Total` and to `GetOrderTotals`,
  marked `inferred: no caller found`. The user guide says the invoice shows the order value, but the
  invoice amount comes from the bus (`unknown: ask the bus owner`).
- The key concept is the order status (`src/Shop.Data/Scripts/003_add_order_status.sql`, `inferred:`).

## Traps a correct brief must handle

1. The `.NET 6` versus `net8.0` conflict (Q3).
2. The secret value must not appear (Q7).
3. The hidden caller `NightlySyncJob` is listed under external systems (Q6).
4. `CustomersController` and `POST /api/orders` are not listed as bus dependants (Q6).
5. The nightly claim is not made as fact (Q6).
6. No claim that the project builds or that tests pass (Q3).
7. A brief that invents a UI layer is wrong (Q9). The fixture has no UI.
8. A brief that claims `GetOrderTotals` computes the invoice amount is wrong (Q9). The procedure has no
   caller, and the invoice comes from the bus.

## After --v2

The second commit adds order cancellation and moves to `net9.0`. After a refresh, a correct brief:

- Lists the new use case: a clerk cancels an order, `POST /api/orders/{id}/cancel`
  (`OrdersController.Cancel`, role Clerk), marked `changed:`.
- Says cancel calls `LegacyBusClient.CancelAsync` directly from the controller. This breaks the controller,
  then service pattern, and the brief notes it.
- Adds cancel to the features that depend on the bus: submit, cancel, invoice, orders sync.
- Replaces `net8.0` with `net9.0` (`changed:`). The README still says .NET 6, so the `conflict:` stays.
- Adds `docs/userGuide/cancel.md` to the documentation sources.
- Moves the header to the new scanned commit and records the date.
- Leaves the facts in these sections unchanged: the data model, the pipeline, the roles and the secret
  handling. No script, pipeline or role file changed. A section that cites a changed file is re-checked, so
  a `path:line` citation may move (the cancel action shifts the line numbers in `OrdersController.cs`),
  but the fact itself stays. `Purpose and users` and `Data model` cite no changed file, so they are
  byte-for-byte the same.
- `Unknowns` and `open-questions.md` change only to add the new questions (the cancel use case, whether a
  controller may call the client directly, the four bus calls) and to say `net9.0` where they named
  `net8.0`.
- Adds a `feature-to-code.md` block for the cancel use case, marked `changed:`.
