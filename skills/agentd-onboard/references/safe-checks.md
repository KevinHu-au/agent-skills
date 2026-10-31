# Safe checks

Safe checks give facts that reading cannot: does it build, and how many unit tests exist. They are optional. The skill runs them only with one confirmation per run, and only when the engineer can answer.

## Allowed

- A build of the project, with the command the project already uses (from `AGENTS.md`, the README, or the pipeline file). A build writes `bin/`, `obj/` or `node_modules/`, and may restore packages from the project's package feed. Say so in the confirmation.
- Listing or counting unit tests, for example `dotnet test --list-tests`, `jest --listTests`, or on a classic .NET Framework project `vstest.console.exe <test dll> /ListTests` or the NUnit console `--explore`. The classic listing reads the built test assembly, so a build comes first. This shows the test names and the real count and runs no test. Use it to check that a filter such as a category really matches tests.

Both a build and a test listing run the project's own build and test code (build targets, test discovery). Say so in the confirmation, and let the engineer decide.

## Never

- Start the application.
- Run integration tests.
- Run DbUp, migrations, or any schema or data script.
- Run anything that touches a database or a network service, except the package restore above.
- Fix a failing build or change code to make a check pass. A failure is a finding.

## Confirmation

List the commands first. Then ask once, for the whole run. Do not ask again for each command.

```
Safe checks for <repository>. From <directory> I will run:
1. <build command>  (writes <bin/, obj/>; restores packages from <feed>)
2. <list-tests command>  (lists test names and runs none)
Both run the project's own build and test code.
I will not start the app, run integration tests, run DbUp or migrations, or touch a database or network service.
Run these? (yes / no)
```

If the commands are not known, do not guess. Ask the engineer for them, or mark the facts `unknown:`.

## Headless

When nobody can confirm (a run with no input), run no command. Behave as read-only. Mark the facts a check would have given as `unknown:` or `inferred:` (for example a build command read from the pipeline file but never run).

## Recording results

Write each result as a fact with its command and date in the `Sources:` line. Record the test count when you have it. If the engineer said no, or the run was headless, say that no check was run.

When the pipeline or the README names a project, solution or test folder that has no project file in the repository, the build cannot work as the repository stands. Report it as `conflict:`, with both sources. Do not add files and do not try to fix it.
