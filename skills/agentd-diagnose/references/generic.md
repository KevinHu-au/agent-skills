# Other stacks

Use this file for a project that matches none of the stack signals in `SKILL.md`. It tells you how to work out the facts that the stack references give for .NET, React and iOS. These notes come from general knowledge of software projects. They are not yet checked on a customer project. Every fact you take from this file or from reading the code of an unknown stack is `inferred:`, with a `path:line` for the code that shows it. A run, a query or a measurement that shows the fact makes it `confirmed:`, as the evidence tiers in `SKILL.md` say. When a fact is not in the code, write `unknown:` and ask the engineer.

## Run and count tests

- Find the test command in the build files and the pipeline file, in this order: the contract's Commands heading, a `Makefile` or `justfile` target, the scripts in `package.json`, `pyproject.toml`, `tox.ini` or `noxfile.py`, `build.gradle` or `pom.xml`, `Cargo.toml`, `go.mod`, a `Gemfile` or `Rakefile`, and the pipeline file (`.github/workflows`, `azure-pipelines.yml`). Read the command body. A target can start a watch mode, a build, a database or end-to-end tests. Run the test runner directly with one file or one test, and copy its flags and environment variables from the body.
- Run only tests that need no network, account or configured service. Put the command on the run plan. Never run end-to-end or browser tests from this skill.
- A filter that matches no test can still exit 0 and run zero tests. Check the total in the output and compare it with the count in the Commands heading of the contract. If the runner can list tests with the same filter, list them first. Report a run of zero tests as "ran 0 tests", never as a pass.
- Installing packages writes to the project and uses the network. If dependencies are missing, say so and give the engineer the command. Do not install them.

## Configuration layers

- A value can come from a default in code, a tracked file, an untracked local file, an environment variable, a secret store or a feature flag. Find the code that reads each one: search for the read calls of the language, for example `getenv`, `os.environ`, `process.env`, `System.getenv`, `ConfigurationManager`, `@Value` or `viper`. Then find the code that loads the files.
- Write the order in which the layers override one another, with `path:line`. When the order is not in the code, write `unknown:` and ask the engineer.
- Never open an untracked local file, a secret store or a file that holds credentials. Name its path and ask.

## Wiring and dependency injection

- Find the composition root first: the `main` function, the application factory or the start-up file. Read how it builds the services.
- Find the container, if any, by its registration calls (`register`, `bind`, `provide`, `add`, `@Inject`, `@Component`, a module file). Without a container, wiring is by hand: read the constructor calls.
- For a suspect interface or function, name the concrete type that is used at run time, with the `path:line` of the registration or of the call. A type that is chosen by configuration or by a flag has more than one answer: list each.

## Migrations and the database

- Find the migration tool by its folder or file names: `migrations/`, `db/migrate`, `alembic`, `flyway`, `liquibase`, `prisma`, `knex`, `sequelize`, `typeorm`, `diesel`, `goose`, `dbup`, or plain `.sql` files in a numbered order.
- Read how the tool decides which scripts have run (a history table, a journal file). Do not connect to a database to look. Give the engineer the query to run and mark the result `unknown:`.
- A migration that ran in one environment and not in another is a difference between environments. Say so in the report.

## Bug candidates

- A condition that reads the wrong side of a comparison, an off-by-one in a range or a page, a missing null or empty check, an error that is caught and ignored, a value that is changed in place while another reader uses it, time-zone and locale differences, and a retry that repeats a side effect.
- Mark each candidate `inferred:` until a run or a query shows it.

## Data candidates

- A query without the filter that the nearby queries have, a join that multiplies rows, an update without a `WHERE` clause on the key, and a write that the code reads back from a cache.
- Compare good and bad rows inside the query and print only IDs and counts.

## Performance candidates

- A query or request inside a loop, a missing index for a filter column, a result set that is not paged, and work that is repeated on each request and could be done once.
- Measure with the profiler or the query plan of the stack, on a build like production, before you name a cause.
