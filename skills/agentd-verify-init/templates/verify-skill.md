---
name: verify-<app>
description: Use when the engineer wants an independent check of a ticket's change in the real <app>, after /agentd-dev-rev. It drives the app the way a user does and returns an evidence report.
metadata:
  generated-by: agentd-verify-init
---

<!-- Generator notes. Delete this comment when you write the skill.
Copy this file to the verify skill's folder as SKILL.md. Replace each <app> and each other <placeholder>. Fill `<current-user route>` from the API code. Fill `<admin roles>` from the API code.
For Flow step 11, fill these from the code: `<skill folders>` with every folder inside the repository that holds a copy of this skill; `<user guide folder>` with the folder of the user documents found in Flow step 3 of the generator; `<shared folders>` with the folders whose code many screens use (shared components, hooks, the API client and its generated models) and the dependency files (the package manifest and its lock file, the project files); `<test file patterns>` with the project's test file names (for example `*.test.ts`). With no copy of the skill inside the repository (files policy `none`), delete each `:(exclude)<skill folders>` pathspec: git refuses a path outside the repository. With no user guide folder, delete each `:(exclude)<user guide folder>` pathspec, the two user guide commands of step 11, the user guide entry at the end of step 11, and the user guide bullet of the claims in Expectations.
Copy everything under `## Report` and `## Results` of `templates/report.md` into the Report section, including the notes and the Order of results.
For an iOS app, replace the `Browser and session` section with a `Driver` section built from the `Driver`, `Sign-in` and `Evidence and privacy` sections of `references/ios.md`, and use the Doctor of that file in place of the saved-response steps. Also drop the steps for helpers that the app does not have (`db-start`, `db-restore`, `dbup-run` and `api-start`), unless the engineer says the run needs a local API. This includes the restore line and the API restart in Flow step 11: keep only the helpers the app has. Write every helper name with the extension of the language that Flow step 5 of the generator picked.
Optional first body line, written only by the Create flow when the proof run stops (Flow step 7 of the generator):
draft: not proven
Not proven:
- <each step that did not run>
Update mode removes both lines after a proof run passes with the engineer present.
-->

# verify-<app>

Check a ticket's change in the real <app>, as a second check that does not depend on the developer's reasoning. Run it
in a fresh session. The session gets only the feature map, the raw ticket and the Verify block. Later it may also read
two more inputs, and only as named. The first is the change's claims, which it shows to the engineer (see
Expectations). The second is the changed file names (Flow step 11). It starts the app, lets the engineer sign in,
drives the changed feature through the user interface, and writes an evidence report.

## Flow

1. **Read the input.** See Input below. Write down the base branch and the ticket number. If this session made, reviewed or
   staged the change (it holds the diff or the `/agentd-dev-rev` work), stop and ask the engineer to start a fresh
   session.
2. **Choose the features.** Read `features/README.md`. Ask the engineer which features to verify: one or more. Show
   every feature in the table by name with its "Why it is here" text. Mark each row whose File column says
   `none yet` as "index only: no feature file", and ask about those rows in one numbered list after the others. On
   the `Feature:` and `Neighbours:` lines, ` (index only)` after a name is a mark, not part of the name. Mark the features named on the Verify block's
   `Feature:` line as the suggested choice, and still ask the engineer to confirm or change it. Use a multi-select
   question when the tool has one (four options at most per question, so ask in several questions), otherwise a
   numbered list. With no Verify block, ask the engineer to pick from the table. Write the chosen list down: every
   later step runs for each chosen feature. Do not add a feature the engineer did not pick. A feature the engineer
   leaves out but the ticket touches gets no expectations. It goes in Not verified as "left out by the engineer in
   step 2", and it does not block a `pass`.
3. **Write the expectations.** Before it drives, write what should be true, for the features chosen in step 2 only.
   See Expectations.
