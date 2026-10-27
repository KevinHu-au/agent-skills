# Helper contracts

Used in Flow step 5 of `agentd-verify-init`. This file gives the contract of each helper: its parameters, what it
prints and the rule it enforces. It holds no function bodies. Write each helper in the scripting language of the
repository, and name the files as below with that language's extension (`.ps1` here, for PowerShell). The helpers go
in the verify skill's folder, so a committed skill carries them.

## Rules for every helper

- No personal paths. Find a tool on `PATH`, or by an environment variable such as `SQLPACKAGE_PATH`. A tool that is not
  found on PATH and has no variable set stops the helper with a message that names the variable.
- No secrets in any file. The database password is made per container, stored only in the container configuration, and
  read back with `docker inspect`.
- Helpers never edit settings files, and never read, print, copy or change user secrets. Connection strings and roles
  go to the app as an environment variable.
- Every helper prints one line per step and ends with `ok` or `blocked: <reason>`.
- The scripts folder is the folder the project's migration tool runs scripts from.
- No customer values in a usage example. A usage example in a contract or a helper header shows `<ticket>`, and never a
  real work item number.
- Write `${name}?` (braces) whenever a variable is followed by `?` in a string. PowerShell 7 reads `"$name?"` as a
  variable called `name?`. This only fails at run time, so a parse check does not catch it.
- Helpers set strict mode. Test that the key exists first, before a read of an optional key from a settings file, such
  as the role override list. A missing key is an error under strict mode.
- A parse check is not enough. After it, run each helper once with its prerequisites missing (no container, no
  state). It must stop with its own `blocked:` message instead of a PowerShell error. This is a run-time smoke check
  and does not start Docker. It applies to every helper except the shared file that is only sourced.
- A helper that runs a query in the container must wrap query results in `@()` before indexing or counting. PowerShell turns a
  one-row result into a plain string, so the count prints its first character and a `.Count` read fails.
- Privacy: the browser tool's open output prints the full authorize URL (tenant and client IDs), its network output
  prints the Authorization header, and a saved response can hold the signed-in person's name. Filter these from tool
  output before it reaches notes or the report. Doctor output follows the same rule. Evidence files are the only place
  such data may be saved, outside every repository.

## state.json

Path: `~/.<app>-verify/<ticket>/state.json`. It sits outside every repository and is never committed. Keys:

| Key | Holds |
|---|---|
| `containerId` | the container ID |
| `createdAt` | when the container was created |
| `dataSource` | `empty`, or the bacpac file name and date |
| `recipes` | the setup recipes that ran on this container |
| `branchScripts` | map from script path to the SHA-256 of the script |
| `appFingerprint` | the app-code fingerprint, a SHA-256 |
| `evidenceFolder` | the evidence folder of the current run, so a later session does not guess by newest timestamp |

- Branch scripts: a script the branch adds or changes against `Base:`. Read the working tree, not commits. The list is
  `git diff --name-only <merge-base sha>` (committed, staged and unstaged) plus the untracked files from
  `git ls-files --others --exclude-standard`, under the scripts folder.
- A hash is recorded only after the migration log shows that script ran.
- The app-code fingerprint is a SHA-256 of `git diff <merge-base sha>` plus the untracked files, outside the scripts folder, the skill's own folder, and the local-only files.
- Local-only files: files the engineer edits by hand on their own machine that hold no application logic, for example
  the UI sign-in values file (`<local-only file>`). The generated skill lists them in one place, the `LocalOnlyFiles`
  list in `common.ps1`. The engineer approves each entry, and the agent never reads their content.
- Scripts that the migration tool will re-run on every run, such as stored procedures, need no hash.
- Before each run: a different container ID resets the recipe list, clears `branchScripts`, `appFingerprint` and `dataSource`, and skips the restore check. A missing stored value is no reason to restore. A recorded branch script whose hash changed, or a
  removed script forces a fresh restore and a re-run of the recipes, because the migration journal would skip an
  edited script. A changed app-code fingerprint also forces a fresh restore, because recipe data made through the UI by
  an earlier build may be wrong. A changed data source (for example `empty` to `bacpac`) also forces a fresh restore,
  because the import needs an empty database. The report says when this happened.

