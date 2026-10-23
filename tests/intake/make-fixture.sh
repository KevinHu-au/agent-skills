#!/usr/bin/env bash
# Builds the fixture for agentd-intake: the diagnose fixture (tests/diagnose/make-fixture.sh, not changed), plus a
# small onboarding pack in one more commit. The pack is docs/onboarding/README.md, which links to
# docs/onboarding/glossary.md. The glossary maps the words the tickets in tests/intake/tickets use to the code.
# Usage: make-fixture.sh <dest>
#   <dest> must not exist. Prints "head <hash>".
# Uses the same clean git environment as the diagnose builder, so the hash is the same on every build.
# Needs bash, git and Python 3. Exit: 0 = built, 1 = destination exists, 2 = bad arguments.
set -eu

HERE=$(cd "$(dirname "$0")" && pwd -P)

if [ $# -ne 1 ]; then
  echo "usage: make-fixture.sh <dest>" >&2
  exit 2
fi
DEST=$1
if [ -e "$DEST" ]; then
  echo "make-fixture.sh: $DEST already exists" >&2
  exit 1
fi

bash "$HERE/../diagnose/make-fixture.sh" "$DEST" >/dev/null

for v in $(env | sed -n 's/^\(GIT_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$v"; done
unset EMAIL
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
g() { git -C "$DEST" -c core.hooksPath=/dev/null -c core.excludesFile=/dev/null -c commit.gpgsign=false "$@"; }
SCANNED=$(g rev-parse HEAD)

mkdir -p "$DEST/docs/onboarding"

cat >"$DEST/docs/onboarding/README.md" <<EOF
Scanned commit: $SCANNED
Scanned on: 2026-05-04

# Shop: onboarding brief

## Purpose and users

An order and invoicing tool for a wholesaler, used from the command line. The support desk runs it for the
wholesaler's staff. The finance team receives the invoice file each week.

## Use cases

1. Price an order: \`python3 -m shop total <order id>\`.
2. List the accounts: \`python3 -m shop customers\`.
3. Run the yearly revenue report: \`python3 -m shop report <year>\`.
4. Send an account's invoice file to finance: \`python3 -m shop export <customer id> <file>\`.

## Glossary

The customer's words and where they live in the code: see [the glossary](glossary.md).

## Contract

Commands, risk areas and external systems are in \`AGENTS.md\`, under "Project contract".
EOF

cat >"$DEST/docs/onboarding/glossary.md" <<EOF
Scanned commit: $SCANNED
Scanned on: 2026-05-04

# Glossary

| Customer's word | Meaning | Where in the code |
|---|---|---|
| account | a customer of the wholesaler | table \`customers\`, \`shop/customers.py\` |
| discount | a coupon taken off an order | table \`coupons\`, \`shop/pricing.py\` |
| invoice file | the invoice CSV sent to finance, one row per order | \`shop/export.py\`, \`python3 -m shop export\` |
| revenue report | the yearly revenue for each account | \`shop/reports.py\`, \`python3 -m shop report <year>\` |
EOF

g add -A
GIT_AUTHOR_DATE=2026-05-04T09:00:00+10:00 GIT_COMMITTER_DATE=2026-05-04T09:00:00+10:00 \
  g commit -q -m 'Add onboarding pack'
echo "head $(g rev-parse HEAD)"
