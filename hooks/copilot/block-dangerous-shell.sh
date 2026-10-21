#!/bin/bash
set -u

INPUT=$(cat)

COMMAND=$(
  printf '%s' "$INPUT" | jq -r '
    def args:
      if .toolArgs then
        if (.toolArgs | type) == "string" then (.toolArgs | fromjson? // {}) else .toolArgs end
      elif .tool_input then
        if (.tool_input | type) == "string" then (.tool_input | fromjson? // {}) else .tool_input end
      else {} end;
    args.command // ""
  '
)

TOOL_NAME=$(
  printf '%s' "$INPUT" | jq -r '.toolName // .tool_name // ""'
)

case "$TOOL_NAME" in
  bash|powershell|Bash|"")
    ;;
  *)
    printf '{"permissionDecision":"allow"}\n'
    exit 0
    ;;
esac

deny() {
  jq -cn --arg reason "$1" '{permissionDecision:"deny", permissionDecisionReason:$reason}'
}

ask() {
  jq -cn --arg reason "$1" '{permissionDecision:"ask", permissionDecisionReason:$reason}'
}

DANGEROUS_GIT_PATTERNS=(
  '(^|[;&|[:space:]])git[[:space:]]+push([[:space:]]|$)'
  '(^|[;&|[:space:]])git[[:space:]]+reset[[:space:]]+--hard([[:space:]]|$)'
  '(^|[;&|[:space:]])git[[:space:]]+clean[[:space:]]+-fd([[:space:]]|$)'
  '(^|[;&|[:space:]])git[[:space:]]+clean[[:space:]]+-f([[:space:]]|$)'
  '(^|[;&|[:space:]])git[[:space:]]+branch[[:space:]]+-D([[:space:]]|$)'
  '(^|[;&|[:space:]])git[[:space:]]+checkout[[:space:]]+\.([[:space:]]|$)'
  '(^|[;&|[:space:]])git[[:space:]]+restore[[:space:]]+\.([[:space:]]|$)'
  '(^|[;&|[:space:]])git[[:space:]].*push[[:space:]].*--force'
  '(^|[;&|[:space:]])git[[:space:]].*reset[[:space:]]+--hard'
)

for pattern in "${DANGEROUS_GIT_PATTERNS[@]}"; do
  if printf '%s\n' "$COMMAND" | grep -Eq "$pattern"; then
    deny "Blocked shell command: '$COMMAND' matches dangerous git safety pattern '$pattern'. Ask the user explicitly before taking this action."
    exit 0
  fi
done

if printf '%s\n' "$COMMAND" | grep -Eq '(^|[;&|[:space:]])(rm|trash)([[:space:]]|$)'; then
  ask "Shell command '$COMMAND' removes or deletes files. Ask the user for explicit permission before continuing."
  exit 0
fi

printf '{"permissionDecision":"allow"}\n'
