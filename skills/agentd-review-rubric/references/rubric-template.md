# Rubric template

The shape of `review-rubric.md`. The review skills read this file and cite its criterion IDs, so keep the shape exact.

## File

Write the file like this. Replace each `<...>`.

```markdown
# Review rubric
Scanned commit: <output of git rev-parse HEAD>
Date: <YYYY-MM-DD>
Owner: <role, or unknown: ask the team>. The team owns this file. The review skills only read it.
Lint: <the lint command, or its config file; leave this line out when there is none>
Built-in rules win: a rubric never lowers the severity of a failing build or test, a security problem, data loss
or a contract break. It may add checks and raise severity.

### R1: <short title>
- Rule: <one sentence a reviewer can check>
- Applies to: <path glob, or all>
- Severity: Block | Major | Minor
- How to check: <a command, or what to read in the diff>
- Source: <path:line | URL | told by <role>> | inferred: <where it came from>
```

The heading `### R<number>:` is the fixed anchor. The review skills search for it, so never rename it, and never
reuse an ID. A criterion that is dropped keeps its number: leave a gap.

## Writing a criterion

- One idea per rule. One sentence, active voice, in the words the team uses.
- Write only a rule a reviewer can check from the diff or a command. Drop "write clean code".
- Skip a style rule that the lint or format check already enforces. Name that command once, in the optional `Lint:`
  header line.
- `Applies to` narrows the rule to the paths where it holds. Use `all` only when it holds everywhere. A reader treats
  a missing `Applies to` line as `all`.
- A criterion with no source is `inferred:` and `Minor`. Add a source to raise it.

Two examples, from invented projects.

```markdown
### R1: New endpoints list their roles
- Rule: Every new controller action names the roles that may call it.
- Applies to: src/Api/Controllers/**
- Severity: Major
- How to check: Read each new action in the diff for an authorisation attribute that names a role.
- Source: CONTRIBUTING.md:42

### R2: Migrations are never edited
- Rule: A migration that already ran is not edited. Add a new one instead.
- Applies to: db/migrations/**
- Severity: Block
- How to check: Run git diff --diff-filter=M --name-only on db/migrations; the list must be empty.
- Source: told by the tech lead
```

```markdown
### R1: Money uses the shared type
- Rule: Amounts use the Money type, never a float.
- Applies to: app/billing/**
- Severity: Major
- How to check: Search the diff for float or double on a field that holds an amount.
- Source: docs/architecture.md:18

### R2: Screens have an empty state
- Rule: A new list screen shows a message when the list is empty.
- Applies to: app/screens/**
- Severity: Minor
- How to check: Read the new screen for a branch that handles an empty list.
- Source: inferred: the existing list screens all do this
```

## Risk tiers

An optional section after the last criterion. It names the paths that need more of the engineer's attention than the
built-in signals give. `risk-tiers.md`, next to this file, holds the tiers, the built-in signals and how skills read
this section.

```markdown
### Risk tiers

| Paths | Tier | Why | Source |
|---|---|---|---|
| <path glob, or several separated by commas> | <T1, T2 or T3> | <one short reason> | <path:line, URL, told by <role>, or inferred: <where it came from>> |
```

- The heading is `### Risk tiers`, at the same level as the criteria, so the section also fits inside a
  `## Review rubric` section in `AGENTS.md`. Never rename it. It is not a criterion and has no ID.
- At most 10 rows, one reason each. A glob follows the `Applies to` rules.
- A row raises a path's tier. It never lowers a built-in signal, so a row that only repeats one adds nothing: leave it
  out. There is no T0 row: a row never lowers production code below T1.
- A row with no source is written `inferred:`, and gives at most T2.

An example, from an invented project.

```markdown
### Risk tiers

| Paths | Tier | Why | Source |
|---|---|---|---|
| src/Billing/** | T3 | Invoice totals and payment amounts | told by the tech lead |
| src/Shared/Components/** | T2 | Every screen uses these components | CONTRIBUTING.md:30 |
| docs/runbooks/** | T1 | Support follows these steps during an incident | inferred: linked from the on-call page |
```
