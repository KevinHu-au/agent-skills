<!--
Project contract, version 1.

agentd-onboard writes this section to contract.md in the onboarding pack. A project may also keep it in its own
AGENTS.md; the skills read that copy first. General agent skills read the project's facts from these exact headings.
Do not rename them.

Rules for filling it in:
- Cite a source for each fact: `path/to/file:line`, a URL, or "told by <role>".
- Write `unknown: ask <role or name>` when you cannot find a fact. Never guess.
- Write `inferred:` before a fact you worked out but could not confirm.
- When two sources disagree, write both with their sources and mark it `conflict:`. Do not pick one
  silently. Prefer the source closest to the running code (a project file beats a README).
- Never write secrets. Write where they are kept, for example "LastPass folder X".
- An access rule under Data access needs "told by <role>" or a document as its source. Never write it as `inferred:`.
  Skills treat a rule without a source as no access.
- Keep each answer short. Link to longer documents instead of copying them.
-->

## Project contract

### Commands

Run from: `<directory>`

- **Prerequisites:** `<runtime versions, tools, Docker, VPN, licences>`
- **Build:** `<command>`
- **Unit tests:** `<command>`
- **Integration tests:** `<command>` (needs: `<Docker, database, services>`)
- **Run one test:** `<command with a filter>`
- **Lint and format:** `<commands>`
- **Run locally:** `<commands for each part: API, UI, database>`
- **Count check:** how to confirm tests really ran. Give the expected count, and any filter that
  matches zero tests but still exits 0.
- **Known failing on a clean main:** `<command: what fails and why>`

### Verify

- **Start the app:** `<steps>`
- **Sign in:** `<how a local user gets in and gets roles, without secrets>`
- **Test data:** `<how to load it, where the files are>`
- **Key flows to drive** (three to five; one row each):

  | Flow | Start at | Expected result |
  |---|---|---|
  | `<name>` | `<screen or URL>` | `<what you see>` |

- **Automated checks of the running app:** `<UI or API test commands, or "none">`

### Data access

| Environment | URL | Database | Access rule | Who approves access |
|---|---|---|---|---|
| `<Dev>` | `<url>` | `<server / name>` | `<read-write / read-only / none>` | `<role>` |

- **Network:** `<VPN, firewall rules, IP allow list>`
- **Query safely:** `<read-only login, tool, how to avoid locks>`
- **Never do:** `<for example: writes to Prod, running a reset against a shared database>`
- **Schema changes:** `<where scripts live, naming, which scripts run once (never edited after they are applied) and which re-run on every deploy (edited in place)>`
- **Sensitive data:** `<personal or financial data, masking rules>`

### Risk areas

- **Public contracts:** `<HTTP API, DTOs, serialized shapes, config keys: who depends on them>`
- **Database:** `<schema, stored procedures, migrations>`
- **Authorisation:** `<where it is enforced, and the rule that it must not move>`
- **Generated files:** `<file and the exact command that regenerates it>`
- **Business-critical calculations:** `<where the rules are documented and tested>`
- **Never commit:** `<files that hold secrets or local settings>`

### External systems and owners

One row per system outside this repository that the application calls or that calls the application
(for example a message broker, an integration platform, an identity provider, a payment service).

| System | Direction | Our endpoints and services that depend on it | Features that depend on it | Owner | Test environment |
|---|---|---|---|---|---|
| `<name>` | `<outbound / inbound / both>` | `<controller routes, services, jobs>` | `<features or use cases that fail without it>` | `<team or person>` | `<where it can be tested, or "none">` |

- **Failure behaviour:** `<timeouts, retries, queues, what the user sees when the system is down>`
- **Other side of the boundary:** the logic inside the external system is not in this repository.
  Write `unknown: ask <owner>` for anything you cannot read here.
