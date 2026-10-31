#!/usr/bin/env bash
# Checks that text shared between skills stays word for word the same, so one copy cannot drift from the others.
# Today it checks the "Find the project facts" paragraph: how a skill finds the onboarding pack and the project
# contract. Line breaks and indents may differ between skills; the words may not. Reads files and writes nothing.
# Usage: tests/test-shared-text.sh
set -u

HERE=$(cd "$(dirname "$0")" && pwd -P)
SKILLS="$HERE/../skills"
PASS=0
FAIL=0

check() {
  local desc=$1
  shift
  if "$@" >/dev/null 2>&1; then
    PASS=$((PASS + 1))
    printf '  pass  %s\n' "$desc"
  else
    FAIL=$((FAIL + 1))
    printf '  FAIL  %s\n' "$desc"
  fi
}

# The skills that read the onboarding pack or the project contract.
READERS="agentd-diagnose agentd-blast-radius agentd-pr-review agentd-data-fix agentd-intake agentd-explain agentd-verify-init agentd-dev-rev"

# paragraph <file>: the "Find the project facts" paragraph on one line, with any list mark and indent removed. It ends
# at a blank line, the next list item or a heading.
paragraph() {
  awk '
    !on && index($0, "**Find the project facts.**") { on = 1; l = $0; sub(/^- /, "", l); out = l; next }
    on && ($0 ~ /^[[:space:]]*$/ || $0 ~ /^- / || $0 ~ /^#/) { exit }
    on { l = $0; sub(/^[[:space:]]+/, "", l); out = out " " l }
    END { if (on) print out }
  ' "$1" | tr -s ' '
}

REF=$(paragraph "$SKILLS/agentd-diagnose/SKILL.md")
check "agentd-diagnose has the paragraph" [ -n "$REF" ]

for s in $READERS; do
  f="$SKILLS/$s/SKILL.md"
  check "$s has the paragraph once" [ "$(grep -c 'Find the project facts' "$f")" -eq 1 ]
  check "$s has the same words as agentd-diagnose" [ "$(paragraph "$f")" = "$REF" ]
done

# The paragraph names the tool by its home path, never by a ~ path, and the tool exists.
check "the paragraph runs onboarding-pack find and set" bash -c \
  'printf "%s" "$1" | grep -qF "\"\$HOME/.agents/bin/onboarding-pack\" find" &&
   printf "%s" "$1" | grep -qF "\"\$HOME/.agents/bin/onboarding-pack\" set <folder>"' _ "$REF"
check "the tool is in global/bin" [ -x "$HERE/../global/bin/onboarding-pack" ]
check "the paragraph treats an unsourced access rule as no access" bash -c \
  'printf "%s" "$1" | grep -qF "as no access"' _ "$REF"

# The .NET notes of blast-radius, diagnose and onboard tell .NET Framework from .NET Core with the same bullets.
# kind_bullets <file>: the lines of the "Which kind of project" part of a dotnet.md that are the shared rule.
kind_bullets() {
  awk '/^## Which kind of project/ { on = 1; next } /^## / { on = 0 } on && (/^- / || /^Read the target/)' "$1"
}

KREF=$(kind_bullets "$SKILLS/agentd-blast-radius/references/dotnet.md")
# blast-radius holds the reference copy. Change the bullets in all three files together. The sentence after the list
# differs on purpose in each file.
check "blast-radius dotnet.md has the kind bullets (the reference copy)" [ "$(printf '%s\n' "$KREF" | grep -c '^- ')" -ge 5 ]
for s in agentd-diagnose agentd-onboard; do
  check "$s dotnet.md has the same kind bullets as blast-radius" \
    [ "$(kind_bullets "$SKILLS/$s/references/dotnet.md")" = "$KREF" ]
done

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
