---
name: agentd-explain
description: Use when the engineer needs to understand a business term, a figure, a status or a whole domain in a project. Answers with the business meaning and the code path from the frontend through the backend to the database or external system. Read only, apart from an export the engineer asks for. Edits no code.
disable-model-invocation: true
---

# agentd-explain

Answer one question for the engineer: what something means in the business, and the code behind it, from the screen
to the data source. The answer is for the engineer, never the customer. This is a side tool that runs any time. Read
`references/answer-template.md` at step 1: it holds the vague-question shape and the answer shapes.

## Prerequisite

- The current folder is inside a git repository. Find its root with `git rev-parse --show-toplevel` and work from
  there.
- The input is one plain-English question. If it is empty, ask for the question once, then stop.
- Sources, in this order: `docs/onboarding/README.md` and its glossary; earlier exports in `docs/onboarding/explain/`;
  user guide documents in the repository; the project contract in `AGENTS.md` (Risk areas, and External systems and
  owners); then the code. If the onboarding pack or the contract is missing, say so once, as one Gaps line, and carry
  on from the code.
- The code wins every conflict. Where a document disagrees with the code, mark `conflict:` with both sources and use
  the code's value. An earlier export is just another document: every claim in it is checked against the code.
- Detect each stack and read each matching reference: `references/dotnet.md` (`*.sln` or `*.csproj`),
  `references/react.md` (`package.json` that lists `react-dom`), `references/ios.md` (`*.xcodeproj`, `*.xcworkspace`,
  or a `Package.swift` whose sources import SwiftUI). For a stack with no reference, use the generic order: screen →
  client state → client service → API boundary → application logic → data access → storage or external system.
  When the engineer gives the path of a second repository, detect its stack too and read its reference.
- A layer the stack does not have is `none`. A layer that should exist but was not found is `unknown:`.

## Flow

1. **Read the question.** Pick its kind: `figure or term`, `status`, `code`, `domain`. A question that could mean
   several things is vague: search briefly, list at most five matches grouped by calculation, say how many more there
   are, and ask "Which one?". Never guess. With nobody to answer, list the matches and stop.
   - A question that says where the figure shows is specific: the screen or tab, plus the row or column when one screen
     shows it at several levels. Answer it. A bare name ("What is X?") does not say where.
   - One name shown at several levels or on several screens is vague only when the matches are worked out differently.
     When every match comes from one calculation (an item figure and its group total, one field on two screens),
     answer once and say where else it shows.
   - A status set by several code paths is one question, not a vague one: list every path.
2. **Read the sources.** In the order above. Note each claim a document makes about the subject.
3. **Find the core code.** The entity or data model; where the calculation lives (a service, a handler, a stored
   procedure, or the frontend); and the schema: table, columns, and the migration script that made them.
4. **Trace the flow.** Walk the layers in order from the screen to the data source, one layer per line and one
   `path:line` per layer. The flow ends where the data really comes from: a table, a stored procedure, or an external
   system. The other side of an external system is `unknown: ask the <system> owner`. Code in another repository is
   `unknown: <endpoint> is in another repository. Give its path to follow it.` If the engineer gives a path, read that
   repository too, read only, and put the repository name before each `path:line` from it.
   - A value or code with no screen, such as a background job or a stored procedure alone, starts at its entry point.
     Use one line `→ screen: none (no screen)`. For a stored value that a screen shows, add one line for the code that
     writes it, after the table line.
   - A hop through dependency injection is plain when you cite its registration or its single implementation. A hop
     through an event or a queue is `inferred:` unless you cite the subscriber's registration. Any hop you cannot
     trace (dependency injection, reflection, an event or a queue) is `inferred:`: name the missing hop.
   - A `status`: find every code path that sets it, the condition for each, and what moves it out. Stop there.
     Which path happened in one case is a diagnosis, not an explanation. When every path does not fit the budget,
     give one line per path and move the conditions to Ask next.
   - A `domain`: map the entities, the statuses, when data is created, and the key formulas. No layer-by-layer flow.
5. **Answer.** Use the shape from `references/answer-template.md`, about one screen long: aim for 60 lines for an answer
   and never go past 70 lines for an answer or a domain overview, each line at most 120 characters. Wrap prose at 120 characters by hand. When
   paths share a long prefix, state the shared prefix once under Core code. Give the facts the engineer needs first
   and move the rest to Ask next. Mark the general meaning of an industry term as `general knowledge`, apart from what
   this project means by it.

## Shapes

- `figure or term`, `status` and `code` use the answer shape. `domain` uses the domain overview shape.
- Brief first. Ask next holds two to four drill-down topics found while tracing; an optional Next line comes after it.
  A follow-up in the same chat goes one level deeper on the topic the engineer picks, in the answer shape.
- A "why" question gets the business reason plus the core code path, not who changed it or when. A reason worked out
  from the code alone is `inferred:`. It is plain fact only when a document or the user guide states it.
- `Next: /agentd-diagnose` only when the question is about a live problem: a user sees something wrong now.
  Otherwise there is no Next line.

## Export

- Only when the engineer asks, after an answer. One file per topic: `docs/onboarding/explain/<topic>.md`, with
  `<topic>` lowercase with hyphens, for example `invoice-discount`. If the folder is missing,
  create `docs/onboarding/explain/` and say so.
- The file merges everything answered in this chat on that topic, follow-ups included, in the export shape from the
  template. Its header records the question, the commit (`git rev-parse HEAD`) and the date.
- If the file exists, ask before replacing it. Yes rewrites the whole file. No skips the export. With nobody to
  answer, skip the export and say so.
- The line limits are for chat only; the export file has none.
- If the customer does not want the file committed, give the engineer the exact line to add to `.git/info/exclude`.
  The skill never edits that file.
- The export is the only write this skill makes.

## Rules

- Read and search only, except the export above. No build, no tests, no app, no database, no `git log`, no
  `git blame`. The git commands are `git rev-parse --show-toplevel` for the root and `git rev-parse HEAD` for the
  export header.
- No sub-agents. One question, one trail.
- Always English, also when the question is in another language.
- Markers: `unknown:` (not found; say who to ask), `inferred:` (worked out, not confirmed; name what is missing: the
  hop, or the document that would confirm it),
  `conflict:` (a document against the code), `general knowledge` (industry meaning, not checked against this project).
  Cite `path:line` for every claim.
- Privacy: name a key, never its value. No personal data from the code, test data or database.
- Write nothing for the customer. Do not start another skill.
