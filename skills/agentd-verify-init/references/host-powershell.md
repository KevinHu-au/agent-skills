# PowerShell helpers (Windows PowerShell 5.1 and PowerShell 7)

Load this file in Flow step 5, when the helpers are written in PowerShell: the repository's scripts are PowerShell, or the helpers run on Windows. It holds the rules that are specific to PowerShell. The rules for every helper are in `templates/helpers.md`. These notes come from general knowledge of the platform. Checked: the Windows 11 virtual machine has Windows PowerShell 5.1 (`powershell.exe`). Every other line is not yet checked on a customer project. Mark a recipe built only from these notes `inferred:`.

## Rules

- Write `${name}?` (braces) whenever a variable is followed by `?` in a string. PowerShell 7 reads `"$name?"` as a
  variable called `name?`. This only fails at run time, so a parse check does not catch it.
- Helpers set strict mode. Test that the key exists first, before a read of an optional key from a settings file, such
  as the role override list. A missing key is an error under strict mode.
- A helper that runs a database query (in a container or in LocalDB) must wrap query results in `@()` before indexing or counting. PowerShell turns a
  one-row result into a plain string, so the count prints its first character and a `.Count` read fails.

## Windows PowerShell 5.1

- Write helpers that run on Windows PowerShell 5.1, which is what a Windows machine has by default. Do not use `&&` or `||` between commands, the ternary `?:`, `??`, or `ForEach-Object -Parallel`. These need PowerShell 7. `inferred:`
- Run a helper with `powershell -NoProfile -File <helper>`. A machine's execution policy may block a script. When it does, the helper stops with `blocked: execution policy` and prints the command `Get-ExecutionPolicy -List` for the engineer. The agent never changes the policy. `inferred:`
- Build paths with `Join-Path`, never with a hard-coded `\` or `/`. Take the user's folder from `$HOME`. Never write a personal path to a committed file.
- Write `state.json` and the evidence text files as UTF-8 without a byte order mark: `[System.IO.File]::WriteAllText($path, $text, (New-Object System.Text.UTF8Encoding($false)))`. Windows PowerShell 5.1 writes in another encoding by default, and `-Encoding UTF8` on a write adds a byte order mark in 5.1, which breaks other readers such as `jq`. Read the files with `Get-Content -Raw -Encoding UTF8`. `inferred:`
- Stop a process by its recorded ID with `Stop-Process -Id <id>`, never by name.
- Run the helpers as the Windows user who owns the LocalDB instances. Another user does not see them.