4. **Start the data and the app.** Run the helpers this skill carries, in this order. Each job has one owner. When a
   helper ends with `blocked:`, stop and report `blocked`, except the two named retries: `-ConfirmRestore` and the
   `ui-start.ps1` fix command.
   - `db-start.ps1`: the state check and the container. When the state check forces a fresh restore, it prints
     `fresh restore needed: <reason>` and, without a terminal, stops. Ask the engineer, then run it again with
     `-ConfirmRestore`. When the engineer asks for fresh data, run it with `-ConfirmRestore` too.
   - `db-restore.ps1`: only when the data is a bacpac and `db-start.ps1` printed `database: new` or
     `database: dropped`.
   - `dbup-run.ps1`: on every run, after `db-start.ps1` and after `db-restore.ps1` when that ran.
   - `api-start.ps1`: with the admin roles (`<admin roles>`) when any setup recipe is still pending, otherwise with the
     roles of the `Roles:` line. A recipe is pending when the `Data:` line names it, or the `Needs:` line of a feature
     file chosen in step 2 names it, or a pending recipe builds on it, and `state.json` `recipes` does not list it. A
     recipe builds on the recipe that its own `Needs:` line in `features/data-setup.md` names. `empty schema` there is
     not a recipe. With `Data: empty` or a database backup on the `Data:` line, ask the engineer before a `Needs:`
     recipe becomes pending, and say what the drive lacks without it. A recipe the engineer declines is not pending.
     A chosen index-only feature has no `Needs:` line and no role rules: ask the engineer which recipes and which
     roles it needs.
   - `ui-start.ps1`. When it stops because a dependency is missing, it prints a fix command. Show it to the engineer,
     run it once, then run `ui-start.ps1` again. After it runs, check `git status --porcelain`: a changed tracked file is
     `blocked`, and you tell the engineer. A second `blocked` ends the run.
5. **Make the evidence folder.** Call `New-EvidenceFolder` from `common.ps1`. It records the path in `state.json` as
   `evidenceFolder`.
6. **Sign in.** The page opens. The engineer signs in with their own account. Never type credentials.
7. **Run Doctor.** Save the response of the API's current-user call (`<current-user route>`) as a saved response in the evidence
   folder, then run `doctor.ps1` with that file and the roles `api-start.ps1` started the API with. The token is never printed or saved. Stop when Doctor fails.
8. **Set up the data.** Run the pending recipes (see step 4) in dependency order: a recipe runs after the recipe it
   builds on. A recipe's `Order:` line in `features/data-setup.md` names recipes it must follow when they also run; it
   does not make them pending. Run each one as admin through the user interface, and record each one in `state.json` `recipes`. Then restart the API with the roles of the
   `Roles:` line when they differ from the roles it runs with. After the restart, reload the page, save a new
   current-user response to a new file in the evidence folder, and run `doctor.ps1` with that file and the roles of the
   `Roles:` line.
9. **Drive.** Each chosen feature keeps the rules of its feature file (roles, data and gotchas).
   - Follow the `Steps:` line in its own order. A step that only reaches a screen (for example opening the entry
     feature and picking the record) always runs. So does a step that only sets up what a later step needs (for
     example giving a user access to the record), even when its feature was not chosen: this wins over the skip rule
     below. Follow its feature file when it has one, and mark it `inferred:` when it has none. So does a step on a
     screen that has no row in `features/README.md`: drive it from the labels on screen and mark it `inferred:`. Skip a step that acts on a feature the engineer did not choose in step
     2, and every later step that needs what it makes (data or a screen state). List each skipped step in Not verified.
   - A chosen feature is covered when a `Steps:` step acts on it (an edit, a click on its controls or a value check).
     Drive each chosen feature that is not covered from its feature file, one at a time, in the order of the table in
     `features/README.md`. A chosen index-only feature has no file: start from the entry feature (pick the record),
     then go to its Route or screen, drive it from the labels on screen, and mark each step `inferred:`. In the
     report, label its steps "index only: no feature file", and suggest `/agentd-verify-init` (update mode) to write
     its file. It is driven, so it does not go in Not verified. When its screen refuses the user (a not-authorised
     page) or stays disabled, it was not driven: list it in Not verified with the reason.
   - Work that locks a period, or closes or deletes a record other features need, goes last. When a `Steps:` step
     locks, closes or deletes, the whole `Steps:` line goes last, in its own order. The neighbours pass and the edges
     (step 10) run before it too, so they still find the data open.
   - After such a lock, close or delete, clear `state.json` `recipes`, so a later run on this container sets the data
     up again.
   - Label each step in the report with its feature. Save a screenshot or a saved response for each step in the evidence folder.
