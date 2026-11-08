#!/bin/bash
# Shell safety hook for the agentd skills, shared by Claude Code, Copilot CLI and Codex.
# Denies dangerous git commands. Asks before commands that remove files, commit, rewrite git history,
# discard changes, create, complete or merge a pull request, or write to a SQL Server database.
# Prints nothing for everything else (empty output means the tool's default behaviour).
#
# Usage: block-dangerous-shell.sh [--harness claude|copilot|codex] [--event tool|prompt|end]
#   claude   Called from the hooks: block in each agentd SKILL.md, so Claude Code runs it only after an
#            agentd skill starts. Prints the hookSpecificOutput shape.
#   copilot  Called from ~/.copilot/hooks/git-safety.json. Prints the flat Copilot shape. Gated (see below).
#   codex    Called from ~/.codex/hooks.json. Prints the hookSpecificOutput shape. Codex hooks cannot ask,
#            so every ask becomes a deny. Gated (see below).
#   (none)   Older installs that call the script with no flags. The input decides the shape, and only the
#            older rules run (dangerous git and file removal), so a git pull changes nothing for them.
#
# The gate. Copilot and Codex cannot attach a hook to a skill, so their hook is installed for the user and
# stays dormant until an agentd skill starts in that session. An agentd skill is one in ~/.agents/skills whose
# SKILL.md holds this hook's line (--harness claude --event tool), so another kit's agentd-* skill does not count.
# It starts when:
#   --event prompt  a prompt names /agentd-<name> or $agentd-<name>;
#   --event tool    Copilot's skill tool starts agentd-<name>, or a shell command reads the skill's SKILL.md
#                   with cat, head, sed, less, more, bat, type or Get-Content.
# Then the hook writes an empty marker, ~/.agents/hook-state/<session-id>. A shell command is checked only in a
# session that has a marker. Each checked command refreshes the marker's time. The marker stays after the session
# ends, so a resumed session stays checked. Markers unused for 30 days are removed when a skill starts.
# --event end does nothing; older hook files call it.
# When the session ID cannot be read, the gate cannot tell: the rules run if any marker exists, else it is dormant.
# It also prints a warning on stderr, so the cause shows in the tool's hook log.
#
# In a checked session it fails closed: missing jq, input that is not JSON, or a command it cannot read is denied.
# A regex can never parse every shell form. It catches the common bypasses, not all of them.
# A false deny or ask (for example a command word inside a quoted message) is accepted as safe.
set -u

HARNESS=""
EVENT=tool
while [ $# -gt 0 ]; do
  case "$1" in
    --harness) HARNESS=${2:-}; shift 2 || shift ;;
    --event) EVENT=${2:-}; shift 2 || shift ;;
    *) shift ;;
  esac
done

INPUT=""
IFS= read -r -d '' INPUT || true

GATED=0
LEGACY=0
case "$HARNESS" in
  claude) FLAVOR=claude ;;
  copilot) FLAVOR=copilot; GATED=1 ;;
  codex) FLAVOR=codex; GATED=1 ;;
  *)
    LEGACY=1
    FLAVOR=copilot
    case "$INPUT" in
      *'"toolName"'*) ;;
      *'"tool_name"'*) FLAVOR=claude ;;
    esac
    ;;
esac

HAVE_JQ=1
command -v jq >/dev/null 2>&1 || HAVE_JQ=0

# deny_raw <reason>: a deny decision written without jq. The reason must hold no quote or backslash.
deny_raw() {
  if [ "$FLAVOR" = copilot ]; then
    printf '{"permissionDecision":"deny","permissionDecisionReason":"%s"}\n' "$1"
  else
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$1"
  fi
}

# decide <deny|ask> <reason>
decide() {
  local d=$1 reason=$2
  if [ "$FLAVOR" = codex ] && [ "$d" = ask ]; then
    d=deny
    reason="$reason Codex hooks cannot ask, so the command is blocked. The engineer can run it in their own terminal."
  fi
  if [ "$FLAVOR" = copilot ]; then
    jq -cn --arg d "$d" --arg reason "$reason" '{permissionDecision:$d, permissionDecisionReason:$reason}'
  else
    jq -cn --arg d "$d" --arg reason "$reason" \
      '{hookSpecificOutput:{hookEventName:"PreToolUse", permissionDecision:$d, permissionDecisionReason:$reason}}'
  fi
}

deny() { decide deny "$1"; }

ask() { decide ask "$1"; }

# --- The gate (Copilot and Codex only) ---

