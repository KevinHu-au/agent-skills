# Shell helpers (bash on macOS and Linux)

Load this file in Flow step 5, when the helpers are written in bash or zsh: the repository's scripts are shell scripts, or the helpers run on a Mac. It says how to write them. The rules for every helper are in `templates/helpers.md`. These notes come from general knowledge of the platform. The lines marked checked were checked on one Mac with macOS's own tools. They are not yet checked on a customer project. Mark a recipe built only from the unchecked notes `inferred:`.

## Rules

- Start every helper with `#!/usr/bin/env bash` and `set -u`, and run it with `bash <helper>`, never with `zsh <helper>`. Checked: macOS has bash 3.2.57 at `/bin/bash` and zsh 5.9. In zsh an unquoted variable is not split into words, and in bash it is, so one `for f in $files` loop does two different things. Quote every variable, and keep a list in an array.
- Checked: macOS bash is version 3.2. It has no associative arrays and no `mapfile`. `inferred:` Use a file or `jq` for a map, and a `while read` loop for lines.
- With `set -u`, write `${name:-}` for a variable that may be unset.
- Under `set -u`, bash 3.2 treats `"${list[@]}"` on an empty array as an unbound variable. Test the length first (`[ "${#list[@]}" -gt 0 ]`), or write `${list[@]+"${list[@]}"}`. `inferred:`
- A query that returns one row returns one line. Count lines with `wc -l`, and read the first with `head -n 1`. Do not treat the result as an array.
- `sed -i` on macOS needs an empty suffix argument (`sed -i '' ...`), and on Linux it must not have one. Do not use in-place `sed` in a helper. Write to a temp file, or use `jq`.
- Stop a process by its recorded ID with `kill <pid>`, never by name with `pkill`.
- Print one line per step, and end with `ok` or `blocked: <reason>`. Exit with 0 for `ok` and 1 for `blocked`. `inferred:`

## State and queries

- Checked: `jq` 1.7.1 is at `/usr/bin/jq`. Read an optional key with `jq -r '.key // empty'`: a missing key is an empty string, not an error. Test for empty before you use it.
- Write `state.json` to a temp file and move it into place, so a half-written file never replaces it. `inferred:`
- Hash a file with `shasum -a 256 <file>` on macOS (`sha256sum` on Linux). `inferred:`
- The shared file is `common.sh`, sourced by the other helpers. It prints nothing by itself and never removes anything.
