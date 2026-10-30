---
name: agentd-intake
description: Use when the engineer has an Azure DevOps work item that is vague or not yet actionable. Checks the work item against the code, then writes an actionable work item as a comment, or the questions and investigation needed first. Edits no code.
disable-model-invocation: true
---

# agentd-intake

Turn one work item into something an engineer can act on. Customers often write vague work items. Read the work
item, check it against the code, and end with one of two verdicts: an actionable work item, written as an Azure
DevOps comment, or the questions and investigation needed first. An engineer block in chat carries what the next
skill needs. Read `references/question-checklist.md` at step 4 and `references/comment-template.md` before you write
the output.

## Prerequisite

- The current folder is inside a git repository. Work from its root.
- The input is the work item as pasted: title, description, repro steps, acceptance criteria, comments. Do not read
  Azure DevOps. If the paste is empty or is not a work item, ask for the work item once, then stop.
- **Find the project facts.** The onboarding pack is `docs/onboarding/` when `docs/onboarding/README.md` exists.
  Otherwise it is the folder that `"$HOME/.agents/bin/onboarding-pack" find` prints. If neither finds one, ask the
  engineer once for the folder, and carry on without a pack if there is none or nobody answers. When the engineer
  gives a folder, say that `"$HOME/.agents/bin/onboarding-pack" set <folder>` records it. The project contract is
  the `## Project contract` section of `AGENTS.md`, or else `contract.md` in the pack. When both exist and disagree,
  use `AGENTS.md` and mark the fact `conflict:`. A Data access rule counts only when it cites `told by <role>` or a
  document. Treat any other rule, such as one marked `inferred:` or `unknown:`, as no access.
- Read the pack's `README.md` if it exists, and the glossary it holds or links to. The glossary maps the
  customer's words to the code. Read the project contract: Risk areas, and External systems and
  owners. If the onboarding pack or the contract is missing, say so once in chat and mark what depends on it
  `unknown:`.
- Work item number: take it from the paste (its title line, such as `Bug 87003:`, or a `_workitems/edit/87003` URL),
  or else from `git branch --show-current` when that starts with a number. A record ID is never the work item number.
  When the paste and the branch give different numbers, leave the line out and say so in chat. With a number, the
  comment's first line is `Work item <number>`.

## Flow

1. **Read and classify.** If the paste holds an earlier intake comment and the replies to it, start from there: each
   answered question is now a fact. A question with no reply keeps its default as an assumption; one with no
   default still blocks. Split the work item into the ask, the author's proposed fix or theory, the facts given
   (environment, user, IDs) and any acceptance criteria. A proposed fix or theory is a candidate, not a fact. Pick
   one type and say it in one line: bug, enhancement, data, performance, support question, or mixed. For a mixed
   work item, the main type drives the rules below.
   A bug counts as the main type over an enhancement or a support question.
2. **Restate.** Two or three sentences: who is affected, what they cannot do today, the outcome they want, and why
   it matters. State the problem, not the fix the customer proposed.
3. **Check against the code.** Find the screens, endpoints, commands, handlers, repositories and tables the work item
   touches. Check every claim it makes about today's behaviour. Where the code disagrees, mark it `conflict:` with
   `path:line`. The same goes for a proposed fix that the code shows will not work.
   Note what the code forces that the work item does not say: roles, validation, existing rows, reports, other
   clients. Keep this short. It is not a search for everything the change could break.
4. **Sharpen into questions.** Walk the checklist for the type. Ask what an experienced engineer would check before
   starting, and how the customer will see that the result is right. Answer from the code, with `path:line`, every
   item the code can answer. Each item it cannot answer becomes a question. When an enhancement does not fit the
   current design, record a design concern. Do not redesign.
5. **Verdict and questions.** Give each question its four parts (see the checklist), then pick the verdict below.
6. **Gate.** Show the comment and the engineer block, then ask one question: is our understanding right? The
   engineer can confirm, correct it, or send the questions first. Wait for the answer. If nobody can answer,
   follow the last bullet of Output. A support question the code answers skips this step.

