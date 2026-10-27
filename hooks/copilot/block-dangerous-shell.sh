#!/bin/bash
# Copilot CLI preToolUse hook for shell commands.
# Denies dangerous git commands, asks before commands that remove files, and prints nothing
# for everything else (empty output means Copilot's default behaviour).
# It fails closed: missing jq, input that is not JSON, or a command it cannot read is denied.
# A regex can never parse every shell form. It catches the common bypasses, not all of them.
# A false deny or ask (for example a command word inside a quoted message) is accepted as safe.
set -u

# deny_raw <reason>: a deny decision written without jq. The reason must hold no quote or backslash.
deny_raw() {
  printf '{"permissionDecision":"deny","permissionDecisionReason":"%s"}\n' "$1"
}

if ! command -v jq >/dev/null 2>&1; then
  deny_raw "block-dangerous-shell.sh needs jq to read the command, and jq was not found. Install jq (brew install jq)."
  exit 0
fi

deny() {
  jq -cn --arg reason "$1" '{permissionDecision:"deny", permissionDecisionReason:$reason}'
}

ask() {
  jq -cn --arg reason "$1" '{permissionDecision:"ask", permissionDecisionReason:$reason}'
}

# One jq call prints the tool name, a newline, the command, a newline and a final dot.
# The dot keeps the trailing newlines that command substitution would strip.
if ! OUT=$(
  jq -j '
    def args:
      if .toolArgs then
        if (.toolArgs | type) == "string" then (.toolArgs | fromjson? // {}) else .toolArgs end
      elif .tool_input then
        if (.tool_input | type) == "string" then (.tool_input | fromjson? // {}) else .tool_input end
      else {} end;
    (.toolName // .tool_name // "") + "\n" + (args.command // "") + "\n."
  ' 2>/dev/null
); then
  deny "block-dangerous-shell.sh could not read the hook input."
  exit 0
fi
OUT=${OUT%.}
TOOL_NAME=${OUT%%$'\n'*}
COMMAND=${OUT#*$'\n'}
COMMAND=${COMMAND%$'\n'}

case "$TOOL_NAME" in
  bash|powershell|Bash|"") ;;
  *) exit 0 ;;
esac

if [ -z "$COMMAND" ]; then
  deny "block-dangerous-shell.sh could not read the shell command."
  exit 0
fi

# Join backslash line continuations (LF or CRLF), so "git reset \<newline> --hard" is read as one line.
BSCRNL=$'\\\r\n'
BSNL=$'\\\n'
COMMAND=${COMMAND//"$BSCRNL"/ }
COMMAND=${COMMAND//"$BSNL"/ }

# A command word starts the command or follows a separator, a bracket, a backtick, a quote or a space.
# It may carry a path (/usr/bin/git) or a leading backslash (\git).
START='(^|[;&|({`!$[:space:]"'"'"'])([^[:space:];&|()`"'"'"']*/)?\\?'
# Ends a word: a space, the end, a separator, a closing bracket, a quote or a redirection.
END='([[:space:]]|$|[;&|)`<>"'"'"'])'
# A global option value: quoted, a command substitution, or one unquoted word.
VALUE='("[^"]*"|'"'"'[^'"'"']*'"'"'|\$\([^)]*\)[^[:space:];&|]*|[^[:space:];&|]+)'
# git (maybe quoted), then its global options (-C <path>, -c <name=value>, --git-dir <path>, --no-pager, ...).
GIT_OPTS='-C|-c|--git-dir|--work-tree|--namespace|--config-env|--super-prefix|--exec-path'
GIT="${START}git[\"']?([[:space:]]+(${GIT_OPTS})[[:space:]]+${VALUE}|[[:space:]]+-[^[:space:];&|]*)*[[:space:]]+"
# Any arguments between a subcommand and the flag that makes it dangerous.
ARGS='[[:space:]]([^;&|]*[[:space:]])?'
FORCE='-[A-Za-z]*f[A-Za-z]*|--force'

DANGEROUS_GIT="(${GIT}push${END})"
DANGEROUS_GIT="${DANGEROUS_GIT}|(${GIT}reset${ARGS}--hard${END})"
DANGEROUS_GIT="${DANGEROUS_GIT}|(${GIT}clean${ARGS}(${FORCE})${END})"
# branch -D, -M (force delete or force rename) and -f (force move).
DANGEROUS_GIT="${DANGEROUS_GIT}|(${GIT}branch${ARGS}(-[A-Za-z]*[DM][A-Za-z]*|${FORCE})${END})"
# checkout -f, -B and switch -C, --force-create (reset an existing branch), or --discard-changes.
DANGEROUS_GIT="${DANGEROUS_GIT}|(${GIT}(checkout|switch)${ARGS}(-[A-Za-z]*[fBC][A-Za-z]*|--force|--force-create|--discard-changes)${END})"
DANGEROUS_GIT="${DANGEROUS_GIT}|(${GIT}(checkout|restore)${ARGS}\\.\\/?${END})"

if printf '%s\n' "$COMMAND" | grep -Eq -- "$DANGEROUS_GIT"; then
  deny "Blocked shell command: '$COMMAND' matches a dangerous git pattern. Ask the user explicitly before taking this action."
  exit 0
fi

REMOVE="(${START}(rm|rmdir|unlink|trash|shred)${END})|(${START}find[[:space:]][^;&|]*-delete${END})"
# PowerShell names are not case-sensitive.
REMOVE_PS="${START}(remove-item|ri|del|erase|rd)${END}"

if printf '%s\n' "$COMMAND" | grep -Eq -- "$REMOVE" || printf '%s\n' "$COMMAND" | grep -Eiq -- "$REMOVE_PS"; then
  ask "Shell command '$COMMAND' removes or deletes files. Ask the user for explicit permission before continuing."
  exit 0
fi

exit 0
