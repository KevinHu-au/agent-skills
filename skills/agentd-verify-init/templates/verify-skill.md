---
name: verify-<app>
description: Use when the engineer wants an independent check of a ticket's change in the real <app>, after /agentd-dev-rev. It drives the app the way a user does and returns an evidence report.
metadata:
  generated-by: agentd-verify-init
---

<!-- Generator notes. Delete this comment when you write the skill.
Copy this file to the verify skill's folder as SKILL.md. Replace each <app> and each other <placeholder>. Fill `<current-user route>` from the API code. Fill `<admin roles>` from the API code.
Copy everything under `## Report` and `## Results` of `templates/report.md` into the Report section, including the notes and the Order of results.
Optional first body line, written only by the Create flow when the proof run stops (Flow step 7 of the generator):
draft: not proven
Not proven:
- <each step that did not run>
Update mode removes both lines after a proof run passes with the engineer present.
-->

# verify-<app>

Check a ticket's change in the real <app>, as a second check that does not depend on the developer's reasoning. Run it
in a fresh session. The session gets only the feature map, the raw ticket and the Verify block. It starts the app, lets
the engineer sign in, drives the changed feature through the user interface, and writes an evidence report.

## Flow

1. **Read the input.** See Input below. Write down the base branch and the ticket number. If this session made, reviewed or
   staged the change (it holds the diff or the `/agentd-dev-rev` work), stop and ask the engineer to start a fresh
   session.
2. **Write the expectations.** Before it drives, write what should be true. See Expectations.
3. **Start the data and the app.** Run the helpers this skill carries, in this order. Each job has one owner. When a
   helper ends with `blocked:`, stop and report `blocked`, except the two named retries: `-ConfirmRestore` and the
   `ui-start.ps1` fix command.
   - `db-start.ps1`: the state check and the container. When the state check forces a fresh restore, it prints
     `fresh restore needed: <reason>` and, without a terminal, stops. Ask the engineer, then run it again with
     `-ConfirmRestore`. When the engineer asks for fresh data, run it with `-ConfirmRestore` too.
   - `db-restore.ps1`: only when the data is a bacpac and `db-start.ps1` printed `database: new` or
     `database: dropped`.
   - `dbup-run.ps1`: on every run, after `db-start.ps1` and after `db-restore.ps1` when that ran.
   - `api-start.ps1`: with the admin roles (`<admin roles>`) when the `Data:` line names setup recipes that `state.json` `recipes` does
     not list, otherwise with the roles of the `Roles:` line.
   - `ui-start.ps1`. When it stops because a dependency is missing, it prints a fix command. Show it to the engineer,
     run it once, then run `ui-start.ps1` again. After it runs, check `git status --porcelain`: a changed tracked file is
     `blocked`, and you tell the engineer. A second `blocked` ends the run.
4. **Make the evidence folder.** Call `New-EvidenceFolder` from `common.ps1`. It records the path in `state.json` as
   `evidenceFolder`.
5. **Sign in.** The page opens. The engineer signs in with their own account. Never type credentials.
6. **Run Doctor.** Save the response of the API's current-user call (`<current-user route>`) as a saved response in the evidence
   folder, then run `doctor.ps1` with that file and the roles `api-start.ps1` started the API with. The token is never printed or saved. Stop when Doctor fails.
7. **Set up the data.** Run the setup recipes the `Data:` line names that `state.json` `recipes` does not list, as admin
   through the user interface, and record each one in `state.json` `recipes`. Then restart the API with the roles of the
   `Roles:` line when they differ from the roles it runs with. After the restart, reload the page, save a new
   current-user response to a new file in the evidence folder, and run `doctor.ps1` with that file and the roles of the
   `Roles:` line.
8. **Drive.** Follow the `Steps:` line and the feature file named in `Feature:`. Save a screenshot or a saved response
   for each step in the evidence folder.
9. **Check.** Do the three-way match, recompute the figures on a calculation ticket, check the neighbours, and try the
   edges. See the sections below.
10. **Report and clean up.** Write the evidence report. Run `cleanup.ps1`. Check that the evidence folder still exists.

## Input

Two parts. Read both before anything else.

