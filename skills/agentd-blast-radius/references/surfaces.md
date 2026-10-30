# Surfaces

Where a search for callers stops, and what to check instead. Use only the surfaces the change touches. For each one, say what you searched and what you found. Record a search that finds nothing.

Start with the old name as a plain string. Search every file type for it: code, SQL, scripts, configuration, documents and client code. A symbol search sees one language. A string search sees them all.

## Wire shapes

The JSON, XML or CSV that the application sends to a caller you do not control.

- A field that is renamed, removed or retyped. A field that becomes nullable, or an enum with a new value. A changed status code or error body. Casing, date formats and time zones.
- Callers: a mobile app (an old version stays installed for months), another service, an integration platform map, a partner script. Check the contract's External systems and owners table for each one.
- A mobile app cannot be run here. The break stays `supported` unless a run shows the shape that the client reads.
- Prove a shape change with a run: print the old and the new output for the same input, and compare the field names and types.

## Data

- A column that is renamed, retyped or made not null. A table that is split or merged.
- Stored procedures and their result sets, views, triggers, scheduled jobs, reports and exports that read the same table. They often build their SQL from strings.
- Other applications that use the same database.
- Prove it by applying the change to a copy of a file database in the scratch folder, or to a local container database that the contract allows, and running each reader against it. Never copy a server database.

## Configuration and flags

- A configuration key that is renamed or removed, a default that changes, a value that differs per environment, a feature flag that gates the old path.
- Name the key, never the value.

## Indirection

- Calls that search does not see: dependency injection registrations, reflection and assembly scanning, events, queues and message handlers, convention-based routing, attributes, and names built from strings.
- A call you cannot trace is `inferred:`.

## Persisted names

- A type, method or message name that is stored as data, and read back later by code that may have changed. Look at job queues and schedulers, message buses and workflow state, serialised objects that carry type names, and caches and sessions. The .NET stores are in `references/dotnet.md`.
- A rename, a namespace change, a move to another assembly or a changed signature can make an old stored item fail to load or run. The item was written before the change and is read after it.
- Look at what is stored now, not at what the new code would write. A queue or table can hold days or months of old items.
- Prove it with a run that reads an old-shaped item with the new code. If the store is a shared environment, ask the owner for a sample with the secrets and personal data removed.

## Deploy order and rollback

- During a rolling deploy or a slot swap, old and new code run at the same time against the same database, queue and cache. Say what each side does with the other side's data.
- A schema change must work with the old code and the new code (add first, remove later). A change that works only after every instance is updated is a risk.
- Can the change be rolled back once data exists in the new shape? A dropped column, a rewritten value or a migration that cannot be undone says no.
- List the steps in the order that is safe for this change, and say why. An addition usually goes schema first, then code. Not when old code breaks on it: a `NOT NULL` column with no default, a new constraint or a trigger makes the old code's inserts fail. A removal goes code first, then schema. A rename is add, copy the old rows into the new name, write both until every instance is updated, move the reads, then remove. Put configuration and flags in the list too. State which step needs a gap, and what breaks if the order is wrong.
- A mobile app or a partner system cannot be rolled back with the server. See Wire shapes.
- The deploy tool and the release steps are not in this repository unless the contract says so. Write `unknown: ask <owner>` for what you cannot read.

## Performance reach

- A changed predicate, join or sort can stop an index from being used. A function on a column, an implicit type conversion, a leading wildcard and a parameter with another type are the usual causes.
- A migration can lock a table or run for a long time: `ALTER` on a large table, an index build that is not online, a backfill in one transaction. Size the table first (see Data in Running commands).
- A new call in a loop, or a new query on a hot path, changes the cost for every caller.
- A local copy has other data and other statistics than production. A run there shows the query shape, not the production cost. The production plan and timings are `unknown: ask <owner>`.

## Timing and state

- Transactions and their order, a cache that holds the old shape, a background job that retries, a handler that must be idempotent, a teardown that runs after the thing it cleans up is gone.
- A change that is safe once can be unsafe when it runs twice.

## Other readers of the same bytes

- A file, a log line or a message that another tool or another language reads. A parser that expects a date format, a column order or a delimiter.
- A document that states the format may be stale. A stale document is `supported` for what the format was, not for what a reader accepts.

## Generated and derived files

- Client code, API descriptions and mappings that are generated from the thing you change. Find the command that regenerates them, and say whether the change needs it.

## Libraries and the runtime

- The version that the project pins, and any local patch. Read the library's own source for the function you call.
- A behaviour that differs between versions or settings, for example a flag that changes what a pattern matches.
- Prove it with a script that imports the same version and calls the exact function.

## Authorisation reach

- Who can reach a route, a column or a report after the change. A rule that moved, a check that was only in the code you removed, a role that gets new access.

## External systems

- Use the contract's External systems and owners table: direction, our endpoints that depend on it, the features that depend on it, the owner, the test environment.
- The other side of the boundary is not in this repository. Write `unknown: ask <owner>` for what you cannot read, and list the evidence the owner can give.
- Never call an outside system to find out.

## Tests that encode the old behaviour

- A test, a fixture or a snapshot that asserts the old shape. It fails after the change. That is a cost to plan for, not a break in production. Also look for tests that still pass because they never touch the changed path.
