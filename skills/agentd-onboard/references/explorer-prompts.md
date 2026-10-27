# Explorer prompts

Used in Flow step 2. Start one read-only sub-agent for each angle, in parallel. Give each sub-agent its angle prompt, the shared rules and report template, the repository root, and any handover notes the engineer gave. A sub-agent has none of this conversation, so every prompt stands alone. If you cannot start sub-agents, run the six angles one after another and keep each report to the same size. After each angle, keep only its report: drop the files you read from your notes, and do not read a file again that an earlier report already covers. On a large repository (more than about 1,000 tracked files), read the entry points and one example of each pattern, not every file, and list what you skipped under Open Questions.

## Shared rules and report template

Put this block at the top of every explorer prompt.

**Rules**

- You are read-only. Read files, search, and run read-only git commands (`git log`, `git ls-files`, `git grep`). Do not edit anything. Do not run the app, a build, a test, a script, or anything that writes, or reaches a database or a network service.
- Never copy a secret value (passwords, keys, tokens, connection strings). Name the key and its file only.
- Do not read everything. Start at entry points and follow what matters. Trust the code over configuration and documents. When they disagree, report both and mark it `conflict:`.
- Mark every fact: no marker means you read it in the code and cite `path:line`. `inferred:` means you worked it out and could not confirm it. `unknown:` means you looked and did not find it, and says who could answer. `changed:` is only for a refresh and means the fact differs from the existing brief. `conflict:` means two sources disagree.
- Report at most about 600 words, in the template below. Return only the report.

**Report template**

```
### Components
Each component: name, its job in one line, its path.
### Flow
How a request or an event moves through this angle, as numbered steps with path:line.
### Files Read
The paths that support your findings. Not every file you opened.
### Boundaries
Where this code meets other code or systems: HTTP, queues, files, the database.
### Non-obvious
Surprises, patterns worth copying, rules the code enforces, conflicts.
### Open Questions
Each unknown: with who could answer it.
```

## UI and routes

Goal: find out who uses the application and how they move through it.

Look for screens, pages, routes and navigation; forms and what they submit; menus and who sees which one; user-facing text and labels; empty and error states. In .NET look at views, Razor pages, Blazor `@page`, and SPA route tables. In an iOS app look at `View` types, `NavigationStack`, `TabView` and `.sheet`. In a React app look at the router (`<Route>`, `createBrowserRouter`), `pages/` folders, the Next.js `app/` folder (`page.tsx`) and the components they render. Read any user guide or help text for the words users use.

Report: the types of user; the screens each type uses; three to five candidate use cases, each as a short numbered journey of screens and actions. Mark every use case `inferred:` until the engineer confirms it, even when a document states it. Name the document. Name the entry point of each in the code.

## API and permissions

Goal: list what the application exposes and who may call it.

Look for endpoints: route, verb, the handler, and the request and response types. Look for authentication and authorisation: roles, policies, scopes, claims, API keys, and where each is enforced. Look for public contracts others depend on: DTOs, serialised shapes, versioned routes, configuration keys.

Report: a compact table of endpoints with their required role; which endpoints change state; which look called by another system and not by a user; any endpoint with no authorisation.

## Domain model and schema

Goal: describe the data and the business rules held in it.

Look for entities, their relations, enums and status values, and state changes. Look for the schema: scripts, migrations, stored procedures, views, and the naming and ordering rule for a new script. Look for business rules in code, such as calculations, validation and workflow. Collect the domain terms for a glossary.

Report: the main entities and their relations; the rule for changing the schema safely and who applies a change; stored procedures that matter and what calls them; which code reads and writes which table; glossary terms with one-line meanings.

## Data-flow tracer

Goal: follow real requests from the entry point to storage and back, so the brief can show a pattern to copy.

Pick the three to five entry points with the most business weight: endpoints that change state, and background jobs. For each, trace one request through every layer (handler, service, data access, external call), citing `path:line` at each hop. Name the layers and the one pattern that repeats. Note where a hop is hidden behind injection, events or a queue, and mark it `inferred:`.

Report: one numbered flow for each traced entry point; the pattern to copy and an example file; deviations from the pattern; background jobs and what starts them.

## Integrations and dependencies

Goal: find every system outside this repository and what depends on it. Follow `external-systems.md` in this skill's references, in full.

Report: one record for each external system, as that file describes; the endpoints and jobs that do not depend on any external system; important packages and services the application relies on. Name configuration keys only.

## Documentation and tests

Goal: find what the team has written down, what the tests prove, and how work is delivered.

Look for README files, wikis, user guides, architecture notes, contribution rules, code owners, pull request templates and branch naming. Look at pipeline and infrastructure files for build, test, deploy stages, environments, and approvals. Look at the test projects: what they cover, how they are named, how they run, and whether a filter or category matches any test.

Report: documents and what each covers; delivery path from branch to production; the test layout and what it proves; any document that disagrees with the code, marked `conflict:` with both sources; house rules the team states. Do not run the tests.

## Synthesizer

The main agent does this step itself, because it talks to the engineer. If the six reports would not fit in context, give them to one more sub-agent for pass 1 and take back a bounded result.

Inputs: the six reports, the engineer's answers (or none), `brief-template.md`, and the stack reference if one applies.

**Pass 1, before the engineer corrects anything**

1. Merge the reports. Remove duplicates. When two reports contradict each other, read the code and decide. If you cannot decide, keep both with their sources and mark `conflict:`. Do not pick by majority.
2. Check every claim that an endpoint or feature depends on an external system by reading the call chain from the endpoint down to the client. Drop what you cannot show, or mark it `inferred:`.
3. Draft the three to five use cases and a short journey for each. Mark each `inferred:` until the engineer confirms it. Show them to the engineer and ask for corrections.

**Pass 2, after the engineer answers (or does not)**

4. Write `README.md` with `brief-template.md`, with its budgets. Cite `path:line` in each `Sources:` line. Move a section to a side file only when it outgrows its share, and leave a summary and a link.
5. Write `open-questions.md`: every `unknown:` and every `inferred:` use case that nobody confirmed, grouped by who to ask, with why each matters. If the engineer gave no answer about use cases, list them first.
6. Check the eight questions in `SKILL.md`. Each checklist item links to its section or says `unknown:`. Then list the gaps.
7. Never write a secret value. Re-read the output for connection strings, keys and tokens before you finish.
