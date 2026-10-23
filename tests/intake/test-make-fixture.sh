#!/usr/bin/env bash
# Tests for tests/intake/make-fixture.sh: the intake fixture is the diagnose fixture plus a small onboarding pack in
# one more commit, it builds the same way every time, and the lines that expected-findings.md cites hold their facts.
# Builds into a throwaway folder from mktemp. Nothing is deleted; the folders are listed at the end.
# Usage: tests/intake/test-make-fixture.sh
set -u

HERE=$(cd "$(dirname "$0")" && pwd -P)
BUILDER="$HERE/make-fixture.sh"
DIAGNOSE_HEAD=6458ad8b5eb5574d684c3cbd31e272fcde6a93b2
# The scoring key (expected-findings.md) is written for this commit. If the builder changes on purpose, update the
# key and this hash together.
INTAKE_HEAD=a0156d30a93c85924b8417fc65b1f75563318ff0
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

ROOT=$(mktemp -d)
[ -n "$ROOT" ] && [ -d "$ROOT" ] || { echo "mktemp -d failed" >&2; exit 1; }
F="$ROOT/shop"
OUT1=$(bash "$BUILDER" "$F" 2>&1)
STATUS1=$?
OUT2=$(bash "$BUILDER" "$ROOT/shop2" 2>&1)

# line_has <path:line> <text>: that line of the fixture contains the text.
line_has() {
  local f=${1%:*} n=${1##*:}
  sed -n "${n}p" "$F/$f" | grep -qF -- "$2"
}

test_bad_arguments_exit_2() {
  bash "$BUILDER" >/dev/null 2>&1
  [ $? -eq 2 ] || return 1
  bash "$BUILDER" "$ROOT/a" "$ROOT/b" >/dev/null 2>&1
  [ $? -eq 2 ]
}

test_existing_destination_exits_1() {
  bash "$BUILDER" "$F" >/dev/null 2>&1
  [ $? -eq 1 ]
}

test_build_has_the_pack_and_a_clean_tree() {
  local p
  [ "$STATUS1" -eq 0 ] || return 1
  for p in docs/onboarding/README.md docs/onboarding/glossary.md; do
    [ "$(sed -n 1p "$F/$p")" = "Scanned commit: $DIAGNOSE_HEAD" ] || return 1
    [ "$(sed -n 2p "$F/$p")" = "Scanned on: 2026-05-04" ] || return 1
  done
  grep -qF '(glossary.md)' "$F/docs/onboarding/README.md" &&
    [ -z "$(git -C "$F" status --porcelain)" ]
}

test_parent_is_the_pinned_diagnose_head() {
  [ "$(git -C "$F" rev-parse HEAD~1)" = "$DIAGNOSE_HEAD" ] &&
    [ "$(git -C "$F" log -1 --format=%s)" = "Add onboarding pack" ]
}

test_two_builds_have_the_same_pinned_head() {
  printf '%s\n' "$OUT1" | grep -qE '^head [0-9a-f]{40}$' && [ "$OUT1" = "$OUT2" ] &&
    [ "$OUT1" = "head $INTAKE_HEAD" ]
}

test_glossary_maps_the_ticket_words() {
  local g="$F/docs/onboarding/glossary.md"
  grep -qiE '^\| account \|.*customer' "$g" &&
    grep -qiE '^\| discount \|.*coupon' "$g" &&
    grep -qiE '^\| invoice file \|.*CSV' "$g" &&
    grep -qiE '^\| revenue report \|.*report' "$g"
}

test_the_expected_lines_hold_their_facts() {
  line_has shop/pricing.py:13 'amount_cents' &&
    line_has shop/pricing.py:20 'apply_coupon' &&
    line_has shop/reports.py:14 'load_coupon' &&
    line_has shop/reports.py:25 'order_total(lines, coupon)' &&
    line_has shop/export.py:18 'WHERE customer_id' &&
    line_has shop/export.py:23 '"customer", "order_id", "date", "total"' &&
    line_has shop/export.py:26 'created_at[:10]' &&
    line_has shop/customers.py:22 'ORDER BY id' &&
    line_has shop/db.py:18 'amount_cents INTEGER' &&
    line_has shop/db.py:24 'coupon_code' &&
    line_has scripts/seed_db.py:16 '("TEN", "percent", None, 10)' &&
    line_has shop/__main__.py:15 'customers' &&
    line_has shop/__main__.py:18 'report' &&
    line_has shop/__main__.py:21 'export'
}

check "no argument or two arguments exit 2" test_bad_arguments_exit_2
check "an existing destination exits 1" test_existing_destination_exits_1
check "the build has the onboarding pack and a clean tree" test_build_has_the_pack_and_a_clean_tree
check "the parent commit is the pinned diagnose head" test_parent_is_the_pinned_diagnose_head
check "two builds have the same pinned head" test_two_builds_have_the_same_pinned_head
check "the glossary maps the ticket words" test_glossary_maps_the_ticket_words
check "the lines cited in expected-findings.md hold their facts" test_the_expected_lines_hold_their_facts

echo
echo "passed=$PASS failed=$FAIL"
echo "temp folders left in place: $ROOT"
[ "$FAIL" -eq 0 ]
