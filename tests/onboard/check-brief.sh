#!/usr/bin/env bash
# Deterministic checks for an onboarding brief (docs/onboarding/README.md).
# Usage: check-brief.sh <onboarding-dir>
# Exit 0 = no FAIL. Exit 1 = at least one FAIL. Exit 2 = bad usage.
# Prints "FAIL <rule>: <detail>" and "WARN <rule>: <detail>". It never prints a matched secret.
set -u

# Invalid bytes (for example Windows-1252 text pasted into a brief) make grep, sed and awk fail under a UTF-8
# locale, and awk echoes the whole line in its error. The C locale reads bytes and never fails.
export LC_ALL=C

if [ $# -ne 1 ]; then
  echo "usage: check-brief.sh <onboarding-dir>" >&2
  exit 2
fi

DIR=$1
README="$DIR/README.md"
FAILS=0
WARNS=0
SECTIONS=("First-ticket checklist" "Purpose and users" "Use cases" "Architecture and patterns" "Data model" \
  "External systems" "Run and verify" "Risks and delivery" "Unknowns")

fail() { printf 'FAIL %s: %s\n' "$1" "$2"; FAILS=$((FAILS + 1)); }
warn() { printf 'WARN %s: %s\n' "$1" "$2"; WARNS=$((WARNS + 1)); }

# strip_fences: README.md without fenced code blocks, so a "## " line inside one is not read as a heading.
strip_fences() { awk '/^(```|~~~)/ { f = !f; next } !f' "$README"; }

# section_text <name>: the lines under "## <name>" up to the next H2.
section_text() {
  strip_fences | awk -v h="## $1" '{ sub(/[[:space:]]+$/, "") } $0 == h { on = 1; next } /^## / { on = 0 } on'
}

# h2_names: every H2 heading in README.md, in order, without the "## ".
h2_names() { strip_fences | grep -E '^## ' | sed 's/^## //; s/[[:space:]]*$//'; }

# R1
if [ ! -f "$README" ]; then
  fail R1 "$README does not exist"
  exit 1
fi

# R2
grep -Eq '^Scanned commit: [0-9a-f]{7,40}[[:space:]]*$' "$README" ||
  fail R2 "header line 'Scanned commit: <7 to 40 hex characters>' is missing or malformed"
grep -Eq '^Scanned on: [0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]]*$' "$README" ||
  fail R2 "header line 'Scanned on: YYYY-MM-DD' is missing or malformed"
grep -Eq '^Working tree: (clean|dirty)[[:space:]]*$' "$README" ||
  fail R2 "header line 'Working tree: clean|dirty' is missing or malformed"

# R3
CHECKLIST=$(section_text "First-ticket checklist")
n=1
while [ "$n" -le 8 ]; do
  item=$(printf '%s\n' "$CHECKLIST" | grep -E "^$n\. " | head -1)
  if [ -z "$item" ]; then
    fail R3 "checklist item $n is missing"
  elif ! printf '%s\n' "$item" | grep -Eq '\[[^]]+\]\([^)]+\)|unknown:'; then
    fail R3 "checklist item $n has no link and no 'unknown:'"
  fi
  n=$((n + 1))
done

# R4
prev=0
for name in "${SECTIONS[@]}"; do
  pos=$(h2_names | awk -v n="$name" '$0 == n { print NR; exit }')
  if [ -z "$pos" ]; then
    fail R4 "section '$name' is missing"
  elif [ "$pos" -le "$prev" ]; then
    fail R4 "section '$name' is out of order"
  else
    prev=$pos
  fi
done

# R5
while IFS= read -r name; do
  case "$name" in "" | "First-ticket checklist" | "Unknowns") continue ;; esac
  src=$(section_text "$name" | grep -m1 '^Sources:')
  if [ -z "$src" ]; then
    fail R5 "section '$name' has no 'Sources:' line"
  elif ! printf '%s\n' "$src" | grep -Eq '[/.]|told by|unknown:'; then
    warn R5 "section '$name' has a 'Sources:' line with no path, 'told by' or 'unknown:'"
  fi
done <<<"$(h2_names)"

# R6: scans every .md file in the folder. A valid Scanned commit line is skipped; its hash is not a secret.
for f in "$DIR"/*.md; do
  base=$(basename "$f")
  hits=$(grep -n -i -E -e 'password=|pwd=|accountkey=|sharedaccesskey=|-----BEGIN' "$f" | cut -d: -f1)
  provider=$(grep -n -E -e 'xox[abprs]-[A-Za-z0-9-]{10,}' -e 'sk_(live|test)_[A-Za-z0-9]{8,}' -e 'AKIA[0-9A-Z]{16}' \
    -e 'gh[pousr]_[A-Za-z0-9]{20,}' -e 'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.' "$f" | cut -d: -f1)
  tokens=$(sed -E 's/^Scanned commit: [0-9a-f]{7,40}[[:space:]]*$//' "$f" |
    grep -n -o -E '[A-Za-z0-9+=]{32,}' | grep -E '^[0-9]+:[A-Za-z0-9+=]*[0-9]' | cut -d: -f1)
  lines=$(printf '%s\n%s\n%s\n' "$hits" "$provider" "$tokens" | grep -E '^[0-9]+$' | sort -un | tr '\n' ',' | sed 's/,$//')
  [ -z "$lines" ] || fail R6 "$base: secret-like text on line(s) $lines (value not shown)"
done

# R7: relative *.md links, in the plain, titled ("x.md \"t\"") and angle-bracket (<x.md>) inline forms.
links=$(strip_fences | grep -oE '\]\(<?[^)<> "#]+\.md[)#> "]' | sed -E 's/^\]\(<?//; s/\.md[)#> "]$/.md/')
while IFS= read -r target; do
  [ -n "$target" ] || continue
  case "$target" in *://* | mailto:*) continue ;; esac
  [ -f "$DIR/$target" ] || fail R7 "link target '$target' does not exist"
done <<<"$links"

# R8
words=$(wc -w <"$README" | tr -d ' ')
[ "$words" -le 2400 ] || warn R8 "README.md has $words words; the soft target is about 2000"

printf 'checked %s: %d failure(s), %d warning(s)\n' "$README" "$FAILS" "$WARNS"
[ "$FAILS" -eq 0 ]
