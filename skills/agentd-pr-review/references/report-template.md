# Report template

Everything goes in chat, in this order: the summary comment, the finding comments, then the notes for the engineer.
Nothing is saved in the repository. Each paste-ready piece sits in its own ````markdown fence of four backticks, so a
code block inside a comment cannot close it, and the engineer copies the raw markdown into the Azure DevOps PR. Comments are written to the teammate: plain, specific and polite. Say what
is wrong and why it matters; do not lecture. Write `none` for an empty part.

## Summary comment

One comment for the PR overview. It says what the PR does compared with the work item, the test results per suite,
any failure that is new compared with the base, and the count of findings by severity. With no work item, it compares
the PR with the inferred intent instead.

Suggested vote, from the findings:

- Any Block: **Wait for author**.
- No Block, at least one Major: **Wait for author** or **Approve with suggestions**; the engineer chooses.
- Minor findings only: **Approve with suggestions**.
- No findings: **Approve**.
- With no work item: the same votes, because the requirement was not checked. The vote line ends with `Only after you check the work item.`

The engineer picks the vote. Write `Suggested vote: <vote>, because <reason>.` on one line just above the paste
block, outside it, so the vote is not pasted into the PR by mistake. With no Block and at least one Major, name both
votes on that line.

````markdown
**Review of <work item number>: <title>** | **Review of <branch>: no work item given. The requirement was not checked.**

<What the PR does, compared with the work item or the inferred intent, in two or three sentences. Name what it covers and what it leaves out.>

**Tests**

| Suite | Passed | Failed | Skipped | Note |
|---|---|---|---|---|
| <suite> | <n> | <n> | <n> | <new compared with the base / ran 0 tests / skipped: Docker not running / none> |

**Findings:** <n> Block, <n> Major, <n> Minor. Details are in the comments on each file.

**Open questions:** <n> open questions about the requirement, for the work item creator. | <n> open questions, for the PR author. | none
````

## Finding comment

One comment per finding, most severe first: every Block, then every Major, then every Minor. The engineer adds each
one on its line in the PR's Files view, so the first line repeats the place. Keep a code snippet to about 10 lines,
and add one only when it is clearer than words.

````markdown
**[Major]** `src/path/File.cs:42`

<What is wrong, in one or two sentences.>

**Scenario:** <the input or the steps, and the wrong result>

**Reproduce:** <Block only: replace this line with the Reproduce part below. Delete this line from a Major or Minor comment.>

**Suggestion:** <what to change>

_Evidence: confirmed by a test run | confirmed: seen in the UI | supported by <sources> | inferred: from reading the code | unknown: <where I looked> | assumed requirement: see the question to the work item creator | inferred intent: see the question to the PR author_
````

Use `[Block]`, `[Major]` or `[Minor]` as the tag. A sibling gap names the place the PR did not change, and says which
changed place it should match.

A finding from a rubric criterion adds the criterion ID and title after the path, for example
`**[Major]** `src/path/File.cs:42` (R3: <title>)`. The teammate may not have the rubric file, so write the rule in
the comment text as well as the ID. When the diff shows the breach plainly, the evidence line is `supported by the diff
and R<number>`.

### Reproduce (Block only)

Every `[Block]` comment has a `**Reproduce:**` part between `**Scenario:**` and `**Suggestion:**`, in the same comment
and the same fence, so the engineer and the author can check the finding themselves. Major and Minor findings do not
get one. Write it for the surface the user touches: a web page, an iOS screen, a desktop window, an API call, a job.
Name the real screen, menu path or route, field and button from the code. For a native app, look for labels in the
resource or localisation files; if you cannot find one, describe the control and mark the label `unknown:`.
This is the shape of the part. It replaces the one-line `Reproduce` placeholder above:

````markdown
**Reproduce:** <Surface: web app | iOS app | API | command | other>. <Add "Use a test environment and test data: the steps write data." only when a step changes data.>