10. **Check.** Do the three-way match, recompute the figures on a calculation ticket, check the neighbours, and try the
   edges. See the sections below.
11. **Check coverage, and offer to continue.** Do this before the report and before cleanup, while the app still runs.
    - Skip this step when the run stopped before it (a `blocked:` stop or a failed Doctor). Write
      `Coverage: not checked: run stopped at Flow step <n>` in the report instead.
    - List the changed file names. Never open the files. Run the commands from the repository root, in the branch's
      working tree, never in a checkout of the base commit. Leave out this skill's folders inside the repository and
      each file in the `LocalOnlyFiles` list of `common.ps1`: one `':(exclude)<file>'` per file inside the repository,
      and none for a file outside it. Never write an empty `':(exclude)'`: git then lists nothing. Keep each pathspec
      in single quotes, so the shell does not expand it.

      ```
      git diff --name-only --no-renames <merge-base sha> -- . ':(exclude)<skill folders>' ':(exclude)<user guide folder>' ':(exclude)<each local-only file>'
      git ls-files --others --exclude-standard -- . ':(exclude)<skill folders>' ':(exclude)<user guide folder>' ':(exclude)<each local-only file>'
      git diff --name-only --no-renames <merge-base sha> -- '<user guide folder>'
      git ls-files --others --exclude-standard -- '<user guide folder>'
      ```

      The first two commands list the app files: commits and working-tree changes, then untracked files. The last two
      list the user guide files the same way. `--no-renames` lists a moved file under its old path
      and its new path, so both features show.
    - Use the file names for coverage only, never for expectations. They are not the diff that step 1 means.
    - Group the app file names into items. Each item has one feature, or every feature that lists the same folder.
      Test files (`<test file patterns>`) are not items. Place each other file by the first rule that matches:
      1. A file named in a feature's "Why it is here" text (for example a stored procedure) belongs to that feature.
      2. A file in `<shared folders>` goes in one item, "shared: affects many screens", with its folder.
      3. A file under a feature's "Code folders" entry in `features/README.md`, at any depth, belongs to the feature
         with the longest matching entry. When several features list that same folder, name them all in one item.
      4. Any other file goes in an item "other: `<folder>`".
    - Inside a feature, map the path to a screen, tab, side panel or dialog by its folder name. Name the item by what
      the user sees, for example "<screen>, <tab> tab".
    - With no `Code folders` column in the map, say so, and suggest `/agentd-verify-init` (update mode adds the column).
      Group the files by folder, and ask the engineer which feature each folder belongs to.
    - An item may lie inside a feature the engineer left out in step 2. Then name the item and its feature. In Not
      verified, list the item under that feature's entry, not as a separate line. Once the engineer picks the item in
      this step, the report shows that feature as driven by the item, not as left out.
    - Mark an item `driven` only when a numbered step acted on it (an edit, a click or a value check) and saved an
      evidence file. Write that step number next to it. A screen that only loaded on the way to another step is
      `not driven`.
    - Show the engineer a numbered list of the `not driven` items, with the file names behind each one. Mark each item
      that cannot be driven now, and give the reason, for example "blocked by the failure this run found". The engineer
      cannot pick a marked item. Ask which items to continue with: none, one or more.
    - A "shared" or "other" item has no screen of its own. The engineer can pick it only after naming a screen to
      drive it on. Otherwise mark it "cannot be driven now: no screen named".
    - For each item the engineer picks, in this order:
      1. Check the data it needs. It runs on the data as this run left it. When it needs data this run changed (for
         example a month this run locked), tell the engineer and ask before you restore. When the engineer says no,
         mark the item "cannot be driven now: restore declined", and write no expectations for it.
      2. Write its expectations (see Expectations, "An item picked in Flow step 11").
      3. Treat its feature as chosen in step 2 from now on. An index-only item has no `Needs:` line: first ask the
         engineer which recipes it needs. Set up the data it needs under the step 8 rules. When a
         recipe is pending and the API runs without the admin roles, restart the API with `<admin roles>`, reload the
         page, save a new current-user response and run Doctor. After the recipe, restart the API with the roles of the
         `Roles:` line and run Doctor again.
      4. Drive it from its feature file's entry points. An index-only item follows the step 9 rules for an index-only
         feature. When those do not reach it, ask the engineer
         how to reach it.
         Never read the branch's code to find it.
      5. Check it: the three-way match and the edges for this item. Do not make a new neighbours pass. Label its steps
         in the report with the item name.
    - Before a restore, run the Side effects SELECTs and record the database legs of the main journey: the report uses
      these results, not the restored data. A restore keeps the evidence folder from step 5. Run `cleanup.ps1`, then
      Flow steps 4, 6, 7 and 8 again. In step 4, run `db-start.ps1` with `-ConfirmRestore`. Save each current-user
      response to a new file, so the evidence of the main journey stays.
    - A `blocked:` stop inside this step ends the run, as in step 4. Keep the coverage table. Mark each item not yet
      driven "not driven: run stopped in Flow step 11".
    - Then offer again, from the same item list: mark the items driven in this round, and show the items still
      `not driven`. Do not list or group the files again. The agent does not offer an item again once the engineer has
      picked it. Stop when no item is left to offer, when the engineer picks none, or when a round drives no new item.
    - An item the engineer picks may lie outside the features chosen in step 2. That is allowed, because the engineer
      picked it.
    - In the report, each item still `not driven` goes under Not verified as "in the change, not driven". It does not
      block a `pass` unless it holds a written expectation. Then it is a core check not done (see Results and Order of
      results).
    - A user guide change goes under Not verified as "user guide changed; not checked in a verify run".
