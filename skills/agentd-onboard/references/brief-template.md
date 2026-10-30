# <Project name> onboarding brief

> Template for `docs/onboarding/README.md`. Keep the header lines, the headings and their order exactly. A refresh and the checks depend on them. Replace every `<...>`. Delete every guidance line that starts with `>`. Aim for about 2,000 words in total (about four pages, 500 words a page). Keep the whole pack under about 5,000 words, not counting `open-questions.md`.
>
> Markers: `unknown:` not found, and who to ask. `inferred:` worked out, not confirmed. `changed:` updated in the last refresh. `conflict:` two sources disagree, and the code wins. Cite sources as `path:line`. Never write a secret value. Name the key only.
>
> Run from the repository root, the working tree is `dirty` when `git status --porcelain -- . ':(exclude)docs/onboarding'` prints anything. The pack itself never counts. Build output from safe checks does not count. If it is dirty, list the changed files in `Unknowns`. Write any other commit id in 7 to 12 characters. Only the `Scanned commit:` line holds a full hash.

Scanned commit: <the full output of git rev-parse HEAD>
Scanned on: <YYYY-MM-DD>
Working tree: <clean or dirty>

## First-ticket checklist

> Nine items, numbered 1 to 9. Budget: about 140 words. Each links to the section that answers it, or says `unknown:` and who to ask. Keep the item text as written. When an answer is partial, add a short `unknown:` note after the link.

1. What the app is for and who uses it: [Purpose and users](#purpose-and-users)
2. The three to five main use cases and where they are in the code: [Use cases](#use-cases)
3. How to run it, sign in, load test data and check a change: [Run and verify](#run-and-verify)
4. The pattern to copy and the house rules: [Architecture and patterns](#architecture-and-patterns)
5. The main data entities and how to change the schema safely: [Data model](#data-model)
6. The external systems, and which endpoints and features break if one fails: [External systems](#external-systems)
7. What never to do or commit: [Risks and delivery](#risks-and-delivery)
8. How a finished ticket is delivered, and who to ask: [Risks and delivery](#risks-and-delivery)
9. Where a feature's code is in each layer, and how to search for the rest: [Start here](#start-here)

## Purpose and users

> Budget: about 200 words. What the application is for, in two or three sentences. Each type of user: what they do and roughly how many. The domain words a new engineer will meet, in a short glossary. Move a long glossary to `glossary.md` and keep a summary here, so this section stays short.

<text>

Sources: <path:line, path:line>

## Use cases

> Budget: about 250 words. The three to five main use cases. For each one: who, the goal, the journey in numbered steps, and one line saying where it starts in the code (`path:line`). The full layer rows are in `feature-to-code.md`. At most one small Mermaid block. Put long journeys in `use-cases.md` and keep a one-line summary here. Mark a use case nobody confirmed with `inferred:`.

<text>

Sources: <path:line, path:line>

## Start here

> Budget: about 300 words, including the diagram. Three parts, in this order. Nothing here is specific to one stack.
>
> 1. Key concept: one short paragraph and one small Mermaid block (a lifecycle, a state machine, a sync flow, a data pipeline or an entity diagram) for the one idea that most main use cases pass through. Use exactly one ```mermaid block. When no concept stands out, write one line instead: `Key concept: unknown:` and who to ask. Mark a concept nobody confirmed with `inferred:`.
> 2. Layers: one short block for each layer the project has, in request order. Each block has three lines, `Open:` the first files, `Run:` the first command (or `unknown:`), and `Pattern:` one example file to copy. Backtick only paths on `Open:` and `Pattern:` lines and in the path columns; write any note without backticks. The path columns are every column after the first (Layer) in the use case tables of `feature-to-code.md`. A `Run:` line holds a command, never checked as a path.
> 3. Find the code for a feature: the four steps below, then the link and the `Sources:` line. The `Sources:` line lists every path the block cites.

Key concept: <one short paragraph: the idea, and why it matters for a change>

```mermaid
flowchart LR
  A[<state or step>] --> B[<state or step>] --> C[<state or step>]
```

### <Layer name>

Open: `<path>`, `<path>`
Run: `<command>`
Pattern: `<path>`

Find the code for a feature:

1. Take the business words from the request.
2. Look the words up in [feature-to-code.md](feature-to-code.md), or in the glossary.
3. Search for the code name in each layer, in order.
4. In each layer, read where the data loads and where the calculation sits.

When a word is not in the map, search the UI label first, then the field name it binds to. Example (made up): the label `Shipping date` binds to the field `shp_dt`.

Sources: <path:line, path:line>

## Architecture and patterns

> Budget: about 200 words. The shape of the application: projects or layers, and how a request moves through them. The pattern to copy for each layer is in Start here, so do not repeat it. The house rules the code follows or the team states. Mark a conflict between the code and a document with `conflict:`.

<text>

Sources: <path:line, path:line>

## Data model

> Budget: about 225 words. The main entities and how they relate. Where the schema lives and how to change it safely: script naming, who applies it, which scripts run once (never edited after they are applied) and which re-run on every deploy (edited in place). The stored procedures that matter. The environments and their access rules (read-only or not), or `unknown:` and who to ask. Move long detail to `data-model.md`.

<text>

Sources: <path:line, path:line>

## External systems

> Budget: about 225 words. One short entry per external system: direction, the endpoints, services and jobs that depend on it, the features that fail without it, the owner, and where it can be tested. Say which endpoints do not depend on it. Method and limits are in `external-systems.md` in the skill's references. Move long detail to `integrations.md`.

<text>

Sources: <path:line, path:line>

## Run and verify

> Budget: about 200 words. How to build, run, sign in, load test data and check a change. Put the commands here in full, each with its source (a project file, the README or the pipeline). Do not write them to `AGENTS.md`. Mark a command you did not run `inferred:`.

<text>

Sources: <path:line, path:line>

## Risks and delivery

> Budget: about 175 words. The standing rules only: what never to do or commit, run-once scripts, generated files, where authorisation lives. A finding (a committed secret) goes in Unknowns, not here. Name the rule it breaks, with a link to Unknowns. One paragraph on delivery: branch to production, where tickets come from, who to ask. Read the pipeline files first.

<text>

Sources: <path:line, path:line>

## Unknowns

> Budget: about 150 words. Every `unknown:` and `inferred:` item from this brief, grouped by who to ask, with one line on why it matters. This summarises `open-questions.md`. It holds findings as well as gaps. A gap listed here is a pass. A gap left out is a failure. This section has no `Sources:` line.

- <who to ask>: <the question, and why it matters>
