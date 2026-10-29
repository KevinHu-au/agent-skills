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

Put every field that an angle's "Also report" paragraph asks for under `### Flow`, as labelled lines after the numbered steps. Do not add headings, and keep to the word limit above.

## UI and routes

Goal: find out who uses the application and how they move through it.

Look for screens, pages, routes and navigation; forms and what they submit; menus and who sees which one; user-facing text and labels; empty and error states. In .NET look at views, Razor pages, Blazor `@page`, and SPA route tables. In an iOS app look at `View` types, `NavigationStack`, `TabView` and `.sheet`. In a React app look at the router (`<Route>`, `createBrowserRouter`), `pages/` folders, the Next.js `app/` folder (`page.tsx`) and the components they render. Read any user guide or help text for the words users use.

Report: the types of user; the screens each type uses; three to five candidate use cases, each as a short numbered journey of screens and actions. Mark every use case `inferred:` until the engineer confirms it, even when a document states it. Name the document. Name the entry point of each in the code.

Also report, for each candidate use case: the screen, route or trigger; the UI file; where its state lives; where it loads data (the client call); and any calculation done in the client. Give a Label-to-field list for the values on those screens, as screen label to field name (for example `Shipping date` to `shp_dt`). Say whether a UI layer exists at all. This angle may report up to about 800 words.

## API and permissions

Goal: list what the application exposes and who may call it.

Look for endpoints: route, verb, the handler, and the request and response types. Look for authentication and authorisation: roles, policies, scopes, claims, API keys, and where each is enforced. Look for public contracts others depend on: DTOs, serialised shapes, versioned routes, configuration keys.

Report: a compact table of endpoints with their required role; which endpoints change state; which look called by another system and not by a user; any endpoint with no authorisation.

Also report, for each endpoint a use case calls: the handler, and where its business rules and calculations sit. List the response field names that differ from the UI names.

## Domain model and schema

Goal: describe the data and the business rules held in it.

Look for entities, their relations, enums and status values, and state changes. Look for the schema: scripts, migrations, stored procedures, views, and the naming and ordering rule for a new script. Look for business rules in code, such as calculations, validation and workflow. Collect the domain terms for a glossary.

Report: the main entities and their relations; the rule for changing the schema safely and who applies a change; stored procedures that matter and what calls them; which code reads and writes which table; glossary terms with one-line meanings.

Also report, for each use case: the Load points, meaning the procedures, queries or local-store reads that load its data, including nested calls one level down; and the Calculation points, meaning where the calculation sits in them. List procedures with no caller found. Give one Key concept candidate (the one idea most use cases pass through) with one line on why. This angle may report up to about 800 words.

## Data-flow tracer

Goal: follow real requests from the entry point to storage and back, so the brief can show a pattern to copy.

Pick the three to five entry points with the most business weight: endpoints that change state, and background jobs. For each, trace one request through every layer (handler, service, data access, external call), citing `path:line` at each hop. Name the layers and the one pattern that repeats. Note where a hop is hidden behind injection, events or a queue, and mark it `inferred:`.

Report: one numbered flow for each traced entry point; the pattern to copy and an example file; deviations from the pattern; background jobs and what starts them.

Also report the Layer chain, named as the project names its layers (this is how the skill finds the layers). For each traced entry point, give the Load points and the Calculation points at each hop. Give one Key concept candidate with one line on why. This angle may report up to about 800 words.

## Integrations and dependencies

Goal: find every system outside this repository and what depends on it. Follow `external-systems.md` in this skill's references, in full.

Report: one record for each external system, as that file describes; the endpoints and jobs that do not depend on any external system; important packages and services the application relies on. Name configuration keys only.

## Documentation and tests

Goal: find what the team has written down, what the tests prove, and how work is delivered.

Look for README files, wikis, user guides, architecture notes, contribution rules, code owners, pull request templates and branch naming. Look at pipeline and infrastructure files for build, test, deploy stages, environments, and approvals. Look at the test projects: what they cover, how they are named, how they run, and whether a filter or category matches any test.

Report: documents and what each covers; delivery path from branch to production; the test layout and what it proves; any document that disagrees with the code, marked `conflict:` with both sources; house rules the team states. Do not run the tests.

Also report each documented calculation or business rule, with the code that computes it if found, and which calculations have a test.

## Synthesizer

The main agent does this step itself, because it talks to the engineer. If the six reports would not fit in context, give them to one more sub-agent for pass 1 and take back a bounded result.

Inputs: the six reports, the engineer's answers (or none), `brief-template.md`, `feature-to-code-template.md`, and the stack reference if one applies.

**Pass 1, before the engineer corrects anything**

1. Merge the reports. Remove duplicates. When two reports contradict each other, read the code and decide. If you cannot decide, keep both with their sources and mark `conflict:`. Do not pick by majority.
2. Check every claim that an endpoint or feature depends on an external system by reading the call chain from the endpoint down to the client. Drop what you cannot show, or mark it `inferred:`.
3. Draft the three to five use cases and a short journey for each. Mark each `inferred:` until the engineer confirms it.
   - 3a. Layers. A layer exists when at least one report cites a file in it. Use the Data-flow tracer's names. Never invent a layer the reports do not show.
   - 3b. Feature rows. For each drafted use case, merge the Load points and Calculation points from the UI and routes, API and permissions, Domain model and schema, and Data-flow tracer reports. When two reports name a different point, read the code and decide. If one value is calculated in more than one layer, say which layer owns it.
   - 3c. Key concept. Pick the Key concept candidate that most main use cases pass through. On a tie, show both candidates with the use-case drafts in Flow step 3 and ask. With no answer, keep the first and mark it `inferred:`. Then show the layers from 3a with the drafts and the key concept to the engineer, and ask for corrections.

**Pass 2, after the engineer answers (or does not)**

4. Run the path and search-term check on the merged rows, then write `feature-to-code.md`. Write `README.md` with `brief-template.md`, with its budgets. Cite `path:line` in each `Sources:` line. Move a section to a side file only when it outgrows its share, and leave a summary and a link.
5. Write `open-questions.md`: every `unknown:` and every `inferred:` use case that nobody confirmed, grouped by who to ask, with why each matters. Findings go to `open-questions.md` and Unknowns, not to Risks and delivery. If the engineer gave no answer about use cases, list them first.
6. Check the nine questions in `SKILL.md`. Each checklist item links to its section or says `unknown:`. Then list the gaps.
7. Never write a secret value. Re-read the output for connection strings, keys and tokens before you finish.
