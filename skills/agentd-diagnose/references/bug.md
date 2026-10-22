# Bug mode

Find why the code does the wrong thing, and prove it with a run.

## Reproduce

1. Find the surface where the ticket saw the problem: an API call, a screen, a batch job, a test. Reproduce it there. A passing unit test on another path is not a reproduction. "Inconclusive" is not a pass.
2. Prefer an existing failing test, or the smallest command or call that fails for the stated reason. Use the Verify heading of the contract to drive the app.
3. If it does not reproduce, change one thing at a time: the input, the user and role, the data, the configuration, the timing. Read the real state with a debugger, with logging that an environment variable or a command-line option switches on, or with a wrapper script in the scratch folder, without editing the repository. Do not edit a tracked configuration file for this. Do not guess at the state. If it still does not reproduce, stop and ask for the evidence you need.
4. If the ticket names an ID or a record that the test data does not have, you cannot reproduce with it. Say so. A "not found" for that ID is missing data, not the failure in the ticket, unless the ticket reports the same message. Ask for the real error text.

## Find the cause

- List the candidate causes before you test any. Include the ticket's theory.
- Run the check that rules out the most candidates at once. Cross out what the evidence rules out.
- Keep asking "why". Stop when the answer is a decision the code makes, or a state it does not handle, and not a side effect of an earlier step.
- Decide whether the bad state is legitimate: a state the system is allowed to reach. If it is legitimate, the code that failed on it is the cause of the bug. If it is not, a check at the point of failure only hides the bug. Find what put the system in that state. Typical hiding places are a retry that masks a failure, an exception that is caught and dropped, and a value that is clamped into range.
- If it fails only after a restart or a deploy, suspect persisted state first: configuration, caches, files, serialised state, and data.
- For a regression, find the commit that changed the behaviour (`git log -S`, `git blame`) and read its diff.
- When two theories built on the same premise have failed, write the premise in one sentence. Then find a check whose result would differ if the premise were wrong, and run it. Do not try a third theory first.
- When you find the cause, search for the same fault elsewhere: other callers, copies of the pattern. List every place.
- If the key fact was hard to find, suggest a log line or an assertion that would make it easy to find next time.

## Propose

- Propose the smallest change that the evidence supports. Do not include a change only because it might help. Without evidence it is a guess.
- Say what the fix does not change.
- Write the failing test for the hand-off: where it lives (next to the existing tests of that code), what it arranges, what it calls, what it asserts, and the failure it gives before the fix. It encodes the intended behaviour, not the current code. `agentd-dev-rev` writes it first and watches it fail for the stated reason.
- If a cheap local test is not practical (it needs production state, a heavy harness or brittle mocks), say why. Name the closest executable check instead: a script, a request, a query.