STATE_DIR="$HOME/.agents/hook-state"
SKILLS_DIR="$HOME/.agents/skills"
# A skill named in a prompt: /agentd-<name> or $agentd-<name>, after the start, a newline, a space or punctuation.
# Without jq the prompt is raw JSON, so an escaped newline (\n) also counts as a start.
SKILL_CALL='(^|\\n|[^A-Za-z0-9_.])[/$]agentd-[A-Za-z0-9-]+'
# A shell command that reads a skill file: the reader, then a path to agentd-<name>/SKILL.md.
SKILL_READ='^[[:space:]]*(cat|head|sed|less|more|bat|type|get-content)[[:space:]][^;&|]*agentd-[A-Za-z0-9-]+/SKILL\.md'

# The session ID. Only letters, digits, _ and - are kept, so the ID cannot leave the marker folder.
# Without jq, the first "sessionId" or "session_id" string in the input is used. Both tools send it first.
if [ "$HAVE_JQ" = 1 ]; then
  SESSION=$(printf '%s' "$INPUT" | jq -r '(.sessionId // .session_id // "") | tostring' 2>/dev/null)
else
  SESSION=$(printf '%s' "$INPUT" | grep -oE '"(sessionId|session_id)"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n 1 \
    | sed -E 's/.*"([^"]*)"$/\1/')
fi
SESSION=$(printf '%s' "$SESSION" | tr -cd 'A-Za-z0-9_-')
MARKER=""
[ -z "$SESSION" ] || MARKER="$STATE_DIR/$SESSION"
# A tool update that renames the field would land here, so say so in the tool's hook log.
if [ "$GATED" = 1 ] && [ -z "$MARKER" ]; then
  printf 'block-dangerous-shell.sh: could not read the session ID, so commands are checked while any marker exists in %s.\n' \
    "$STATE_DIR" >&2
fi

# ours <name>: true when ~/.agents/skills/<name>/SKILL.md is one of this repository's agentd skills.
ours() {
  case "$1" in agentd-*) ;; *) return 1 ;; esac
  case "$1" in *[!A-Za-z0-9-]*) return 1 ;; esac
  grep -qF -- '--harness claude --event tool' "$SKILLS_DIR/$1/SKILL.md" 2>/dev/null
}

# mark_names: read skill names, one per line, and write the marker when one of them is ours.
mark_names() {
  local n
  while IFS= read -r n; do
    if ours "$n"; then
      mark
      return 0
    fi
  done
  return 0
}

mark() {
  [ -n "$MARKER" ] || return 0
  if ! (umask 077 && mkdir -p "$STATE_DIR" && : >"$MARKER") 2>/dev/null; then
    printf 'block-dangerous-shell.sh: could not write %s, so this agentd session is not checked.\n' "$MARKER" >&2
    return 0
  fi
  # Old markers: one empty file per session. A marker unused for 30 days is removed.
  find "$STATE_DIR" -type f -mtime +30 -delete 2>/dev/null
  return 0
}

# dormant: true when this session has not started an agentd skill. When the session ID cannot be read, the
# hook cannot tell, so it is dormant only while no marker exists at all.
dormant() {
  if [ -n "$MARKER" ]; then
    [ ! -e "$MARKER" ]
  else
    [ -z "$(ls -A "$STATE_DIR" 2>/dev/null)" ]
  fi
}

if [ "$GATED" = 1 ]; then
  case "$EVENT" in
    prompt)
      if [ "$HAVE_JQ" = 1 ]; then
        PROMPT=$(printf '%s' "$INPUT" | jq -r '(.prompt // "") | tostring' 2>/dev/null)
      else
        PROMPT=$INPUT
      fi
      printf '%s\n' "$PROMPT" | grep -oE -- "$SKILL_CALL" | sed -E 's/.*[/$]//' | mark_names
      exit 0
      ;;
    tool) ;;
    *) exit 0 ;;
  esac
fi

# --- A tool call ---

if [ "$HAVE_JQ" = 0 ]; then
  if [ "$GATED" = 1 ]; then
    # Copilot's skill tool, read from the raw JSON. It starts a skill and is not a shell command, so no decision.
    STARTED=$(printf '%s' "$INPUT" | grep -oE '"skill"[[:space:]]*:[[:space:]]*"agentd-[A-Za-z0-9-]+"' \
      | sed -E 's/.*"(agentd-[A-Za-z0-9-]+)"$/\1/')
    if [ -n "$STARTED" ]; then
      printf '%s\n' "$STARTED" | mark_names
      exit 0
    fi
    if dormant; then
      exit 0
    fi
  fi
  deny_raw "block-dangerous-shell.sh needs jq to read the command, and jq was not found. Install jq (brew install jq)."
  exit 0
