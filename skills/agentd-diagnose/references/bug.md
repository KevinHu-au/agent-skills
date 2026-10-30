# Bug mode

Find why the code does the wrong thing, and prove it with a run.

## Reproduce

Read the whole error first, in the ticket and in your own runs: the full stack trace, inner exceptions, exit code and warnings. Note the file, line and error code. Do this before you name a cause.

1. Find the surface where the ticket saw the problem: an API call, a screen, a batch job, a test. Reproduce it there. A passing unit test on another path is not a reproduction. "Inconclusive" is not a pass.
2. Prefer an existing failing test, or the smallest command or call that fails for the stated reason. Use the Verify heading of the contract to drive the app.
3. If it does not reproduce, first run it several times (step 5). If it still never fails, change one thing at a time: the input, the user and role, the data, the configuration, the timing. Read the real state with a debugger, with logging that an environment variable or a command-line option switches on, or with a wrapper script in the scratch folder, without editing the repository. Do not edit a tracked configuration file for this. Do not guess at the state. If it still does not reproduce, stop and ask for the evidence you need.
4. If the ticket names an ID or a record that the test data does not have, you cannot reproduce with it. Say so. A "not found" for that ID is missing data, not the failure in the ticket, unless the ticket reports the same message. Ask for the real error text.
5. Run it many times (for example 20) and count the failures. If none fail, go on with step 3. If some fail, record what differs between a pass and a fail: order, timing, data, concurrency. Never use a fixed sleep to wait for a state. Wait on a condition (a state, a signal, a count), because a sleep hides the race. The failing test in the hand-off forces the failing order, for example with a latch, so it fails every time before the fix.

## Production evidence

Use this when the ticket's failure was seen only in production, or does not happen on the engineer's machine. You never run anything against production. You write the query and say what to paste back. The engineer, or a DBA, runs it and pastes the result.

- **Log or APM query:** write it for the platform the project uses (for example Application Insights KQL). Name the table, the time window, the filter that finds the failing request or user, and the columns to keep. Ask for the correlation ID, the full exception with inner exceptions, the request path and the build or release number. Ask for counts by hour or day, so you can see when it started.
- **Read-only SQL:** write it for a DBA, even when the Data access heading has no rule for production, because a person runs it. SELECT only, a bounded row count, IDs and non-personal columns. Say which environment it is for. The rules in SKILL.md, Running commands, Data apply to the text of the query: nothing that writes or locks (no `SELECT ... INTO`, `FOR UPDATE` or lock hints), no full count of a large table (size it from catalog statistics or an indexed key), and no personal columns. So do the rules in `references/data.md`.
- **Crash report or dump:** ask for the report or the stack, the app version, the OS or runtime version, and the time. For a .NET dump see `references/dotnet.md`. For an iOS `.ips` report see `references/ios.md`.
- **Redaction:** tell the engineer to remove names, emails, tokens and keys before pasting. If a paste still holds them, do not repeat them in the report.
- **Tier:** a result that a person ran and pasted back is `confirmed` for the fact it shows. Production evidence alone is `supported` for the root cause. A code cause is `confirmed` only when a local run, built from the inputs the logs show, produces the ticket's failure. An environment cause is `confirmed` under the conditions in SKILL.md, Evidence: a person's read-only check shows the differing state (for example the certificate's expiry date), that state is on the path of the failing call, and the first failure in the log fits it. If you can do neither, the verdict is Not confirmed. Say which input or check is missing. When the cause is in the environment, the hand-off has no code fix: see `references/report-template.md`.

## Environment differences

When the failure happens in one environment and not in another, list these as candidate causes next to the code causes. Check each one, and report what you could not check as `unknown:` plus who to ask.

- Certificates: expired, not trusted on that host, or a different chain.
- DNS, proxy, firewall or TLS version.
- Permissions: the account the service runs as, file and folder rights, a missing role or grant.
- Versions: the runtime, the operating system, a dependency, the database engine, a client that is still old.
- Configuration: a feature flag, an app setting or a connection string that differs. Name the key, never the value.
- Time: the server time zone, the clock, daylight saving, culture settings.
- Resources: memory, disk space, connection pool, thread pool, rate limits, a quota.
- Data: a row or a volume that only production has.

## Find the cause

- List the candidate causes before you test any. Include the ticket's theory.
- Find a working case: a similar path that works, an earlier commit, an input that passes. List every difference from the broken case, however small. Do not drop one because it "cannot matter". Check first the difference that rules out the most candidates. Likelihood breaks a tie.
- To run an earlier commit, export it with `git archive` into the scratch folder. Never run `git checkout`, `git stash` or `git bisect` in the repository. With no scratch folder, read old files with `git show <ref>:<path>`. If the export does not build or run for a reason that has nothing to do with the ticket, say so and read old files with `git show`. Do not copy local settings or install packages to make it run.
- With several components (client, API, service, database, queue), check what enters and leaves each one in a single run. Read the state as step 3 describes, without editing the repository. The first boundary where the data is already wrong shows which component to read.
- Trace the bad state backward: where does it start, what passed it in, and what passed it to that. Keep going until you reach where it first goes wrong. If that state is not legitimate (see below), the fix belongs there, not where it shows.
- Pick the check that rules out the most candidates at once, and change one thing at a time in it. Cross out what the evidence rules out.
- Keep asking "why". Stop when the answer is a decision the code makes, or a state it does not handle, and not a side effect of an earlier step.
- Decide whether the bad state is legitimate: a state the system is allowed to reach. If it is legitimate, the code that failed on it is the cause of the bug. If it is not, a check at the point of failure only hides the bug. Find what put the system in that state. Typical hiding places are a retry that masks a failure, an exception that is caught and dropped, and a value that is clamped into range.
- If it fails only after a restart or a deploy, suspect persisted state first: configuration, caches, files, serialised state, and data.
- For a regression, find the commit that changed the behaviour (`git log -S`, `git blame`) and read its diff. Also compare what else changed between the last good release and the first bad one: dependency versions, configuration, runtime, environment and data.
- When two theories built on the same premise have failed, write the premise in one sentence. Then find a check whose result would differ if the premise were wrong, and run it. Do not try a third theory first.
- When you find the cause, search for the same fault elsewhere: other callers, copies of the pattern. List every place.
- If the key fact was hard to find, suggest a log line or an assertion that would make it easy to find next time.
- Ask why the bug escaped: why tests, review or monitoring did not catch it. Write the answer on the report's `Escape:` line. Name the missing test, the unchecked input or the alert that did not exist. Mark a guess `inferred:`. The missing test feeds the failing test in the hand-off. A missing log line is the suggestion above.

## Propose

- Propose the smallest change that the evidence supports. Do not include a change only because it might help. Without evidence it is a guess.
- Say what the fix does not change.
- Write the failing test for the hand-off: where it lives (next to the existing tests of that code), what it arranges, what it calls, what it asserts, and the failure it gives before the fix. It encodes the intended behaviour, not the current code. `agentd-dev-rev` writes it first and watches it fail for the stated reason.
- If a cheap local test is not practical (it needs production state, a heavy harness or brittle mocks), say why. Name the closest executable check instead: a script, a request, a query.
