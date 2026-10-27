# Evaluating agentd-verify-init on a .NET and React project

How to check that the skill works, and a summary of the results. There is no synthetic fixture: the check runs the
skill on a local clone of a real .NET plus React project. This file does not name the project and quotes no term, path,
route, label, ticket or value from it. The detailed notes live in the git-ignored plan folder
`PLAN.agentd-verify-init.local`, which only the repository owner has.

## What the real check is

- **Target:** a local clone of a .NET backend with a React frontend and a SQL Server database. The skill ran only on this
  clone, in a throwaway folder. It never ran on the real checkout.
- **Agent:** Copilot only. The engineer chose Copilot as the one tool, so the generated project skill is for Copilot.
- **Steps an agent runs alone:** read the code, write the project skill, start the database in a container, start the
  API and the UI, drive the browser, save the evidence, stop what it started.
- **Steps that need the engineer:** the sign-in. The agent opens the sign-in page and waits. The engineer signs in by
  hand. The agent never sees a password.
- **How a run starts:** a fresh agent follows `SKILL.md` by hand. A fresh agent cannot run `agentd-verify-init` as a
  skill, because the skill carries the manual-only flag.
- **Flag test:** Copilot CLI 1.0.102 cannot load a skill that has the manual-only flag. So the generated project skill
  is written without that flag. The flag stays on `agentd-verify-init` itself.

## Results

| Step | What it checks | Result |
|---|---|---|
| E0 | Skill folder is complete and the structure test passes | pass |
| V1a | Create mode on the clone: questions, feature map, helpers, project skill written | pass |
| V1b | Merged into V1a | merged |
| E1 | Generated skill has the marker header and no manual-only flag; helpers parse | pass |
| E2 | Six questions about the generated skill, answered from its text | pass (6 of 6 answers match) |
| E3 | No literal secret in the generated files | pass |
| E4 | A fresh headless agent, started from `src/`, loads the generated skill and asks for the raw ticket | pass |
| V2 | Database start, DbUp run, reuse of the container, and a changed script that needs a fresh restore | pass |
| V3 | API start with environment variables, port owner check, cleanup, and a foreign listener | pass |
| V4 | Sign-in, Doctor, a wrong role, one feature end to end, evidence kept | pass (engineer signed in) |
| V6a | Update mode with no code change, then with one route changed | pass |
| V6b | Update mode drives every feature once, then promotes the draft | pass for five features; one feature failed on a bug already in the base code |
| V7 | `agentd-dev-rev` step 9 writes the Verify block from a diagnose hand-off | pass |
| V8 | `agentd-pr-prep` drafts a pull request from a pasted verify report | pass |
| V9 | Independence check: a planted wrong fix whose screen, API and database all agreed | pass (the verifier gave `fail`) |

## Defects the run found, and what changed

The helpers the skill generated broke in places the parse check could not see. Each defect led to a rule in the skill
text, `references/` or `templates/`, and each rule has a phrase check in the structure test.

- A variable followed by a question mark in a string read as part of the name. The templates now say to wrap such a name in braces.
- Strict mode failed on keys missing from the state file or the role overrides. The templates now read optional keys safely.
- The operating system held the default API port. The templates and the Gotchas list now say to choose a free port and to check who owns it.
- A query that returns one row came back as a string, not a list. This broke a count and Doctor. The templates now wrap
  query results in an array.
- The fingerprint counted a local-only file and called the database stale. The templates now have a list of local-only files.
- The browser started headless, so the engineer could not sign in. The templates now start it headed, in a named session.
- The sign-in URL, the authorization header and the saved user response held tenant IDs, tokens or a user name. The
  templates now filter them out of output and evidence.
- Smaller fixes: the database helper printed a wrong applied-script count, the evidence folder was not recorded in the
  state file, and the response file name was fixed.

## Not run or not verified

- A bacpac import and its journal check. Only the parse check and the text checks cover it.
- A Claude Code generation run. Only Copilot was used.
- Windows. The run was on macOS with PowerShell.
- Update mode on a real code change beyond one route.
- The cause of two server errors seen at sign-in. They did not stop the run.
- The round 1 and round 2 review changes and the later rulings (Flow order, start sequence, `dbup-run.ps1` on every run, the data-source restore, Doctor saved-response input and a new file after an API restart, `-ConfirmRestore`, the `ui-start.ps1` fix command, the Code folders column) were checked by the structure test only, not by a real run.
- The failed feature in V6b is a product finding, not a skill defect. The skill reported it correctly.

## How to re-run

The structure test needs no project and no browser:

```
tests/verify-init/test-skill-structure.sh
```

The real check needs a clone of a .NET plus React project, a container engine, PowerShell, a Copilot CLI and an
engineer who can sign in. Run the steps in this order: E0, V1a, E1 to E4, V2, V3, V4, V6a, V6b, V7, V8, V9. Each step
builds on the state the one before it left. Run it on a clone in a throwaway folder, never on the real checkout.
