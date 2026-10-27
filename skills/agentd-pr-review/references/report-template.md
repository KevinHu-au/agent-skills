# Report template

Everything goes in chat, in this order: the summary comment, the finding comments, then the notes for the engineer.
Nothing is saved in the repository. Each paste-ready piece sits in its own ````markdown fence of four backticks, so a
code block inside a comment cannot close it, and the engineer copies the raw markdown into the Azure DevOps PR. Comments are written to the teammate: plain, specific and polite. Say what
is wrong and why it matters; do not lecture. Write `none` for an empty part.

## Summary comment

One comment for the PR overview. It says what the PR does compared with the work item, the test results per suite,
any failure that is new compared with the base, and the count of findings by severity.

Suggested vote, from the findings:

- Any Block: **Wait for author**.
- No Block, at least one Major: **Wait for author** or **Approve with suggestions**; the engineer chooses.
- Minor findings only: **Approve with suggestions**.
- No findings: **Approve**.

The engineer picks the vote. Write `Suggested vote: <vote>, because <reason>.` on one line just above the paste
block, outside it, so the vote is not pasted into the PR by mistake. With no Block and at least one Major, name both
votes on that line.

````markdown
**Review of <work item number>: <title>**

<What the PR does, compared with the work item, in two or three sentences. Name what it covers and what it leaves out.>

**Tests**

| Suite | Passed | Failed | Skipped | Note |
|---|---|---|---|---|
| <suite> | <n> | <n> | <n> | <new compared with the base / ran 0 tests / skipped: Docker not running / none> |

**Findings:** <n> Block, <n> Major, <n> Minor. Details are in the comments on each file.

**Open questions:** <n> open questions about the requirement, for the work item creator. | none
````

## Finding comment

One comment per finding, most severe first: every Block, then every Major, then every Minor. The engineer adds each
one on its line in the PR's Files view, so the first line repeats the place. Keep a code snippet to about 10 lines,
and add one only when it is clearer than words.

````markdown
**[Major]** `src/path/File.cs:42`

<What is wrong, in one or two sentences.>

**Scenario:** <the input or the steps, and the wrong result>

**Suggestion:** <what to change>

_Evidence: confirmed by a test run | confirmed: seen in the UI | supported by <sources> | inferred: from reading the code | unknown: <where I looked> | assumed requirement: see the question to the work item creator_
````

Use `[Block]`, `[Major]` or `[Minor]` as the tag. A sibling gap names the place the PR did not change, and says which
changed place it should match.

## For you only

Not to paste. Bold labels, in this order:

- **Requirement:** what "done" means for this PR, as you understood it.
- **Criteria:** each part of the requirement, marked covered, partly covered or not covered, with `path:line` and the
  test that covers it.
- **Assumptions:** what you assumed where the work item is silent, one line each.
- **Questions for the work item creator:** every gap in the requirement, and every sibling gap, as a question the
  engineer can forward. Each question names the finding it settles.
- **Old failures:** tests that fail on the base as well. Not findings.
- **Not run or not checked:** each suite or check you skipped, and why.

## Check in the UI

Only when a claim can be settled only in the running app. When nothing needs the UI, write no list. One line per
check:

- **<page>:** <action>. Look for: <what to look for>. Settles: <the finding or criterion>.