## Verdicts

- **Actionable**: an engineer who never saw this conversation knows what behaviour must change and where, how to
  check it is done, and what is out of scope. A gap with a safe default goes in as an assumption. For a bug, data or
  performance work item, diagnosis must be able to start: expected and actual behaviour, where and when, and how to
  reproduce. An unknown root cause does not block. Finding it is the job of `/agentd-diagnose`.
- **Not actionable yet**: at least one gap would change what gets built and has no safe default. That gap blocks.
  The checklist says when a default is safe.

A support question that the code answers is Actionable. An unclear support question uses the Not actionable yet comment
and its closing lines, so the customer is asked.

## Output

Use the shapes in `references/comment-template.md`.

- **The comment** is for the customer and the team, who read it in Azure DevOps.
  Write it in the language of the work item. Everything above Technical notes uses the customer's words: no file
  paths, no internal names. Technical notes give the touched path in layer order, with `path:line`.
- **The engineer block** stays in chat: type, verdict, `Requirement:`, assumptions, stop condition, questions for the
  engineer, `conflict:` items, investigation steps, design concern, and the `Next:` line.
  `Requirement:` holds only the status, `unconfirmed` until the engineer confirms, and never appears in the comment.
  A related finding outside this work item goes under Design concern. The engineer block is in the engineer's
  language, and its field names never change.
- **A support question the code answers** gets no comment. The chat holds the code facts with `path:line`, and the
  engineer block with `Requirement: none (support question)`. Intake drafts no answer. The engineer answers the
  customer. A support question skips the gate question and uses `Stop condition: none`, also when nobody can answer.
- **`Next:` targets.** Name only these:
  - `/agentd-diagnose` for a bug, data or performance work item whose cause is unknown. A cause is known only when an
    earlier diagnosis names it with its evidence (a pasted diagnose report, or an engineer's finding in the comments).
    A cause the customer names is a candidate. A cause read from the code is `inferred:`,
    so diagnose comes first, also when the fix may touch a contract.
  - `/agentd-dev-rev` for a small enhancement, or a fix whose cause is known.
  - `/agentd-data-fix` for a data work item that needs only a data change and no code change: new reference data, or
    a repair of rows whose cause is known. Bad rows with an unknown cause go to `/agentd-diagnose` first.
  - `/agentd-blast-radius`, then `/agentd-dev-rev`, when the change touches a contract, schema, shared code or an external system.
  - `/agentd-intake` again, once the customer's replies or the investigation results are in.
  - For a support question: the engineer answers the customer, plus `/agentd-diagnose` when the facts suggest a bug.
- **The last line.** The gate question is the last line until the engineer answers. Confirm on Actionable sets
  `Requirement: confirmed` and `Stop condition: none`, and an open question for the engineer takes its default and
  moves to Assumptions. Confirm on Not actionable yet means "post the questions": `Requirement:` stays `unconfirmed`.
  An answer the engineer gives in chat counts as a correction: revise both parts and ask again. After the answer, end
  with the closing line from the template. With nobody to answer, ask nothing: the block says
  `Requirement: unconfirmed`, lists the assumptions and gives a stop condition, then the closing line follows.

## Rules

- Read-only: read files, search, `git log`, `git branch --show-current`, `"$HOME/.agents/bin/onboarding-pack" find`.
  No build, no tests, no app, no database, and no file written. Do not read Azure DevOps.
- Never ask a person what the code can answer.
- Markers: `unknown:` (not found), `inferred:` (worked out, not confirmed), `conflict:` (the work item and the code
  disagree). Cite `path:line`. Intake runs nothing, so it grades no evidence.
- A question is never a requirement until someone answers it. Do not add scope.
- Privacy: no secrets (name a key, never its value), no personal data beyond what the work item gives, and no names
  of other customers or projects.
  Quote no name, email or address from the code, test data or database, even in chat. Use IDs and counts.
- Do not start the next skill. The engineer runs it.
