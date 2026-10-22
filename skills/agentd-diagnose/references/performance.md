# Performance mode

Measure first. Tie every claim to a number from a run. Reading the code gives candidates, not numbers.

## Before you run

- Write the claim you would ship, in its own words: "the monthly report takes 40 s for 20,000 orders; the target is 5 s". Every check below tests that sentence.
- Read the script or command that measures. Find out which part it times, what it counts, and what it leaves out.
- Check that the machine is quiet (`uptime`). If it is not, say so, and alternate the runs you compare.
- Run it the way production runs it: the optimised build if the stack has one, production-like data and configuration, and a cache that is as warm or as cold as production's.

## Baseline

- Run at least 5 runs. Report the median and the range. A gap smaller than the spread is no gap.
- Measure the path the user waits on, end to end, with realistic data size.
- Keep the command and the number. The hand-off needs them for the run after the fix.

## Find the limiter

Name the thing that sets the time: the CPU, waiting on locks, disk or network I/O, the number of queries, or a query plan. Find it with a profile, a trace, a query plan or counters, and trace it back to the source. A guess from the code is not a measurement. Time each layer (client, API, service, database, network) in one run, without editing the repository. Then you know which layer holds the time before you profile inside it. Ask why the result is not twice as fast. If you cannot answer, you have not understood what you measured.

To compare, find a fast case: a smaller input, an earlier commit or release, or a measurement the engineer already has from another environment. To run an earlier commit, export it with `git archive` into the scratch folder, as `references/bug.md` says. List every difference from the slow case, including dependency versions, runtime and configuration. Report these differences. Do not change a dependency or install one. Change a setting only through an environment variable or a copy in the scratch folder. Change one thing at a time, and check first the difference that rules out the most candidates. Measure again after each change.

Ask what else the number could be measuring: failed requests, cached or skipped work, a code path that never ran, or the load tool itself. Count the failures and the non-success responses. Check that the work really happened.

## Mantras

Try them in this order, cheapest first. Stop at the first one that meets the target.

1. Don't do it. Skip work whose result nobody uses.
2. Don't do it again. Do it once and keep the result.
3. Do it less.
4. Do it later.
5. Do it when they're not looking.
6. Do it concurrently.
7. Do it cheaper.

## Vet the number

Before you report it, check five things. Did any run fail? Did the work really happen? Does the changed part take a large share of the whole path, end to end? (Removing a part that takes 10% of the time saves at most 10% of the time.) Was every side set up the way production is? Does the result repeat across runs?

## Verdict

Lead with one of: reproduced slow, not reproducible, inconclusive. In the report, reproduced slow with a named limiter is Confirmed, not reproducible is Not reproduced, and inconclusive is Not confirmed. State the number and its unit, how many runs, the spread and the limiter. For example: "median 4.1 s over 5 runs, range 3.9 to 4.4 s, bound by 80,000 single-row queries". Call the result inconclusive when you cannot name the limiter, and name the gap.

## Hand-off

The failing test for `agentd-dev-rev` should guard the cost you found, not the clock. Prefer an assertion on a statement count, a number of calls or an allocation count. A time limit works only when it is set well above the noise. If no cheap test can do it, say why, and give the baseline command and number as the check. The Verification line repeats the baseline command and number, so the run after the fix is comparable.