1. **The raw ticket.** The engineer pastes the work item text as it stands. Write expectations from this, never from a
   summary written by the agent that made the fix. With no raw ticket, the skill asks the engineer for the raw ticket
   and does not start.
2. **The Verify block**, written by `/agentd-dev-rev`. It says what changed and how to reach it, not what is right.
   It has no `Expected:` line. The `Change:` line is for navigation only: it tells you which feature to drive.

```
Verify:
Ticket: <number>
Base: <base branch> @ <merge-base sha>
Change: <the user-visible behaviour that changed, 1-2 sentences; navigation only>
Feature: <feature file(s)>; entry points: <which ones>
Neighbours: <features from blast-radius> | none
Data: empty | setup: <recipe names> | bacpac: <what the data must contain> | records: <specific rows to create>
Roles: default | <role list>
Steps: <numbered user actions>
Side effects: <tables or rows to check with a read-only SELECT> | none
Diagnose: <from the diagnose hand-off, verbatim: the Confidence line, the Root cause line, and the reproduction command from the Verification line (not its expected output)> | none
Reference anchors: <calculation reference anchors, as an index only> | none
```

- `Base:` is the commit that Expectations reads with `git show <sha>:<path>`. The skill never guesses `main`, and it
  never guesses any other branch name.
- With `Base: unknown`, or with no block, ask the engineer for the base branch. Then run `git merge-base HEAD <branch>`
  yourself, before you write expectations. With no local branch, run `git merge-base HEAD origin/<branch>`. When that command finds nothing (a shallow clone, a detached HEAD), say so
  and ask again. The skill never guesses.
- With no block, also ask what to check, or run the feature files the engineer names.
- `Verify: none: <reason>` means `/agentd-dev-rev` found no user-visible effect. Say so, and ask the engineer whether
  to check anything.