Setup:
- <data, project or account state, settings, feature flags, permissions, and the build or branch to run>

Steps:
1. <where to go: menu path, route or screen>
2. <the exact action: what to tap, click or type (a placeholder, not a real value), and which record>
3. <wait for / reload / reopen, if the result shows only after that>

| After the last step | Base (<short commit>) | This branch (<short commit>) |
|---|---|---|
| <what to read: a field, a message, a stored value> | <key name or placeholder> | <key name or placeholder> |

Avoid: <an action that would muddy the result, and why. Leave out when there is none.>

_Steps come from reading the code and were not run._
````

Rules:

- **Setup comes first.** Find what makes the problem visible: a settings flag, a record type or state, a role, a locked
  or unlocked item, a data size. Cite the gate as `path:line`, for example the condition that shows the field. If the
  problem shows only in that state, say so, and say what the engineer sees in other states.
- **Steps are exact.** One action per step. Use the labels as the screen shows them. Say when to reload or reopen.
- **Both columns.** Get `<merge-base>` from `git merge-base <base> HEAD` and read the base with `git show <merge-base>:<path>`.
  Both are read-only. Use `wt-base` if the base re-run made one; add no worktree for this. If the merge base cannot
  be found, the column is `unknown:`.
- **Not reachable from the UI.** For a build failure, a failing test, an API-only or job-only path, or a SQL change,
  replace Steps with the command and test name, or the request (method, route, a body with key names only) and the
  response to look for. If no way to trigger it exists, write `**Reproduce:** not reachable from a screen or a command.
  <where it runs>` on one line, and say who can trigger it.
- **No invention.** Never write a step, a label or a route you did not find. Mark a gap `unknown:`.
- **Safe data.** Name no customer, secret or personal data. Use key names and placeholders in the table, never real
  values, as SKILL.md Rules say.
- **The footer.** Keep `_Steps come from reading the code and were not run._` only when the Evidence line is not a
  confirmation. When a test run or the engineer confirmed the finding, leave the footer out.
- If the engineer later says what they saw, update the finding's evidence tier and severity, as the `Check in the UI`
  bullet in SKILL.md says. When a finding becomes Block, add its Reproduce part; when it stops being Block, remove it.

## For you only

Not to paste. Bold labels, in this order:

- **No work item:** only in no-work-item mode, the line `The requirement was not checked. Check the work item yourself
  before you vote.` With a work item, leave this label out; do not write `none`.
- **Requirement:** what "done" means for this PR, as you understood it. With no work item, label it
  **Inferred intent:** and name the source of each part: the branch name, a commit, the PR description or a test.
- **Criteria:** each part of the requirement, marked covered, partly covered or not covered, with `path:line` and the
  test that covers it.
- **Assumptions:** what you assumed where the work item is silent, one line each. With no work item, write `see
  Inferred intent`.
- **Questions for the work item creator:** every gap in the requirement, and every sibling gap, as a question the
  engineer can forward. Each question names the finding it settles. With no work item, label it
  **Questions for the PR author:**.
- **Old failures:** tests that fail on the base as well. Not findings.
- **Not run or not checked:** each suite or check you skipped, and why.
- **Rubric:** the rubric you used and where it was read from, and any criterion that this PR edits. With none, the
  last line of this `For you only` part is `No project rubric. Run /agentd-review-rubric to draft one.` Put it last
  even when a `Check in the UI` list follows.

## Check in the UI

Only when a claim can be settled only in the running app. When nothing needs the UI, write no list. This list is for the
engineer and is not pasted. A Block finding that needs the running app has its steps in its `Reproduce` part: give it a
line in the same format, with the action `follow Reproduce on <finding>`, and do not repeat the steps. A Block finding
settled by a test run, a build or a command gets no line. One line per check:

- **<page>:** <action>. Look for: <what to look for>. Settles: <the finding or criterion>.