## common.ps1

State, hashing and the evidence folder. It is dot-sourced by the other helpers and prints nothing by itself.

- `Get-State`, `Set-State`: read and write `state.json`. Parameters: ticket.
- `Get-BranchScripts`: parameters: merge-base sha, scripts folder. Prints the script paths and their SHA-256.
- `Get-AppFingerprint`: parameters: merge-base sha, scripts folder. Prints the SHA-256 and the first 8 characters.
- `LocalOnlyFiles`: the list of local-only files. `Get-AppFingerprint` leaves them out. Nothing else reads their content.
- `New-EvidenceFolder`: parameters: ticket. Creates `~/.<app>-verify/<ticket>/<timestamp>/` and prints its path.
- Rule: it creates and reads, and never removes anything. It records the new path in `state.json` as `evidenceFolder`.
- `state.json` has the launch keys (the process IDs of the API and UI and of their launchers, and the wanted roles) only
  after a launch writes them. The state reader must default every launch key to null when it is missing.

## db-start.ps1

Parameters: ticket, data source (`empty`, or the bacpac file name and its date), merge-base sha, scripts folder, and the
switch `-ConfirmRestore`.
Starts the SQL Server container for the ticket, or reuses the one in `state.json`, and does the state check. Prints the
container name, image tag, host port, the container ID, and one of `database: new`, `database: reused` or
`database: dropped`.

- Use the same SQL Server image the integration tests use, and never azure-sql-edge. It must have `sqlcmd`.
- One container per ticket, with a unique container name and a host port other than 1433. The container is kept between
  runs. Containers for several tickets may exist side by side.
- Make the password per container. Read it back with `docker inspect`. Never write it to a file.
- Wait until `sqlcmd` can run a query. An open port is not enough.
- State check: compare the container ID, the branch-script hashes (`Get-BranchScripts`, which needs the scripts folder),
  the app-code fingerprint and the data source with `state.json`. This helper owns the check. When it forces a fresh
  restore, print `fresh restore needed: <reason>`, so the report can say that a restore happened and why. The helper
  writes `containerId` and `createdAt` when it creates the container, and writes `dataSource` only after the state check
  passes or after a confirmed drop, never on a `blocked` exit.
- Fresh restore: drop and recreate the per-ticket database. The helper then clears `branchScripts` and `recipes` in
  `state.json`. It never drops any other database. It never imports a bacpac: `db-restore.ps1` does. The migration
  upgrade is `dbup-run.ps1`.
- In a terminal, the helper prompts the engineer before it drops. An agent without a terminal asks the engineer and runs
  the helper again with `-ConfirmRestore`. Without the switch and without a terminal, the helper refuses with `blocked`
  and never drops: it ends with `blocked: fresh restore needed: <reason>`. With `-ConfirmRestore` and no forced reason,
  the helper drops and recreates the database on request.
- Data made by SQL, not through the app, needs the engineer's approval for each insert, and the report marks it "made by
  SQL, not through the app".

## db-restore.ps1

Parameters: ticket, bacpac path (asked at run time, never stored in a file), merge-base sha, scripts folder. Used only
when the data source is a bacpac and `db-start.ps1` printed `database: new` or `database: dropped`. Imports the bacpac
and checks the journal. Prints the number of journal entries and each entry that is neither the base nor the branch.

- Find `SqlPackage` by the `SQLPACKAGE_PATH` environment variable, then on `PATH`.
- Do the journal check with a read-only SELECT after the import and before the upgrade. Find the branch scripts with
  `Get-BranchScripts`, from the merge-base sha and the scripts folder, and map each path to the journal's name format
  (`references/dotnet.md`). If the journal already lists a branch script, stop with `blocked`: the test environment ran an earlier version, and the upgrade would skip it. The
  engineer picks an older bacpac or another data source.
