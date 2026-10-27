# Question checklist

Use at step 4. Walk the section for the work item's type. For a mixed work item, walk the main type's section first.

- **Answer from the code first.** An item the code can answer is not a question. Give the answer with `path:line`.
- **Four parts.** Each question says what is missing, what changes with the answer, who to ask, and a default (or
  "none, this blocks").
- **Safe default.** A default is safe when a wrong guess is cheap to undo and nobody outside the team relies on it
  first. It is never safe when it changes a contract, the input of an external system, existing data, permissions, or
  a figure someone reports. A gap with no safe default blocks. Adding a column, field or value to something an
  external system reads always blocks until its owner agrees, even when the addition looks harmless. A request
  from the customer's business side does not show that the system reading it accepts the change. With no project
  contract, treat any file, API or report that leaves the system as read by an external system. Once the owner of
  the contract or external system has agreed to the change, a small detail inside it (an empty value, a number
  format) may take a default. List it as an assumption.
- **Where a question goes.** A question for someone who reads the work item (the customer, its author, a business
  analyst) goes in the comment. A question for the engineer, or for someone outside the work item (a DBA, the owner
  of a partner system), goes in the engineer block. When someone who reads the work item also owns the system, ask
  in the comment. Their explicit answer counts as the owner's agreement. Their request alone does not.
- **Scope.** Scope never grows from this list. An idea becomes a question, never a requirement.
- **Keep it short.** At most five questions in the comment. Keep the ones whose answer changes what gets built.

## Bug

- The four facts diagnosis needs: expected behaviour, actual behaviour, where and when (environment, user, record
  IDs, time), and how to reproduce. When one is missing and the code cannot supply it, ask. It blocks only when
  diagnosis cannot start without it.
- Is the reported behaviour a fault, or the design? Check the code and any acceptance criteria.
- Reach: one user, some records, or all? Since when: a release, a data load, a date?
- Records that are already wrong: do they need a repair? A repair is a separate piece of work.
- How will the customer see that it is fixed?

## Enhancement

- The problem behind the requested change. Does the proposed fix solve it? Check it against the code.
- Who uses it: roles and permissions.
- Edge cases: empty values, duplicates, very large values, cancelled or deleted records, time zones, and how text
  sorts and matches (capital letters, accents).
- Existing data: does old data need the new behaviour?
- Contracts: exports, APIs, reports and other systems that read what changes.
- Audit and history.
- How the customer will check the result. Write it as an acceptance check.

## Data

- Which records, by ID or count, and in which environment.
- The expected value against the actual value, and the source of truth.
- Since when, and what wrote the records (an import, a job, a screen).
- Repair: a one-off fix, or also stop new bad records? Who approves a change to production data? A repair with no
  code change is written by `/agentd-data-fix`. When new bad records are still being written, the work item also
  needs a code fix: with a known cause, `/agentd-dev-rev` for the code and `/agentd-data-fix` for the rows; with an
  unknown cause, `/agentd-diagnose` first.
- Reports or figures that already used the bad data.

## Performance

- Which action, on which screen or job, for whom, and in which environment.
- The numbers: how long today, how long is acceptable, and how it was measured.
- Since when, and what changed then (a release, data growth).
- Volume: records, users, how often.
- How the customer will measure the result.

## Support question

- The exact question, in the customer's words.
- The screen, report or record it is about.
- Answer from the code with `path:line`. Ask only when the question itself is unclear.
- When the facts suggest a fault, say so in the engineer block.
