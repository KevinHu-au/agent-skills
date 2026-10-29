#!/usr/bin/env bash
# Builds a small synthetic git repository, a shop application called "Shop", to test agentd-onboard.
# Usage: make-fixture.sh <dest> [--v2]
#   <dest> must not exist. v1 is one commit. --v2 adds a second commit: order cancellation and net9.0.
# Prints "v1 <hash>" and, with --v2, "v2 <hash>".
# The fixture uses a fake local identity, ignores your git config, global ignore file, hooks and environment
# variables, and uses fixed commit dates, so the hashes are the same on every run.
# Exit: 0 = built, 1 = destination exists, 2 = bad arguments.
set -eu

usage() { echo "usage: make-fixture.sh <dest> [--v2]" >&2; }

V2=0
if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  usage
  exit 2
fi
DEST=$1
if [ $# -eq 2 ]; then
  [ "$2" = "--v2" ] || { usage; exit 2; }
  V2=1
fi
if [ -e "$DEST" ]; then
  echo "make-fixture.sh: $DEST already exists" >&2
  exit 1
fi

# Start from a clean git environment. Nothing the caller exported (GIT_AUTHOR_*, GIT_DIR, EMAIL, ...) or keeps in
# a global config or global ignore file may change the fixture or its hashes.
for v in $(env | sed -n 's/^\(GIT_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$v"; done
unset EMAIL
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
g() { git -C "$DEST" -c core.hooksPath=/dev/null -c core.excludesFile=/dev/null -c commit.gpgsign=false "$@"; }

# w <relative-path>: write stdin to that file inside the fixture.
w() {
  mkdir -p "$(dirname "$DEST/$1")"
  cat >"$DEST/$1"
}

# commit <date> <message>: commit everything. Call it on its own line, never inside $(...): set -e is off there,
# so a failed commit would go unnoticed.
commit() {
  g add -A
  GIT_AUTHOR_DATE=$1 GIT_COMMITTER_DATE=$1 g commit -q -m "$2"
}

write_csproj() {
  w src/Shop.Api/Shop.Api.csproj <<EOF
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>$1</TargetFramework>
  </PropertyGroup>
</Project>
EOF
}

write_pipeline() {
  {
    cat <<'EOF'
trigger:
  - main

stages:
  - stage: Build
    displayName: Build
    jobs:
      - job: build
        steps:
          - script: dotnet build src/Shop.Api
            displayName: Build
          - script: dotnet test tests/Shop.Tests
            displayName: Unit tests
EOF
    prev=Build
    for env in Dev Test Prod; do
      cat <<EOF
  - stage: Deploy$env
    displayName: Deploy $env
    dependsOn: $prev
    jobs:
      - deployment: deploy
        environment: shop-$(printf '%s' "$env" | tr 'A-Z' 'a-z')
        strategy:
          runOnce:
            deploy:
              steps:
                - script: echo Run the DbUp scripts in src/Shop.Data/Scripts, then deploy Shop.Api
EOF
      prev=Deploy$env
    done
  } | w azure-pipelines.yml
}

write_v1() {
  w README.md <<'EOF'
# Shop

Shop is an order and invoicing service for a small wholesaler. Clerks enter and submit orders.
Managers read invoices. Admins manage customers.

## Stack

.NET 6 Web API (`src/Shop.Api`), SQL Server, Azure Pipelines.

## Run

    dotnet run --project src/Shop.Api

## Database changes

Add the next numbered script to `src/Shop.Data/Scripts`. Never edit a script that has been applied.
The pipeline runs the scripts with DbUp on deploy.

## Integration

Submitted orders go to the legacy order bus. Its address is the `LegacyBus:Endpoint` setting.
EOF

  write_pipeline
  write_csproj net8.0

  w docs/userGuide/orders.md <<'EOF'
# Orders user guide

## Clerks

1. Create an order for a customer.
2. Submit the order. The order goes to the legacy bus. Wait for the confirmation.

## Managers

Open a submitted order and choose Invoice to see its invoice.

The invoice shows the order value for each order.

## When submitting fails

Try again later. If it keeps failing, ask the bus team.
EOF

  w src/Shop.Api/appsettings.json <<'EOF'
{
  "ConnectionStrings": {
    "Default": "Server=sql-shop-dev;Database=Shop;User Id=shop_app;Password=FIXTURE-NOT-A-SECRET;"
  },
  "LegacyBus": {
    "Endpoint": "https://bus.example.invalid/orders"
  }
}
EOF

  w src/Shop.Api/Program.cs <<'EOF'
using Shop.Api.Jobs;
using Shop.Api.Services;
using Shop.Integration;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddHttpClient<LegacyBusClient>(client =>
    client.BaseAddress = new Uri(builder.Configuration["LegacyBus:Endpoint"]!));
builder.Services.AddScoped<OrderSubmissionService>();
builder.Services.AddScoped<InvoiceService>();
builder.Services.AddHostedService<NightlySyncJob>();

var app = builder.Build();
app.MapControllers();
app.Run();
EOF

  write_orders_controller_v1

  w src/Shop.Api/Controllers/CustomersController.cs <<'EOF'
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Shop.Domain;

namespace Shop.Api.Controllers;

[ApiController]
[Route("api/customers")]
[Authorize(Roles = "Admin")]
public class CustomersController : ControllerBase
{
    [HttpGet]
    public IActionResult List() => Ok(Array.Empty<Customer>());
}
EOF

  w src/Shop.Api/Services/OrderSubmissionService.cs <<'EOF'
using Shop.Integration;

namespace Shop.Api.Services;

public class OrderSubmissionService
{
    private readonly LegacyBusClient _bus;

    public OrderSubmissionService(LegacyBusClient bus) => _bus = bus;

    public Task Submit(int orderId) => _bus.PostOrderAsync(orderId);
}
EOF

  w src/Shop.Api/Services/InvoiceService.cs <<'EOF'
using Shop.Integration;

namespace Shop.Api.Services;

public class InvoiceService
{
    private readonly LegacyBusClient _bus;

    public InvoiceService(LegacyBusClient bus) => _bus = bus;

    public Task<string> Fetch(int orderId) => _bus.GetInvoiceAsync(orderId);
}
EOF

  w src/Shop.Api/Jobs/NightlySyncJob.cs <<'EOF'
using Shop.Integration;

namespace Shop.Api.Jobs;

public class NightlySyncJob : IHostedService
{
    private readonly LegacyBusClient _bus;

    public NightlySyncJob(LegacyBusClient bus) => _bus = bus;

    public Task StartAsync(CancellationToken cancellationToken) => _bus.SyncOrdersAsync(cancellationToken);

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}
EOF

  write_legacy_bus_client_v1

  w src/Shop.Domain/AppRole.cs <<'EOF'
namespace Shop.Domain;

public enum AppRole
{
    Clerk,
    Manager,
    Admin
}
EOF

  w src/Shop.Domain/Order.cs <<'EOF'
namespace Shop.Domain;

public class Order
{
    public int Id { get; set; }
    public int CustomerId { get; set; }
    public string Status { get; set; } = "Draft";
    public decimal Total { get; set; }
}
EOF

  w src/Shop.Domain/Invoice.cs <<'EOF'
namespace Shop.Domain;

public class Invoice
{
    public int Id { get; set; }
    public int OrderId { get; set; }
    public decimal Amount { get; set; }
}
EOF

  w src/Shop.Domain/Customer.cs <<'EOF'
namespace Shop.Domain;

public class Customer
{
    public int Id { get; set; }
    public string Name { get; set; } = "";
}
EOF

  w src/Shop.Data/Scripts/001_create_orders.sql <<'EOF'
CREATE TABLE Customers (
    Id INT NOT NULL PRIMARY KEY,
    Name NVARCHAR(200) NOT NULL
);

CREATE TABLE Orders (
    Id INT NOT NULL PRIMARY KEY,
    CustomerId INT NOT NULL REFERENCES Customers (Id),
    Total DECIMAL(18, 2) NOT NULL
);
EOF

  w src/Shop.Data/Scripts/002_create_invoices.sql <<'EOF'
CREATE TABLE Invoices (
    Id INT NOT NULL PRIMARY KEY,
    OrderId INT NOT NULL REFERENCES Orders (Id),
    Amount DECIMAL(18, 2) NOT NULL
);
EOF

  w src/Shop.Data/Scripts/003_add_order_status.sql <<'EOF'
ALTER TABLE Orders ADD Status NVARCHAR(20) NOT NULL DEFAULT 'Draft';
EOF

  w src/Shop.Data/StoredProcedures/GetOrderTotals.sql <<'EOF'
CREATE PROCEDURE GetOrderTotals @CustomerId INT
AS
    SELECT SUM(Total) AS Total FROM Orders WHERE CustomerId = @CustomerId;
EOF

  w tests/Shop.Tests/OrderSubmissionTests.cs <<'EOF'
using Xunit;

namespace Shop.Tests;

public class OrderSubmissionTests
{
    [Fact]
    public void Submit_order_posts_to_legacy_bus() => Assert.True(true);

    [Fact]
    public void Invoice_requires_manager_role() => Assert.True(true);

    [Fact]
    public void Customers_list_is_admin_only() => Assert.True(true);
}
EOF
}

write_orders_controller_v1() {
  w src/Shop.Api/Controllers/OrdersController.cs <<'EOF'
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Shop.Api.Services;
using Shop.Domain;

namespace Shop.Api.Controllers;

[ApiController]
[Route("api/orders")]
public class OrdersController : ControllerBase
{
    private readonly OrderSubmissionService _submission;
    private readonly InvoiceService _invoices;

    public OrdersController(OrderSubmissionService submission, InvoiceService invoices)
    {
        _submission = submission;
        _invoices = invoices;
    }

    [HttpPost]
    [Authorize(Roles = "Clerk")]
    public IActionResult Create(Order order) => Created($"api/orders/{order.Id}", order);

    [HttpPost("{id}/submit")]
    [Authorize(Roles = "Clerk")]
    public async Task<IActionResult> Submit(int id)
    {
        await _submission.Submit(id);
        return Accepted();
    }

    [HttpGet("{id}/invoice")]
    [Authorize(Roles = "Manager")]
    public async Task<IActionResult> Invoice(int id) => Ok(await _invoices.Fetch(id));
}
EOF
}

write_orders_controller_v2() {
  w src/Shop.Api/Controllers/OrdersController.cs <<'EOF'
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Shop.Api.Services;
using Shop.Domain;
using Shop.Integration;

namespace Shop.Api.Controllers;

[ApiController]
[Route("api/orders")]
public class OrdersController : ControllerBase
{
    private readonly OrderSubmissionService _submission;
    private readonly InvoiceService _invoices;
    private readonly LegacyBusClient _bus;

    public OrdersController(OrderSubmissionService submission, InvoiceService invoices, LegacyBusClient bus)
    {
        _submission = submission;
        _invoices = invoices;
        _bus = bus;
    }

    [HttpPost]
    [Authorize(Roles = "Clerk")]
    public IActionResult Create(Order order) => Created($"api/orders/{order.Id}", order);

    [HttpPost("{id}/submit")]
    [Authorize(Roles = "Clerk")]
    public async Task<IActionResult> Submit(int id)
    {
        await _submission.Submit(id);
        return Accepted();
    }

    [HttpPost("{id}/cancel")]
    [Authorize(Roles = "Clerk")]
    public async Task<IActionResult> Cancel(int id)
    {
        await _bus.CancelAsync(id);
        return Accepted();
    }

    [HttpGet("{id}/invoice")]
    [Authorize(Roles = "Manager")]
    public async Task<IActionResult> Invoice(int id) => Ok(await _invoices.Fetch(id));
}
EOF
}

write_legacy_bus_client_v1() {
  w src/Shop.Integration/LegacyBusClient.cs <<'EOF'
namespace Shop.Integration;

public class LegacyBusClient
{
    private readonly HttpClient _http;

    public LegacyBusClient(HttpClient http) => _http = http;

    public Task PostOrderAsync(int orderId) => _http.PostAsync($"orders/{orderId}", null);

    public Task<string> GetInvoiceAsync(int orderId) => _http.GetStringAsync($"invoices/{orderId}");

    public Task SyncOrdersAsync(CancellationToken cancellationToken) => _http.PostAsync("orders/sync", null, cancellationToken);
}
EOF
}

write_legacy_bus_client_v2() {
  w src/Shop.Integration/LegacyBusClient.cs <<'EOF'
namespace Shop.Integration;

public class LegacyBusClient
{
    private readonly HttpClient _http;

    public LegacyBusClient(HttpClient http) => _http = http;

    public Task PostOrderAsync(int orderId) => _http.PostAsync($"orders/{orderId}", null);

    public Task CancelAsync(int orderId) => _http.PostAsync($"orders/{orderId}/cancel", null);

    public Task<string> GetInvoiceAsync(int orderId) => _http.GetStringAsync($"invoices/{orderId}");

    public Task SyncOrdersAsync(CancellationToken cancellationToken) => _http.PostAsync("orders/sync", null, cancellationToken);
}
EOF
}

write_v2() {
  write_csproj net9.0
  write_orders_controller_v2
  write_legacy_bus_client_v2

  w docs/userGuide/cancel.md <<'EOF'
# Cancelling an order

Clerks can cancel a submitted order. The cancellation goes to the legacy bus.
EOF
}

git init -q --template= -b main "$DEST"
g config user.name Fixture
g config user.email fixture@example.invalid

write_v1
commit 2026-01-05T09:00:00+11:00 'Add Shop orders and invoices'
hash=$(g rev-parse HEAD)
echo "v1 $hash"

if [ "$V2" -eq 1 ]; then
  write_v2
  commit 2026-02-02T09:00:00+11:00 'Add order cancellation and move to net9.0'
  hash=$(g rev-parse HEAD)
  echo "v2 $hash"
fi