- List journal entries that are on neither the base nor the branch: the entries on neither the base nor the branch go
  under Environment and under Not verified in the report ("the test environment ran scripts not on this branch").
- Never reset. The upgrade always follows in `dbup-run.ps1`.

## dbup-run.ps1

Parameters: ticket, scripts project folder, merge-base sha, scripts folder. Runs the migration tool in upgrade mode from
its own project folder and prints the log lines that name each script that ran. It runs on every run, after
`db-start.ps1`, and after `db-restore.ps1` when that ran. It never takes the place of the bacpac journal check.

- Rule: it must refuse to run unless the connection environment variable is set and names the container's host and
  port. It must never fall back to a settings file, because a settings file can name the engineer's own database.
- Pass the connection string as an environment variable. Never read or print its value.
- After the log shows a branch script ran, record its hash in `state.json`. Not before. Find the branch scripts with
  `Get-BranchScripts`. The helper drops the entries of removed scripts, and writes `appFingerprint` after a successful run.
- Scripts the tool re-runs on every run are not hashed.
- The "DbUp scripts applied" number in the Environment line is the journal row count, read from the database with
  `SELECT COUNT(*)` on the journal table after the run. It is not a count of lines in the log that the helper printed.

## api-start.ps1

Parameters: ticket, roles (a list, or `default`). Starts the API with the container's connection string and the wanted
roles in environment variables. Prints the port and the process ID, and saves the process ID in `state.json`.

- Rule: it must refuse to run unless the connection environment variable is set and names the container's host and
  port. It never falls back to a settings file.
- Roles: for k wanted roles and N entries in the settings JSON, set indexes 0..max(N,k)-1, cycling through the k roles.
  Read N from the JSON files only. A role change restarts the API.
- Refuse to start when something this run did not start already holds the port. Name the process.
- It must not require the plain-HTTP port when the UI only calls the secure port. Pass `--urls` for the secure port
  only. When it refuses, it names the process that holds a port. Some systems hold a fixed port: macOS holds port 5000
  for AirPlay Receiver.

## ui-start.ps1

Parameters: ticket. Starts the UI dev server and waits until the port answers an HTTP request. Prints the URL and the
process ID, and saves the process ID in `state.json`. Refuse when a process this run did not start holds the port.

- When a dependency is missing, it stops with `blocked: <reason>` and prints the fix command. It never runs the command
  itself. The fix command must not change tracked files (for npm, `npm ci`, never `npm install`).

## doctor.ps1

Parameters: ticket, wanted roles, and the path of the saved response file of the API's current-user call. Runs after
sign-in. Prints one line per check and ends with `ok` or `blocked: <reason>`.

- The agent saves the current-user response in the evidence folder through the browser tool, then passes the path.
  Doctor reads the signed-in user and the roles from that saved response file. The token is never printed or saved, and
  Doctor never asks for it. With no file it stops with `blocked: no saved response file`. After an API restart, pass
  the path of a new saved response file, never the file from before the restart.
- Checks the ports, the signed-in API user, the role set, the container, and the database target
  (`SELECT DB_NAME(), @@SERVERNAME` through the API's own connection or the container; report both values).
- Rule: the role set the API reports must equal the wanted set exactly. An extra or missing role is `blocked`, with the
  hint that another configuration source may hold more entries and the engineer can give their count. When the set
  differs, print the likely cause first ("the API was started with other roles; run the API start helper again"), and
  then the set difference.
- It prints only that a user is signed in, and the role set. It never prints a name or an email.
- Rule: before an authorisation feature, the authorisation switch must not turn authorisation off.
- Rule: the UI sign-in values are not placeholders.
- Rule: it refuses to drive an API or UI that this run did not start.

## cleanup.ps1

Parameters: ticket. Stops the API and UI processes this run started, using the process IDs in `state.json`, and
nothing else. It stops only the recorded process IDs.

- It never removes the container, `state.json` or the evidence folder.
- Removing a container is outside this helper. It asks the engineer before removing anything: it prints the
  `docker rm` command, and the engineer runs it.
- It prints the process IDs it stopped.
