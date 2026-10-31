# Other stacks

Use this file for a project that matches none of the stack signals in `SKILL.md`. It tells you how to work out the facts that the stack references give for .NET, React and iOS. These notes come from general knowledge of software projects. They are not yet checked on a customer project. Every fact you take from this file or from reading the code of an unknown stack is `inferred:`, with a `path:line` for the code that shows it. A run, a query or a measurement that shows the fact makes it `confirmed:`, as the evidence tiers in `SKILL.md` say. When a fact is not in the code, write `unknown:` and ask the engineer.

## Run and count tests

- Find the test command in the contract's Commands heading, then in the build files and the pipeline file: a `Makefile` or `justfile` target, the scripts in `package.json`, `pyproject.toml`, `tox.ini` or `noxfile.py`, `build.gradle` or `pom.xml`, `Cargo.toml`, `go.mod`, a `Gemfile` or `Rakefile`, `.github/workflows`, `azure-pipelines.yml`. Read the command body before you run it, and do not run a target by name: it can start a watch mode, a build, a database or end-to-end tests. Run the test runner directly with one file or one test, copy its flags and environment variables from the body, and put the command on the run plan. Never run end-to-end or browser tests from this skill.
- A test filter that matches no test can still exit 0 and run zero tests. Check the total in the output, or list the tests with the same filter, and compare it with the count in the Commands heading of the contract. Report a run of zero tests as "ran 0 tests", never as a pass.
- Run only tests that need no network, account or configured service. If dependencies are missing, say so and give the engineer the install command. Do not install them.

## Configuration layers

- A value can come from a default in code, a tracked file, an untracked local file, an environment variable, a secret store or a feature flag. Search for the read calls of the language, for example `getenv`, `os.environ`, `process.env`, `System.getenv`, `ConfigurationManager`, `@Value` or `viper`, then for the code that loads the files.
- A changed default or a renamed key breaks every environment that sets it. List each environment that sets the key, from the files in the repository, and mark the ones you cannot see `unknown:` with who to ask.
- Never open an untracked local file, a secret store or a file that holds credentials. Name its path and ask.

## Wiring and dependency injection

- Find the composition root first: the `main` function, the application factory or the start-up file.
- Callers found by search miss the code that is chosen at run time. Find the container by its registration calls (`register`, `bind`, `provide`, `add`, `@Inject`, `@Component`, a module file), or read the constructor calls when wiring is by hand. For a changed interface or function, list each registered implementation, each decorator and each place that a flag or a setting swaps one for another.

## Migrations and the database

- Find the migration tool by its folder or file names: `migrations/`, `db/migrate`, `alembic`, `flyway`, `liquibase`, `prisma`, `knex`, `sequelize`, `typeorm`, `diesel`, `goose`, `dbup`, or numbered `.sql` files.
- Read how the tool runs scripts (at start-up, in the pipeline, by hand) and how it records what has run. That order is the deploy order: say whether the schema change goes before or after the code, and what a rollback does to data that the new code wrote.
- Do not connect to a database to look. Give the engineer the query to run and mark the result `unknown:`.

## Surfaces to map

Follow `references/surfaces.md` in its own order. For an unknown stack, find each surface like this:

- Wire shapes: the routes, the message or event names and the serialisers. Search for the framework's route and handler registration.
- Data: the columns, the readers of a column (code, views, stored procedures, reports, exports) and the persisted names.
- Persisted names: any name that old data or old builds still use after the change: keys in client storage and caches, serialised field and type names, file and queue names, on-device data. A rename breaks the data that is already stored, so list where it is stored and how long it lives.
- Timing and state: caches, sessions and background jobs that hold a value from before the change.
- Configuration and flags: the section above.
- Indirection: the section on wiring above.
- Deploy order and rollback: the section on migrations above.

Mark each surface you did not check `unknown:`, and say that the reach is a lower bound.