12. **Report and clean up.** Write the evidence report. Run `cleanup.ps1`. Check that the evidence folder still exists.

## Input

Two parts. Read both before anything else.

1. **The raw ticket.** The engineer pastes the work item text as it stands. Write expectations from this, never from a
   summary written by the agent that made the fix. The only exception is the change's claims in Expectations. The agent
   shows them to the engineer. Only a line the engineer confirms becomes an expectation. With no raw ticket, the skill
   asks the engineer for the raw ticket and does not start.
2. **The Verify block**, written by `/agentd-dev-rev`. It says what changed and how to reach it, not what is right.
   It has no `Expected:` line. The `Change:` line tells you which feature to drive. It is never an expected result. It is also one source of the
   change's claims, which the engineer confirms (see Expectations).

```
Verify:
Ticket: <number>
Base: <base branch> @ <merge-base sha>
Change: <the user-visible behaviour that changed, 1-2 sentences; navigation, and one source of claims>
Feature: <feature file(s), or <feature> (index only)>; entry points: <which ones>
Neighbours: <features from blast-radius> | none
Data: empty | setup: <recipe names> | bacpac: <what the data must contain> | records: <specific rows to create>
Roles: default | <role list>
API: <the API the run must use, and "debug token" when the engineer will run the API call with a debug token and paste back the value>
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
- With no block, also ask what to check. Step 2 (Choose the features) asks which feature files to run.
- `API:` is optional. When the line is absent, use the default API that the stack reference names. For an iOS app, the API-leg rule of `references/ios.md` applies instead; its API leg is never `blocked`. When it names an API, use that one and say so under Environment. If the run cannot reach it, the result is `blocked`.
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
- **A ticket that names no screen, field or action** (for example "improve performance and user experience"):
  1. Ask the engineer first: "Which user-visible changes should this run check?" Show no list before the answer.
  2. Then show the change's claims, as a checklist of anything the engineer did not name. Give the source next to each
     claim. The claims come from four places:
     - the Verify block's `Change:` line;
     - the commit subjects: `git log <merge-base sha>..HEAD --format=%s`. They cover commits only, not working-tree
       changes. `/agentd-dev-rev` stages and does not commit, so there may be none yet: say so;
     - the PR description, when a PR exists and the project's PR tool can read it (for example `gh pr view --json
       body`). With no PR, or when the tool fails, skip it and say so. Leave out any Verify block or diagnose hand-off
       text in it: never show the fixing side's expected output as a claim;
     - the user guide changes: `git diff <merge-base sha> -- '<user guide folder>'`, and the untracked files that
       `git ls-files --others --exclude-standard -- '<user guide folder>'` lists.
  3. The engineer confirms, changes or removes each line. Each confirmed line is an expectation with source
     `engineer`. A claim the engineer has not confirmed is not an expectation.
  4. A confirmed line may need a feature the engineer did not choose in step 2. Then ask whether to add that feature to
     the step 2 list. When the engineer does not add it, the line is not an expectation. List it in Not verified as
     "left out by the engineer in step 2".
- **An item picked in Flow step 11.** Write its expectations before you drive it.
  - Ask the engineer what the item should now do. You may show the claims that name the item, as a checklist. Each
    line the engineer confirms has source `engineer`.
  - For behaviour the engineer does not describe as changed, use the base code (`git show <merge-base sha>:<path>`).
  - Add the lines to the Expectations list under "Added in Flow step 11, before driving `<item>`". Once written, they
    are core checks, like every other expectation.
- An expectation with source `engineer` does not depend on the reading of the ticket. When it fails, the result is
  `fail`, not `disagree` (see Order of results).
- **Branch input.** Only two kinds are allowed: the claims above, and the file names in Flow step 11. Never read the
  branch's code, including the files behind a step 11 item.
- **Behaviour the ticket does not change:** the code on the base branch, read with `git show <base>:<path>`, so the fix
  cannot confirm itself.
- **A calculation reference** (`Reference anchors:`) is an index, never the oracle. It was written from the code and
  may be out of date. Use it to find the right code. When it disagrees with the base-branch code, write a `conflict:`
  line for that anchor under Reference conflicts. That is a documentation finding, not a fail. Its warning notes are
  claims too and get the same check.
- Expectations never come from the diff or from the branch's new code. The only exception is a line the engineer
  confirmed under "A ticket that names no screen, field or action" or "An item picked in Flow step 11". Its source is
  then `engineer`.
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
  `none`, use the features in the map that the engineer did not choose in step 2, except a feature the ticket touches
  that the engineer left out, and except index-only features. A neighbour named on `Neighbours:` that is index only
  is not driven: list it in Not verified as "index only: no feature file". A neighbour runs on the data the run
  already has: skip a neighbour step whose `Needs:`
  recipe did not run, and list it in Not verified.
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
  app"; a test-environment database backup (a bacpac for SQL Server) only when the ticket needs specific data.

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
- Run this skill in a fresh session. The session gets only the feature map, the raw ticket and the Verify block. The
  two later inputs (the change's claims and the changed file names) are allowed only as Expectations and Flow step 11
  name them.
- This skill is not a task agent by default. A skill that cannot be auto-loaded cannot be preloaded into a sub-agent.
- Never type credentials. Never read, print or change user secrets or any connection string.

## Report

Write the evidence report in the shape below, then give the result. Copy everything under `## Report` and `## Results`
of `templates/report.md` of the generator when you write this skill, including the notes and the Order of results.

