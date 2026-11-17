# Risk tiers

For a skill that makes or reviews a change and tells the engineer how much of it to read. The tier is reported only.
It changes no step, gate, severity or vote of the skill that reads this file.

## Tiers

| Tier | The change | The engineer reads |
|---|---|---|
| T0 Trivial | Changes only documentation, comments or new tests. No production code, configuration, script or package file changes, and no existing test changes. | The `Risk tier:` line and the list of changed files. |
| T1 Standard | Changes production code, and no T2 or T3 signal applies. | The report. |
| T2 High | Has at least one T2 signal, and no T3 signal. | Each file on the Read first list, in full. |
| T3 Critical | Has at least one T3 signal. | The whole diff, line by line. |

A file that is not documentation, a comment-only edit or a new test counts as production code. A new test method in
an existing test file is a new test. An edit to an existing test that keeps every assertion and expected value is T1.
A comment that acts as a directive counts as production code: a build tag, a compiler pragma, or a type, lint or
coverage ignore. When you cannot tell, it is production code.

## Signals

A signal comes from a changed path, or from what the diff does in it. Every signal below is always on.

**T2:**

- A public contract: an HTTP route, a DTO or serialised shape, a public API, or a configuration key.
- The database: the schema, a migration, a stored procedure, a view or a function.
- A generated file, or the file it is generated from.
- A package manifest or lock file: a package is added, removed or upgraded.
- A path or a calculation that the project contract names under Risk areas, in the base or in the change.
- A rubric criterion with Severity `Block`, a Source that is not `inferred:` and an `Applies to` other than `all`,
  that matches a changed path. Read the criteria as `reading-the-rubric.md` says.
- The review rubric or the project contract changes. Name each criterion or Risk area it removes or weakens.
- An existing test loses or changes a check: an assertion or expected value changes or goes away, a test is deleted,
  skipped or ignored, a snapshot or golden file is updated, a tolerance, timeout or coverage threshold is loosened, or
  a shared fixture or test data file changes.
- A blast-radius verdict of `Breaks` or `Unproven`, when the engineer pasted one.
- A signal you cannot decide. Write it `unknown:` and count it as T2.

**T3:**

- The place where authorisation is enforced: a role check, a policy, an authorisation attribute or switch, or sign-in.
- A risk of data loss: the change deletes or overwrites stored rows, drops or narrows a column, or adds a migration that
  cannot be undone.
- Secrets or credentials: how the code reads, stores or passes them.
- Money that is charged, paid or moved.

**Project rows.** The rubric may end with a `### Risk tiers` section: a table of Paths, Tier, Why and Source. Find the
rubric as `reading-the-rubric.md` says. Each row gives its Tier to every changed path that matches one of its globs.
The globs follow the rubric's `Applies to` rules. A row may raise a tier. It never lowers a built-in signal, and never
lowers production code below T1. A row whose Source is `inferred:` gives at most T2.

## Setting the tier

1. List the changed paths. For your own staged work, list the task's paths only: the paths you plan to change before
   any code exists, then `git diff --cached --name-only --no-renames` without staged files that are not part of the
   task. For another person's branch, use
   `git diff --name-only --no-renames <base>...HEAD`. `--no-renames` lists a moved file under its old path and its new
   path, so a file moved out of a glob still gets that glob's tier.
2. Give each path the highest tier that any signal gives it. A path with no signal is T0 or T1, as the Tiers table
   says.
3. The tier of the change is the highest tier of its paths.

Rules:

- **Base and change.** Read the project rows and the contract's Risk areas twice: in the base and in the change. For
  each path, use the higher tier. A row or Risk area the change adds can raise a tier. One the change removes or
  lowers still counts. For another person's branch, the base is `git show <base>:<path>` and the change is
  `git show HEAD:<path>`. For your own staged work, the base is `git show HEAD:<path>` and the change is the working
  copy. In the base, look in every place the lookup names, not only where the file is now, so a rubric or contract
  that moved keeps its base rows. An untracked file, or one outside the repository, has no base: read the working
  copy. When the base has neither file (a new rubric, or a repository with no commit), read the change only.
- **Only up.** The tier only goes up during a run. Set it again whenever the changed paths grow, and keep the higher
  one.
- **Lowering.** Only the engineer lowers a tier. Report it as `lowered by the engineer from T<n>: <reason>`. The
  lowering holds when you set the tier again, until a signal appears that the engineer did not see. Then raise the
  tier, keep the lowering line, and name the new signal.
- **No rubric.** Use the built-in signals, and say once that no project rows were read.

## Output

Write these lines in the notes for the engineer, never in text the engineer pastes elsewhere.

```
Risk tier: T<n>: <reason>; <reason>
Read first: <path> (<reason>); <path> (<reason>); <n> other files at T0 or T1
```

- A reason names its signal and its source: a `path:line`, a criterion ID such as `R3`, or `row <Paths>`.
- At T0 or T1, the reason is `no T2 or T3 signal`, and `Read first:` is `none`.
- Add `Tier rows changed: <row>; <row>` when the change adds, changes or removes a `### Risk tiers` row. Name each
  row by its Paths.
- Never write a secret, a customer name or personal data in a reason.
