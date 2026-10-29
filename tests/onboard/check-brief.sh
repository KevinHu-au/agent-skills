#!/usr/bin/env bash
# Deterministic checks for an onboarding brief (docs/onboarding/README.md).
# Usage: check-brief.sh <onboarding-dir> [<repo-root>]
# With a repo root (the top of a git repository), R9 checks the paths and R10 the search terms against it.
# Exit 0 = no FAIL. Exit 1 = at least one FAIL. Exit 2 = bad usage.
# Prints "FAIL <rule>: <detail>" and "WARN <rule>: <detail>". It never prints a matched secret.
set -u

# Invalid bytes (for example Windows-1252 text pasted into a brief) make grep, sed and awk fail under a UTF-8
# locale, and awk echoes the whole line in its error. The C locale reads bytes and never fails.
export LC_ALL=C

usage() {
  echo "usage: check-brief.sh <onboarding-dir> [<repo-root>]" >&2
  exit 2
}
[ $# -eq 1 ] || [ $# -eq 2 ] || usage

DIR=$1
# The root is the git toplevel, as git reports it: on macOS, mktemp -d gives /var/... but git reports /private/var/...,
# and git returns the real letter case of the folder. The argument must be that toplevel (an empty prefix).
ROOT=""
if [ $# -eq 2 ]; then
  [ -n "$2" ] || usage
  ROOT=$(git -C "$2" rev-parse --show-toplevel 2>/dev/null) || {
    echo "check-brief.sh: '$2' is not a git repository" >&2
    usage
  }
  prefix=$(git -C "$2" rev-parse --show-prefix 2>/dev/null)
  [ -z "$prefix" ] || {
    echo "check-brief.sh: '$2' is a subfolder of the repository at '$ROOT', not its top" >&2
    usage
  }
fi
README="$DIR/README.md"
FAILS=0
WARNS=0
SECTIONS=("First-ticket checklist" "Purpose and users" "Use cases" "Start here" "Architecture and patterns" \
  "Data model" "External systems" "Run and verify" "Risks and delivery" "Unknowns")

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
while [ "$n" -le 9 ]; do
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

# The secret patterns, in one place. R6 scans files with them and looks_secret tests a single value with them.
# Keywords match in any case. The provider shapes are case-sensitive. A long token must also hold a digit.
# A long token is flagged when it holds a digit, except a plain identifier: letters, then at most four trailing digits
# (for example GetCustomerOrderSummaryForPeriod2024). Hex, base64-like, digits in the middle, or five or more
# trailing digits are still flagged.
SECRET_KEYWORDS='password=|pwd=|accountkey=|sharedaccesskey=|-----BEGIN'
SECRET_PROVIDER_ARGS=(-e 'xox[abprs]-[A-Za-z0-9-]{10,}' -e 'sk_(live|test)_[A-Za-z0-9]{8,}' -e 'AKIA[0-9A-Z]{16}'
  -e 'gh[pousr]_[A-Za-z0-9]{20,}' -e 'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.')
SECRET_TOKEN='[A-Za-z0-9+=]{32,}'
SECRET_PLAIN_IDENT='^[A-Za-z]+[0-9]{0,4}$'

# R6: scans every .md file in the folder. A valid Scanned commit line is skipped; its hash is not a secret.
for f in "$DIR"/*.md; do
  base=$(basename "$f")
  hits=$(grep -n -i -E -e "$SECRET_KEYWORDS" "$f" | cut -d: -f1)
  provider=$(grep -n -E "${SECRET_PROVIDER_ARGS[@]}" "$f" | cut -d: -f1)
  tokens=$(sed -E 's/^Scanned commit: [0-9a-f]{7,40}[[:space:]]*$//' "$f" |
    grep -n -o -E "$SECRET_TOKEN" | grep -E '^[0-9]+:[A-Za-z0-9+=]*[0-9]' |
    grep -v -E "^[0-9]+:${SECRET_PLAIN_IDENT#^}" | cut -d: -f1)
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

# R11 and R12 apply only when the brief has a "Start here" section.
if h2_names | grep -qx 'Start here'; then
  # R11: read the raw file, not strip_fences, because the diagram is a fenced block.
  # It tracks fences itself, so a "## " line inside a fenced block does not end the section.
  start_raw=$(awk '{ sub(/[[:space:]]+$/, "") } !f && $0 == "## Start here" { on = 1; next } !f && /^## / { on = 0 }
    /^(```|~~~)/ { f = !f } on' "$README")
  mermaid=$(printf '%s\n' "$start_raw" | grep -Ec '^(```|~~~)mermaid')
  if [ "$mermaid" -gt 1 ]; then
    fail R11 "'Start here' has $mermaid mermaid blocks; it needs exactly one"
  elif [ "$mermaid" -eq 0 ] && ! printf '%s\n' "$start_raw" | grep -q '^Key concept: unknown:'; then
    fail R11 "'Start here' has no mermaid block and no 'Key concept: unknown:' line"
  fi

  # R12
  [ -f "$DIR/feature-to-code.md" ] || fail R12 "feature-to-code.md does not exist"
  section_text "Start here" | grep -Eq '\]\(<?(\./)?feature-to-code\.md' ||
    fail R12 "'Start here' has no link to feature-to-code.md"
fi

# R8
words=$(wc -w <"$README" | tr -d ' ')
[ "$words" -le 2400 ] || warn R8 "README.md has $words words; the soft target is about 2000"

# R9 and R10 read backticked values only. Header and separator rows, and cells that start with the token none,
# unknown: or inferred:, are skipped. "none" is a token only when no letter follows it. A "changed: " before a
# backticked value is not part of the value, and "changed: inferred: ..." is skipped like "inferred: ...".

# TICKS_AWK: awk functions shared by the readers below.
TICKS_AWK='
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
function ticks(s, tag) { while (match(s, /`[^`]+`/)) { print tag trim(substr(s, RSTART + 1, RLENGTH - 2)); s = substr(s, RSTART + RLENGTH) } }
'

# start_unreadable: one line for each Open: or Pattern: line in Start here with no backticked value, and no
# none, unknown: or inferred: marker either. Such a line is not read by start_paths, so R9 would check nothing.
start_unreadable() {
  section_text "Start here" | awk '
    /^([-*][ \t]+)?(\*\*)?(Open|Pattern)(:\*\*|\*\*:|:)/ {
      v = $0
      sub(/^([-*][ \t]+)?(\*\*)?(Open|Pattern)(:\*\*|\*\*:|:)[ \t]*(\*\*)?[ \t]*/, "", v)
      if (v ~ /`[^`]+`/ || v ~ /^(none([^A-Za-z]|$)|unknown:|inferred:)/) next
      l = $0
      sub(/^([-*][ \t]+)?(\*\*)?/, "", l)
      sub(/(:\*\*|\*\*:|:).*$/, "", l)
      print l
    }'
}

# f2c_unreadable: the title of each "## " block in feature-to-code.md with no table row (a line that starts with a
# pipe) outside code fences. A table without leading pipes is valid Markdown, but f2c_values cannot read it.
f2c_unreadable() {
  awk '
    { gsub(/\r/, "") }
    /^(```|~~~)/ { fence = !fence; next }
    fence { next }
    /^## / { if (title != "" && !rows) print title; title = substr($0, 4); rows = 0; next }
    /^\|/ { rows = 1 }
    END { if (title != "" && !rows) print title }
  ' "$DIR/feature-to-code.md"
}