<paste everything under `## Report` and `## Results` here>

## Gotchas

- Fill this list from what the proof run showed. Keep `unknown:` and `inferred:` on what no run has checked. After a
  passing proof run, replace each of them that the run confirmed or refuted with the result. Examples: the browser profile keeps or loses the sign-in between runs;
  a port is fixed. Add each gotcha that a loaded reference says to put here (for example the Apple Silicon steps of the database reference).
- A fixed port: a port that the project fixes (in a launch profile, a server configuration or a script) may be held by the operating system (macOS holds port
  5000 for AirPlay Receiver). Do not require a plain-HTTP port when the UI calls only the secure port, for example `https://localhost:<port>`. Doctor and the start helper name the process that holds a port. The stack reference says how to change the port.
- Local-only files: an edit to a local-only file (`<local-only file>`) never forces a restore. A branch script that
  changed or was removed, or an app-code change outside the scripts folder, this skill's folder and the local-only
  files, forces a restore. A new branch script is applied by the migration runner without a restore.
- The header has no `disable-model-invocation` line. Copilot cannot load a skill that has the flag (checked with
  Copilot 1.0.102). The engineer may add it back when Copilot supports it, to keep the skill out of the auto-loaded
  context.
- The `metadata` marker is nested, with two spaces, so `/agentd-dev-rev` and update mode can find this skill.
