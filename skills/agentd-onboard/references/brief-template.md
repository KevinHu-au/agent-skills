# <Project name> onboarding brief

> Template for `docs/onboarding/README.md`. Keep the header lines, the headings and their order exactly. A refresh and the checks depend on them. Replace every `<...>`. Delete every guidance line that starts with `>`. Aim for about 2,000 words in total (about four pages, 500 words a page).
>
> Markers: `unknown:` not found, and who to ask. `inferred:` worked out, not confirmed. `changed:` updated in the last refresh. `conflict:` two sources disagree, and the code wins. Cite sources as `path:line`. Never write a secret value. Name the key only.
>
> Run from the repository root, the working tree is `dirty` when `git status --porcelain -- . ':(exclude)docs/onboarding'` prints anything. The pack itself never counts. A change to `AGENTS.md` inside its `## Project contract` section and build output from safe checks do not count. If it is dirty, list the changed files in `Unknowns`. Write any other commit id in 7 to 12 characters. Only the `Scanned commit:` line holds a full hash.

Scanned commit: <the full output of git rev-parse HEAD>
Scanned on: <YYYY-MM-DD>
Working tree: <clean or dirty>

## First-ticket checklist

> Eight items, numbered 1 to 8. Each links to the section that answers it, or says `unknown:` and who to ask. Keep the item text as written. When an answer is partial, add a short `unknown:` note after the link.

1. What the app is for and who uses it: [Purpose and users](#purpose-and-users)
2. The three to five main use cases and where they are in the code: [Use cases](#use-cases)
3. How to run it, sign in, load test data and check a change: [Run and verify](#run-and-verify)
4. The pattern to copy and the house rules: [Architecture and patterns](#architecture-and-patterns)
5. The main data entities and how to change the schema safely: [Data model](#data-model)
6. The external systems, and which endpoints and features break if one fails: [External systems](#external-systems)
7. What never to do or commit: [Risks and delivery](#risks-and-delivery)
8. How a finished ticket is delivered, and who to ask: [Risks and delivery](#risks-and-delivery)

## Purpose and users

> Budget: 0.5 page, about 250 words. What the application is for, in two or three sentences. Each type of user: what they do and roughly how many. The domain words a new engineer will meet, in a short glossary. Move a long glossary to `glossary.md` and keep a summary here.

<text>

Sources: <path:line, path:line>

## Use cases

> Budget: 0.75 page, about 375 words. The three to five main use cases. For each one: who, the goal, the journey in numbered steps, and where it starts in the code (`path:line`). At most one small Mermaid block. Put long journeys in `use-cases.md` and keep a one-line summary here. Mark a use case nobody confirmed with `inferred:`.

<text>

Sources: <path:line, path:line>

## Architecture and patterns

> Budget: 0.75 page, about 375 words. The shape of the application: projects or layers, and how a request moves through them. The one pattern to copy when adding a feature, with an example file. The house rules the code follows or the team states. Mark a conflict between the code and a document with `conflict:`.

<text>

Sources: <path:line, path:line>

## Data model

> Budget: 0.5 page, about 250 words. The main entities and how they relate. Where the schema lives and how to change it safely: script naming, who applies it, which scripts run once (never edited after they are applied) and which re-run on every deploy (edited in place). The stored procedures that matter. The environments and their access rules (read-only or not), or `unknown:` and who to ask. Move long detail to `data-model.md`.

<text>

Sources: <path:line, path:line>

## External systems

> Budget: 0.5 page, about 250 words. One short entry per external system: direction, the endpoints, services and jobs that depend on it, the features that fail without it, the owner, and where it can be tested. Say which endpoints do not depend on it. Method and limits are in `external-systems.md` in the skill's references. Move long detail to `integrations.md`.

<text>

Sources: <path:line, path:line>

## Run and verify

> Budget: 0.5 page, about 250 words. How to build, run, sign in, load test data and check a change. The commands live in the project contract in `AGENTS.md`. Summarise them here and say where they are. If the project contract was not written, put the commands here in full. Mark a command you did not run `inferred:`.

<text>

Sources: <path:line, path:line>

## Risks and delivery

> Budget: 0.5 page, about 250 words. What never to do or commit. The risk areas: contracts, schema, authorisation, generated files. One short paragraph on delivery: how a finished ticket gets from a branch to production (stages, environments, approvals), where tickets come from, and who to ask. Read the pipeline files first, then ask the engineer.

<text>

Sources: <path:line, path:line>

## Unknowns

> Every `unknown:` and `inferred:` item from this brief, grouped by who to ask, with one line on why it matters. This summarises `open-questions.md`. A gap listed here is a pass. A gap left out is a failure. This section has no `Sources:` line.

- <who to ask>: <the question, and why it matters>