# start_paths: "README.md<TAB><value>" for each backticked value on an Open: or Pattern: line in Start here. The
# line may start with "- " or "* ", and the label may be bold: "**Open:**" or "**Open**:". Run: is never read.
start_paths() {
  section_text "Start here" | awk "$TICKS_AWK"'/^([-*][ \t]+)?(\*\*)?(Open|Pattern)(:\*\*|\*\*:|:)/ { ticks($0, "README.md\t") }'
}

# f2c_values <path|term>: backticked values in feature-to-code.md. Paths: the second and third cells of the data
# rows under each H2, except under "### Search terms". Terms: cells from the second onward under "### Search terms".
f2c_values() {
  awk -v want="$1" "$TICKS_AWK"'
    { gsub(/\r/, "") }
    /^(```|~~~)/ { fence = !fence; next }
    fence { next }
    /^## / { mode = "path"; rows = 0; next }
    /^### Search terms[ \t]*$/ { mode = "term"; rows = 0; next }
    /^### / { mode = "path"; rows = 0; next }
    !/^\|/ { rows = 0; next }
    { rows++ }
    mode != want || rows == 1 { next }
    { t = $0; gsub(/[ \t:|-]/, "", t); if (t == "") next }
    {
      # An escaped pipe stays inside its cell, and is the rendered text, a plain pipe.
      gsub(/\\\|/, "\001")
      n = split($0, c, "|")
      last = (want == "path") ? 4 : n
      for (i = 3; i <= last && i <= n; i++) {
        cell = trim(c[i])
        gsub(/\001/, "|", cell)
        head = cell
        sub(/^changed:[ \t]*/, "", head)
        if (head ~ /^(none([^A-Za-z]|$)|unknown:|inferred:)/) continue
        ticks(cell, "feature-to-code.md\t")
      }
    }
  ' "$DIR/feature-to-code.md"
}

# looks_secret <value>: true when R6 would flag the value, so it is never printed.
looks_secret() {
  printf '%s\n' "$1" | grep -Eiq -e "$SECRET_KEYWORDS" && return 0
  printf '%s\n' "$1" | grep -Eq "${SECRET_PROVIDER_ARGS[@]}" && return 0
  printf '%s\n' "$1" | grep -o -E "$SECRET_TOKEN" | grep '[0-9]' | grep -v -E "$SECRET_PLAIN_IDENT" | grep -q .
}

# shown <value>: the value for a message, or a placeholder when it looks like a secret.
shown() { if looks_secret "$1"; then printf '(value not shown)'; else printf '%s' "$1"; fi; }

# check_path <file> <value>: R9 for one path, in the form path, path:N or path:N-M.
check_path() {
  local file=$1 value=$2 p line_re start end count
  p=${value#./}
  line_re='^(.+):([0-9]+)(-([0-9]+))?$'
  if [[ $p =~ $line_re ]]; then
    p=${BASH_REMATCH[1]}
    start=${BASH_REMATCH[2]}
    end=${BASH_REMATCH[4]:-$start}
    # [ -gt ] fails on a number past the shell's integer size, so a long number is a FAIL here.
    if [ "${#start}" -gt 9 ] || [ "${#end}" -gt 9 ]; then
      fail R9 "$file: '$(shown "$value")' has a line number with more than 9 digits"
      return
    fi
  else
    start=""
    end=""
  fi
  if [[ /$p/ == *"/../"* ]]; then
    fail R9 "$file: '$(shown "$value")' leaves the repository root"
  elif [ ! -e "$ROOT/$p" ]; then
    fail R9 "$file: '$(shown "$value")' does not exist under the repository root"
  elif [ -n "$end" ] && [ -d "$ROOT/$p" ]; then
    fail R9 "$file: '$(shown "$value")' is a folder, so it cannot have a line number"
  elif [ -n "$end" ] && [ "$start" -gt "$end" ]; then
    fail R9 "$file: '$(shown "$value")' has a line range that starts after it ends"
  elif [ -n "$end" ]; then
    count=$(awk 'END { print NR }' "$ROOT/$p")
    { [ "$end" -ge 1 ] && [ "$end" -le "$count" ]; } ||
      fail R9 "$file: '$(shown "$value")' is outside the file, which has $count line(s)"
  fi
}

if [ -z "$ROOT" ]; then
  echo "NOTE R9: skipped, no repository root"
  echo "NOTE R10: skipped, no repository root"
else
  # R9. The existence check is test -e, so it passes a path that git ignores. R10 uses git grep --untracked, which
  # does not search ignored files, so a term found only in an ignored file fails. The difference is on purpose.
  while IFS= read -r label; do
    [ -n "$label" ] || continue
    warn R9 "README.md: a '$label:' line in Start here has no backticked value, so it is not checked"
  done <<<"$(start_unreadable)"
  if [ -f "$DIR/feature-to-code.md" ]; then
    while IFS= read -r title; do
      [ -n "$title" ] || continue
      warn R9 "feature-to-code.md: the block '$title' has no table row that starts with a pipe, so it is not checked"
    done <<<"$(f2c_unreadable)"
  fi
  paths=$(start_paths; [ ! -f "$DIR/feature-to-code.md" ] || f2c_values path)
  while IFS=$'\t' read -r file value; do
    [ -n "$value" ] || continue
    check_path "$file" "$value"
  done <<<"$paths"

  # R10: the pack is excluded, or every term would match inside feature-to-code.md itself.
  # Git names the pack's repository and its folder inside it, so symlinks and letter case do not matter. When the
  # pack folder is the root itself, only feature-to-code.md is excluded.
  PACK_REL=""
  PACK_EXCLUDE=""
  pack_top=$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null)
  if [ "$pack_top" = "$ROOT" ]; then
    PACK_REL=$(git -C "$DIR" rev-parse --show-prefix)
    PACK_REL=${PACK_REL%/}
    if [ -n "$PACK_REL" ]; then PACK_EXCLUDE=$PACK_REL; else PACK_EXCLUDE=feature-to-code.md; fi
  else
    echo "NOTE R10: onboarding folder is outside the root, no exclusion"
  fi
  terms=""
  [ ! -f "$DIR/feature-to-code.md" ] || terms=$(f2c_values term)
  while IFS=$'\t' read -r file term; do
    [ -n "$term" ] || continue
    if [ -n "$PACK_EXCLUDE" ]; then
      git -C "$ROOT" grep --untracked -F -q -- "$term" -- . ":(top,exclude,literal)$PACK_EXCLUDE"
    else
      git -C "$ROOT" grep --untracked -F -q -- "$term" -- .
    fi
    rc=$?
    if [ "$rc" -eq 1 ]; then
      fail R10 "'$(shown "$term")' not found outside ${PACK_EXCLUDE:-the root}"
    elif [ "$rc" -ne 0 ]; then
      fail R10 "'$(shown "$term")' could not be searched (git grep exit $rc)"
    fi
  done <<<"$terms"
fi

printf 'checked %s: %d failure(s), %d warning(s)\n' "$README" "$FAILS" "$WARNS"
[ "$FAILS" -eq 0 ]
