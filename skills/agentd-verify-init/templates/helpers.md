# Helper contracts

Used in Flow step 5 of `agentd-verify-init`. This file gives the contract of each helper: its parameters, what it
prints and the rule it enforces. It holds no function bodies. Write each helper in the scripting language of the
repository, and name the files as below with that language's extension (`.ps1` here, for PowerShell). The helpers go
in the verify skill's folder, so a committed skill carries them.

## Rules for every helper

- No personal paths. Find a tool on `PATH`, or by an environment variable named for the tool. A tool that is not
  found on PATH and has no variable set stops the helper with a message that names the variable.
- No secrets in any file. The database reference says how the database password is made and where it is kept.
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
  state). It must stop with its own `blocked:` message instead of a shell error. This is a run-time smoke check
  and does not start Docker. It applies to every helper except the shared file that is only sourced.
- A helper that runs a query in the container must wrap query results in `@()` before indexing or counting. PowerShell turns a
  one-row result into a plain string, so the count prints its first character and a `.Count` read fails.
- Privacy: the browser tool's open output prints the full authorize URL (tenant and client IDs), its network output
  prints the Authorization header, and a saved response can hold the signed-in person's name. Filter these from tool
  output before it reaches notes or the report. Doctor output follows the same rule. Evidence files are the only place
  such data may be saved, outside every repository.

## Where the other contracts live

The contracts of the helpers that depend on the stack sit in the reference for that stack. Load the reference, then give each helper its contract.

- `db-start.ps1` and `db-restore.ps1`: `references/sqlserver-docker.md`.
- `dbup-run.ps1` and `api-start.ps1`: `references/dotnet.md`.
- `ui-start.ps1`: `references/react.md`.

An entry applies only when its reference was loaded. For any other stack, use the next section.

## When no reference matches

A stack with no matching reference still needs all the helpers it uses. Write each helper from the core rules above and the four rules below, ask the engineer for what the code does not show, and mark the helper `inferred:`.

- A start helper refuses to start when a process this run did not start already holds the port. It names the process.
- A helper that needs a dependency that is missing stops with `blocked: <reason>` and prints the fix command. It never runs the command itself. The fix command must not change tracked files.
- A helper never falls back to a settings file for a connection string.
- A helper that runs the migrations or starts the API refuses to run unless the connection environment variable is set and names the container's host and port.

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