- Compare your own reading of the raw ticket with the `Change:` line before you drive. If they conflict, the result is
  `disagree` unless a check that does not depend on the reading fails (see the report's Order of results). Still drive,
  against your own reading, and report both readings.

## Expectations

Write each expected result before it drives, and write its source next to it. Sources, in this order:

- **Behaviour the ticket changes:** the raw ticket, plus the diagnose root cause (the mechanism, `path:line`) when its
  confidence is `confirmed`. Never use the expected output from the diagnose hand-off: it was written by the fixing
  side, so it is not the expected output you may trust. The diagnose reproduction command steers what to drive, not
  what is right.
- **Behaviour the ticket does not change:** the code on the base branch, read with `git show <base>:<path>`, so the fix
  cannot confirm itself.
- **A calculation reference** (`Reference anchors:`) is an index, never the oracle. It was written from the code and
  may be out of date. Use it to find the right code. When it disagrees with the base-branch code, write a `conflict:`
  line for that anchor under Reference conflicts. That is a documentation finding, not a fail. Its warning notes are
  claims too and get the same check.
- Expectations never come from the diff or from the branch's new code.
- An unclear ticket: ask the engineer.

## Three-way match

For each checked value, compare the screen, the API response and the database. Take the API response from the
browser's network log.

- A stored value: the stored row, by read-only SELECT.
- A derived value, computed at read time by a function or procedure: that function's result by SELECT, or the
  procedure's result when the feature file marks it read-only. Otherwise the database leg is the recomputed figure from
  the next section.
- Formatting: round the API and database values to the precision and units the screen shows, then compare. The display
  rule comes from the base-branch UI formatting code. A difference within display rounding is a match. The report
  shows the raw values.

## Recompute the figures

Calculation tickets only. Recompute the expected figure from raw input rows, by SELECT, and compare it with the
screen. The formula comes from the base-branch code for the parts the ticket does not change, and from the ticket for
the part it changes. It does not come from the calculation reference.

## Neighbours and edges

- **Neighbours.** After the ticket's journey, make a short pass over the features named in `Neighbours:`. With
  `none`, use the features in the map.
- **Edges.** Try cases the ticket did not ask for, when the change touches them: another role, a record the user is
  not a member of, a locked period, empty data, the first and last period.
- A neighbour or edge failure is tagged "outside the ticket; may be pre-existing, not checked on the base".
- A neighbour or edge you did not try goes in Not verified. It does not block a `pass`.

## Doctor

Run `doctor.ps1` after sign-in, and again after any API restart, before every drive. The app may have no health
endpoint, so Doctor checks the ports, the signed-in API user, the role set, the container and the database target.

- It reads the signed-in user and roles from the saved response file in the evidence folder. It never asks for, prints
  or saves the token. It never prints a name or an email. After an API restart, give it a new saved response file.
- It reports the database the running process uses, not what a settings file says.
- It compares the role set the API reports with the wanted set exactly. An extra or missing role is `blocked`.
- Before an authorisation feature, it checks that the authorisation switch has not turned authorisation off. It also
  checks that the UI sign-in values are not placeholders.
- It refuses to drive an API or UI that this run did not start. It names the process that holds the port.
- Doctor fails with `did not start` when a port does not answer after the helper's wait.

## Evidence

- Evidence goes to `~/.<app>-verify/<ticket>/<timestamp>/`, outside every repository.
- It is never committed. Screenshots may show test-environment data.
- Cleanup never removes it. `cleanup.ps1` stops the processes this run started and nothing else.
- Data is made in this order: an empty schema plus a setup run through the UI as admin; SQL inserts only when the UI
  cannot reach the state in reasonable time, each approved by the engineer and marked "made by SQL, not through the
  app"; a test-environment bacpac only when the ticket needs specific data.

## Browser and session

- Drive the browser with `chrome-devtools-axi`, started through `npx`. Take a fresh page snapshot after each action.
- Start the browser tool headed, with a named session per ticket, using the tool's environment variables, on every
  call. It is headless by default, and then the engineer has no window to sign in.
- Start the browser tool's background process from the repository root. It uploads files only from under the folder it
  started in.
- Sign-in wait: poll every 5 seconds, up to 600 seconds, until the page host is the app host, is not the identity
  provider host, and a known app element is visible. The probe prints only true or false, never the URL. The engineer
  is only asked to sign in, not to say when they are done.
- The browser tool has no double-click command. Send the mouse events (mousedown, mouseup, click twice, dblclick) with
  an evaluate call.
- Element references are stale after every action. Take a new snapshot before each click.
- A saved response file always gets a `.network-response` suffix, whatever name is given. Copy it to the name this skill
  uses.
- Privacy: the browser tool's open output prints the full authorize URL (tenant and client IDs), its network output
  prints the Authorization header, and a saved response can hold the signed-in person's name. Filter these from tool
  output before it reaches notes or the report. Never paste a response body that holds a person's name. Evidence files
  are the only place such data may be saved, outside every repository.
- Run this skill in a fresh session. The session gets only the feature map, the raw ticket and the Verify block.
- This skill is not a task agent by default. A skill that cannot be auto-loaded cannot be preloaded into a sub-agent.
- Never type credentials. Never read, print or change user secrets or any connection string.

## Report

Write the evidence report in the shape below, then give the result. Copy everything under `## Report` and `## Results`
of `templates/report.md` of the generator when you write this skill, including the notes and the Order of results.

<paste everything under `## Report` and `## Results` here>

## Gotchas

- Fill this list from what the proof run showed. Keep `unknown:` and `inferred:` on what no run has checked. After a
  passing proof run, replace each of them that the run confirmed or refuted with the result. Examples: the browser profile keeps or loses the sign-in between runs;
  a port is fixed; on Apple Silicon, turn on Rosetta in Docker Desktop and pull the `linux/amd64` image.
- Launch profile ports: a port in the project's launch profile may be held by the operating system (macOS holds port
  5000 for AirPlay Receiver). Pass `--urls` for `https://localhost:<port>` only, when the UI calls only the secure
  port. Do not require `http://localhost:<port>`. Doctor and the start helper name the process that holds a port.
- Local-only files: an edit to a local-only file (`<local-only file>`) never forces a restore. A branch script that
  changed or was removed, or an app-code change outside the scripts folder, this skill's folder and the local-only
  files, forces a restore. A new branch script is applied by DbUp without a restore.
- The header has no `disable-model-invocation` line. Copilot cannot load a skill that has the flag (checked with
  Copilot 1.0.102). The engineer may add it back when Copilot supports it, to keep the skill out of the auto-loaded
  context.
- The `metadata` marker is nested, with two spaces, so `/agentd-dev-rev` and update mode can find this skill.