fi

# One jq call prints the tool name, the skill name, the command and a final dot, each after a newline.
# The dot keeps the trailing newlines that command substitution would strip.
if ! OUT=$(
  printf '%s' "$INPUT" | jq -j '
    def args:
      if .toolArgs then
        if (.toolArgs | type) == "string" then (.toolArgs | fromjson? // {}) else .toolArgs end
      elif .tool_input then
        if (.tool_input | type) == "string" then (.tool_input | fromjson? // {}) else .tool_input end
      else {} end;
    def line: tostring | gsub("[\r\n]"; " ");
    ((.toolName // .tool_name // "") | line) + "\n"
    + ((if (args | type) == "object" then args.skill else null end // "") | line) + "\n"
    + (args.command // "") + "\n."
  ' 2>/dev/null
); then
  if [ "$GATED" = 1 ] && dormant; then
    exit 0
  fi
  deny "block-dangerous-shell.sh could not read the hook input."
  exit 0
fi
OUT=${OUT%.}
TOOL_NAME=${OUT%%$'\n'*}
OUT=${OUT#*$'\n'}
SKILL=${OUT%%$'\n'*}
COMMAND=${OUT#*$'\n'}
COMMAND=${COMMAND%$'\n'}

if [ "$GATED" = 1 ]; then
  # Copilot starts a skill through its skill tool.
  [ "$TOOL_NAME" != skill ] || printf '%s\n' "$SKILL" | mark_names
  # A shell command that reads an agentd SKILL.md starts one too (an agent loading the skill by hand).
  if printf '%s\n' "$COMMAND" | grep -Eiq -- "$SKILL_READ"; then
    printf '%s\n' "$COMMAND" | grep -oE 'agentd-[A-Za-z0-9-]+/SKILL\.md' | sed 's#/SKILL\.md$##' | mark_names
  fi
  # Dormant until an agentd skill starts in this session.
  if dormant; then
    exit 0
  fi
  # A checked session: refresh the marker's time, so it is not removed while still in use.
  [ -z "$MARKER" ] || touch "$MARKER" 2>/dev/null
fi

case "$TOOL_NAME" in
  bash|powershell|Bash|PowerShell|"") ;;
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

# Older installs stop here, so a git pull does not add the newer rules to every session.
[ "$LEGACY" = 0 ] || exit 0

# ask_if <regex> <what the command does>: ask when the regex matches the command.
ask_if() {
  if printf '%s\n' "$COMMAND" | grep -Eq -- "$1"; then
    ask "Shell command '$COMMAND' $2. Ask the user for explicit permission before continuing."
    exit 0
  fi
}

ask_if "(${GIT}commit${END})" "creates a git commit"
ask_if "(${GIT}(rebase|filter-branch)${END})|(${GIT}stash${ARGS}(drop|clear)${END})" \
  "rewrites git history or drops a stash"
# checkout -- <path> and restore throw away working-tree changes. The forms that discard everything are denied above.
ask_if "(${GIT}checkout${ARGS}--${END})|(${GIT}restore${END})" "discards changes in the working tree"
ask_if "(${START}gh[[:space:]]+pr[[:space:]]+(create|merge)${END})|(${START}az[[:space:]]+repos[[:space:]]+pr[[:space:]]+create${END})" \
  "creates or merges a pull request"
# Completing an Azure DevOps pull request merges it, now or (with auto-complete) once its policies pass.
# gh api can merge through the REST endpoint.
ask_if "(${START}az[[:space:]]+repos[[:space:]]+pr[[:space:]]+update${ARGS}(--status([[:space:]]+|=)[\"']?completed|--auto-complete([[:space:]]+|=)[\"']?true))|(${START}gh[[:space:]]+api[[:space:]][^;&|]*pulls/[0-9]+/merge)" \
  "completes or merges a pull request"

# A SQL client run with a write keyword. EXEC is included because a stored procedure can write.
# A script passed with -i is not read, so it is not caught.
SQL_CLIENT="${START}(sqlcmd|invoke-sqlcmd)${END}"
SQL_WRITE='(^|[^[:alnum:]_])(insert|update|delete|drop|truncate|alter|merge|create|exec|execute)([^[:alnum:]_]|$)'
if printf '%s\n' "$COMMAND" | grep -Eiq -- "$SQL_CLIENT" && printf '%s\n' "$COMMAND" | grep -Eiq -- "$SQL_WRITE"; then
  ask "Shell command '$COMMAND' writes to a database. Ask the user for explicit permission before continuing."
  exit 0
fi

exit 0
