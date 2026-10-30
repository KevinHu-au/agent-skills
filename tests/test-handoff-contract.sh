#!/usr/bin/env bash
# Checks the contract between the skills that write a hand-off block and agentd-dev-rev, which reads it. Every H2
# heading in the diagnose hand-off block and in the blast-radius add-on block, and every field line of the intake
# engineer block, must be named in the Inputs section of agentd-dev-rev. A heading added to a template without a
# matching rule in dev-rev fails here. Reads files and writes nothing.
# Usage: tests/test-handoff-contract.sh
set -u

HERE=$(cd "$(dirname "$0")" && pwd -P)
SKILLS="$HERE/../skills"
DEV="$SKILLS/agentd-dev-rev/SKILL.md"
DIAGNOSE_TEMPLATE="$SKILLS/agentd-diagnose/references/report-template.md"
BLAST_TEMPLATE="$SKILLS/agentd-blast-radius/references/report-template.md"
INTAKE_TEMPLATE="$SKILLS/agentd-intake/references/comment-template.md"
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

# block_h2s <template>: the H2 headings inside the four-backtick markdown fence of a report template (the hand-off
# block, or the add-on block).
block_h2s() {
  awk '
    $0 == "````" { on = 0 }
    on && /^## / { sub(/^## /, ""); print }
    $0 == "````markdown" { on = 1 }
  ' "$1"
}

# inputs: the Inputs section of agentd-dev-rev as one line.
inputs() {
  awk '
    /^[ ]*(```|~~~)/ { f = !f }
    !f && $0 == "## Inputs" { on = 1; next }
    !f && /^## / { on = 0 }
    on
  ' "$DEV" | tr '\n' ' ' | tr -s ' '
}

# names_every_heading <template>: dev-rev Inputs names each H2 heading of the block as `## <heading>`.
names_every_heading() {
  local tpl=$1 h body
  body=$(inputs)
  [ -s "$tpl" ] && [ -n "$body" ] || return 1
  [ "$(block_h2s "$tpl" | wc -l | tr -d ' ')" -ge 6 ] || return 1
  while IFS= read -r h; do
    printf '%s\n' "$body" | grep -qF -- "\`## $h\`" || { printf 'missing: %s\n' "$h" >&2; return 1; }
  done < <(block_h2s "$tpl")
}

# template_has <template> <text>...: the template contains every text.
template_has() {
  local f=$1 t
  shift
  [ -s "$f" ] || return 1
  for t in "$@"; do grep -qF -- "$t" "$f" || return 1; done
}

# inputs_has <text>...: the Inputs section contains every text.
inputs_has() {
  local body t
  body=$(inputs)
  [ -n "$body" ] || return 1
  for t in "$@"; do printf '%s\n' "$body" | grep -qF -- "$t" || return 1; done
}

test_diagnose_headings_are_named() { names_every_heading "$DIAGNOSE_TEMPLATE"; }
test_blast_radius_headings_are_named() { names_every_heading "$BLAST_TEMPLATE"; }

# The diagnose Stop condition section sits outside the fenced block, so it is checked on its own.
test_diagnose_stop_condition_is_named() {
  template_has "$DIAGNOSE_TEMPLATE" '## Stop condition' && inputs_has '`## Stop condition`'
}

test_verdict_lines_are_named() {
  template_has "$DIAGNOSE_TEMPLATE" '**Confidence:** confirmed' 'hypothesis, not confirmed' &&
    template_has "$BLAST_TEMPLATE" '**Blast radius:** Contained | Breaks | Unproven' &&
    inputs_has '`**Confidence:**`' 'hypothesis, not confirmed' '`**Blast radius:**`' '`Contained`' '`Breaks`' '`Unproven`'
}

test_diagnose_blast_radius_values_are_named() {
  template_has "$DIAGNOSE_TEMPLATE" 'needed: <' 'not needed: <' && inputs_has '`needed:`' '`not needed:`'
}

test_intake_fields_are_named() {
  template_has "$INTAKE_TEMPLATE" 'Requirement: confirmed | unconfirmed' 'Assumptions: <' 'Stop condition: <' &&
    inputs_has 'Requirement: unconfirmed' '`Stop condition:`' '`Assumptions:`'
}

check "dev-rev names every heading of the diagnose hand-off block" test_diagnose_headings_are_named
check "dev-rev names every heading of the blast-radius add-on block" test_blast_radius_headings_are_named
check "dev-rev names the diagnose Stop condition section" test_diagnose_stop_condition_is_named
check "dev-rev names the confidence and verdict lines" test_verdict_lines_are_named
check "dev-rev names the needed: and not needed: values" test_diagnose_blast_radius_values_are_named
check "dev-rev names the intake Requirement, Assumptions and Stop condition fields" test_intake_fields_are_named

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
