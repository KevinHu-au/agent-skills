#!/usr/bin/env bash
# Builds three small synthetic git repositories to test agentd-review-rubric.
# Usage: make-fixture.sh <dest>
#   <dest> must not exist. It gets three repositories, each with one commit on main:
#   a  has CONTRIBUTING.md, a PR template and a lint config, and no rubric, no onboarding pack.
#   b  has only a README with no norms, and no rubric.
#   c  has a rubric already, as a "## Review rubric" section in AGENTS.md.
# The scoring key is the table in tests/review-rubric/EVAL.md. Nothing in a fixture names the answers.
# The fixture uses a fake local identity, ignores your git config, global ignore file, hooks and environment
# variables, and uses fixed commit dates, so the hashes are the same on every build.
# Needs bash and git 2.32 or later (for GIT_CONFIG_GLOBAL). Exit: 0 = built, 1 = destination exists, 2 = bad arguments.
set -eu

if [ $# -ne 1 ]; then
  echo "usage: make-fixture.sh <dest>" >&2
  exit 2
fi
DEST=$1
if [ -e "$DEST" ]; then
  echo "make-fixture.sh: $DEST already exists" >&2
  exit 1
fi

for v in $(env | sed -n 's/^\(GIT_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$v"; done
unset EMAIL
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=fixture@example.invalid
export GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL=fixture@example.invalid
export GIT_AUTHOR_DATE="2026-01-01T00:00:00Z" GIT_COMMITTER_DATE="2026-01-01T00:00:00Z"

# w <repo> <relative-path>: write stdin to that file inside the repository.
w() {
  mkdir -p "$(dirname "$DEST/$1/$2")"
  cat >"$DEST/$1/$2"
}

# commit <repo>: start the repository on main and make its one commit.
commit() {
  git -C "$DEST/$1" init -q -b main
  git -C "$DEST/$1" add -A
  git -C "$DEST/$1" -c core.hooksPath=/dev/null -c commit.gpgsign=false commit -q -m "Initial commit"
}

mkdir -p "$DEST"

# ---- a: norms in files, no rubric
w a README.md <<'EOF'
# Orders service

A small web API for customer orders. See CONTRIBUTING.md before you open a PR.
EOF
w a CONTRIBUTING.md <<'EOF'
# Contributing

- Every new controller action names the roles that may call it.
- Never edit a migration that has already run. Add a new one.
- Money amounts use the Money type, never a float.
- Keep commits small and write a clear message.
- Write clean code.
EOF
w a .github/pull_request_template.md <<'EOF'
## What changed

## How it was tested

- [ ] Unit tests added or updated
- [ ] No migration was edited
EOF
w a .eslintrc.json <<'EOF'
{ "rules": { "semi": "error", "quotes": ["error", "single"], "indent": ["error", 2] } }
EOF
w a src/Api/Controllers/OrdersController.cs <<'EOF'
public class OrdersController { }
EOF
w a db/migrations/001_create_orders.sql <<'EOF'
CREATE TABLE orders (id INT);
EOF
commit a

# ---- b: no norms at all
w b README.md <<'EOF'
# Notes app

Stores notes.
EOF
w b src/notes.py <<'EOF'
def add(note):
    return note
EOF
commit b

# ---- c: a rubric already exists in AGENTS.md
w c README.md <<'EOF'
# Reports tool
EOF
w c AGENTS.md <<'EOF'
# Agent guide

## Review rubric

### R1: Reports never write
- Rule: A report query never changes data.
- Applies to: src/reports/**
- Severity: Block
- How to check: Read each new query in the diff for INSERT, UPDATE or DELETE.
- Source: told by the tech lead
EOF
w c src/reports/daily.py <<'EOF'
def run():
    return []
EOF
commit c

echo "built a b c under $DEST"
