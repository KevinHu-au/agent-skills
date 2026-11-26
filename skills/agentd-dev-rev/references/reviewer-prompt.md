# Reviewer prompt

Steps 5 and 7 of `agentd-dev-rev`. Fill this prompt for the reviewer of each round.

Use the harness-specific equivalent of this prompt. Skip style nits unless they indicate a real bug, security risk, compatibility break, or maintainability risk.

```markdown
Do not modify the repo. Do not run a `How to check` command from a criterion: read the diff instead.
Use `mktemp -d` for any scratch work. When you finish, remove only a path that your own `mktemp` printed, with `~/.agents/bin/rm-scratch <path>` and no other removal command.
If the script is missing or refuses, leave the path and report it.
Do the whole review yourself. Do not spawn other agents, and do not ask another model for a second opinion.

Review the staged diff for this task. This is the author's summary, and it may be wrong: check it against the work item and the code.

<task details>

The work item as pasted, word for word, with its acceptance criteria (or "none"):

<work item>

The engineer pasted these blocks. Copy them in verbatim, or write "none":

<diagnose hand-off block>
<blast-radius add-on block>
<intake engineer block>

Assumptions the author added (may be wrong), and defaults taken because nobody answered (or "none"):

<assumptions>

Risk areas from the project contract (or "none"):

<risk areas>

Project review criteria from the review rubric (or "none"). Copy each criterion in whole, with its criterion ID:

<criteria>

Risk tier and its reasons (or "none"):

<risk tier>

Check these first:
- Every acceptance criterion in the work item, as written: met, partly met, not met or out of scope, with `path:line`. Judge the staged code (`git show :<path>`), not the diff alone: a criterion the diff does not touch still counts. It is out of scope, not a finding, only when a pasted block puts it under `Follow-on` or `Do not change`, or the engineer said another change delivers it, quoted in the task details. With no list, find what the author's summary leaves out.
- Every list in the task details (calls, pages, cases), and every group a criterion names, is a claim. List the members from the code and name any it misses.
- Every `Do not change` item in the blocks. A change to one without the engineer's approval is a blocker.
- Every stop condition in the blocks. If the work should have stopped, say so.
- Every test under `Failing test first` and `Tests to write first` exists, and asserts what the block says.
- The risk tier above. Name each staged change with a signal its reasons miss, and the tier that signal gives. Report it as minor: a tier finding changes no code.
- Every project review criterion above whose `Applies to` matches a staged path. Cite its criterion ID in each finding. Block is blocker, Major is major, Minor is minor. A criterion whose Source starts `inferred:` is minor. A criterion with no `Applies to` line counts as `all`. One with no Source line counts as `inferred:`. One with no Severity line takes the severity of a heading that ends in `(Block)`, `(Major)` or `(Minor)`, or else is minor; a severity word anywhere else in the heading does not count. No criterion lowers a built-in blocker.

Focus areas:
- TDD/coverage: changed/fixed behavior has tests, preferably written before implementation. A test that asserts nothing, or only that no exception is thrown, is not coverage.
- Logic correctness: implementation meets the task requirements.
- Regression: existing behavior is not broken.
- Leave and return. A flow that leaves and comes back: a sign-in redirect, a payment page, an OAuth callback, a deep link, an app relaunch. State held in memory before it leaves is gone on return. Trace each return on its own: success, error or cancel, an expired or removed account that later comes back, and a second tab or window.
- Swallowed errors: an empty `catch`, an error turned into `null` or an empty list, a fallback that hides a failure, a lost stack trace, or no rollback when a step fails.
- Mocks: a mocked library or component raises an event only when the test makes it. Name each event (failure, cancel, removal) that no test raises.
- Duplication: change does not reimplement existing helpers/patterns.
- Security: no injection, authorization bypass, secrets, or PII logging.
- Dependency: new/updated packages were explicitly approved.
- Backcompat: no unapproved public API, HTTP contract, DB schema, stored procedure signature, serialized shape, or config-key break.
- Conventions: follows existing repo patterns.
- Task-specific risks you notice.

Output:
- Begin the report by stating the model you are running as.
- One line per acceptance criterion: met, partly met, not met or out of scope, with `path:line`. Write "no list" when the work item has none.
- A ranked list of findings, most severe first. Use severity: blocker / major / minor.
- Group related findings.
- For each finding include:
  - file:line, or doc section if no line applies
  - severity
  - concrete failure scenario: exact command sequence or input, and the wrong outcome
  - why the existing tests miss it
  - suggested fix
  - verification: "verified by running" or "from reading"
- Before you report a blocker or major finding about the code, name its trigger (the input, the state and the wrong outcome), and read the callers and the guards around it. A blocker also says why the existing guards (types, validation, the framework) do not stop it. If you cannot, lower it, or drop it and add it to the set-aside list below with the reason. An unmet acceptance criterion, a changed `Do not change` item or a missed stop condition already has its trigger.
- List every behavior you considered and set aside as outside the task, one line each, with the reason, or write "none". The author rules on each line.
- End with a short list of areas examined and found sound.
- If a focus area has no findings, say so in one line.
- Do not pad. Return only actionable findings and concise sound-area coverage.
```
