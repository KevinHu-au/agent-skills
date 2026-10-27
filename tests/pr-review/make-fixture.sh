#!/usr/bin/env bash
# Builds a small synthetic git repository, a Python project list with three screens, to test agentd-pr-review.
# Usage: make-fixture.sh <dest>
#   <dest> must not exist. The build makes two commits on main and one on the branch pr/42-hide-archived-projects,
#   writes remote refs for origin/main and the PR branch, and leaves HEAD on the PR branch, as if the engineer had
#   checked it out.
# Prints "head <hash>", the hash of the PR branch.
# The work item is tests/pr-review/work-item.md. The scoring key is tests/pr-review/expected-findings.md. Nothing in
# the fixture itself names the answers.
# The fixture uses a fake local identity, ignores your git config, global ignore file, hooks and environment
# variables, and uses fixed commit dates, so the hash is the same on every build.
# Needs bash, git 2.32 or later (for GIT_CONFIG_GLOBAL) and Python 3. Exit: 0 = built, 1 = destination exists,
# 2 = bad arguments.
set -eu

usage() { echo "usage: make-fixture.sh <dest>" >&2; }

if [ $# -ne 1 ]; then
  usage
  exit 2
fi
DEST=$1
if [ -e "$DEST" ]; then
  echo "make-fixture.sh: $DEST already exists" >&2
  exit 1
fi

# Start from a clean git environment. Nothing the caller exported (GIT_AUTHOR_*, GIT_DIR, EMAIL, ...) or keeps in
# a global config or global ignore file may change the fixture or its hash.
for v in $(env | sed -n 's/^\(GIT_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$v"; done
unset EMAIL
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export PYTHONDONTWRITEBYTECODE=1
g() { git -C "$DEST" -c core.hooksPath=/dev/null -c core.excludesFile=/dev/null -c commit.gpgsign=false "$@"; }

# w <relative-path>: write stdin to that file inside the fixture.
w() {
  mkdir -p "$(dirname "$DEST/$1")"
  cat >"$DEST/$1"
}

# commit <date> <message>: commit everything. Call it on its own line, never inside $(...): set -e is off there,
# so a failed commit would go unnoticed.
commit() {
  g add -A
  GIT_AUTHOR_DATE=$1 GIT_COMMITTER_DATE=$1 g commit -q -m "$2"
}

mkdir -p "$DEST"
g init -q -b main
g config user.name "Fixture Author"
g config user.email "fixture@example.invalid"

# ---------------------------------------------------------------- main, commit 1: the app

w .gitignore <<'EOF'
__pycache__/
EOF

w app/__init__.py </dev/null
w app/projects.py <<'EOF'
"""The project list. Status is one of Active, Closed or Archived."""

PROJECTS = [
    {"id": 1, "code": "P001", "name": "North Road", "status": "Active"},
    {"id": 2, "code": "P002", "name": "River Bridge", "status": "Archived"},
    {"id": 3, "code": "P003", "name": "Harbour Wall", "status": "Closed"},
    {"id": 4, "code": "P004", "name": "Hill Tunnel", "status": "Active"},
]


def all_projects():
    return [dict(p) for p in PROJECTS]
EOF

w screens/__init__.py </dev/null
w screens/dashboard.py <<'EOF'
"""Dashboard screen: one row per project."""
from app.projects import all_projects


def rows():
    return [p["code"] for p in all_projects()]
EOF

w screens/reports.py <<'EOF'
"""Reports screen: a table on screen and a CSV export."""
from app.projects import all_projects


def report_rows():
    return [(p["code"], p["name"]) for p in all_projects()]


def export_csv():
    lines = ["code,name,status"]
    for p in all_projects():
        lines.append("{},{},{}".format(p["code"], p["name"], p["status"]))
    return "\n".join(lines)
EOF

w screens/team_assign.py <<'EOF'
"""Team screen: the project picker used when a person is added to a project team."""
from app.projects import all_projects


def selectable_projects():
    return [p["code"] for p in all_projects()]
EOF

w sql/portfolio_view.sql <<'EOF'
CREATE VIEW portfolio AS
SELECT code, name, status
FROM projects;
EOF

w run-tests.sh <<'EOF'
#!/usr/bin/env bash
# Usage: ./run-tests.sh <suite>
set -eu
cd "$(dirname "$0")"
export PYTHONDONTWRITEBYTECODE=1
exec python3 tests/run.py "$@"
EOF
chmod +x "$DEST/run-tests.sh"

w tests/__init__.py </dev/null
# Python 3.12 and later print "NO TESTS RAN" for an empty run. The runner prints "OK" instead, so the 0-test smoke
# suite looks like a pass on every version. The explanation stays here, out of the fixture, so it gives nothing away.
w tests/run.py <<'EOF'
"""Runs one test suite and prints the unittest summary. Exits 0 when nothing failed."""
import io
import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SUITES = {
    "unit": ("tests/unit", "test"),
    "integration": ("tests/integration", "test"),
    "smoke": ("tests/unit", "smoke_"),
}


def main(argv):
    if len(argv) != 1 or argv[0] not in SUITES:
        print("usage: run-tests.sh unit|integration|smoke", file=sys.stderr)
        return 2
    folder, prefix = SUITES[argv[0]]
    sys.path.insert(0, ROOT)
    loader = unittest.TestLoader()
    loader.testMethodPrefix = prefix
    suite = loader.discover(os.path.join(ROOT, folder), pattern="test_*.py", top_level_dir=ROOT)
    out = io.StringIO()
    result = unittest.TextTestRunner(stream=out, verbosity=1).run(suite)
    sys.stdout.write(out.getvalue().replace("NO TESTS RAN", "OK"))
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
EOF

w tests/unit/__init__.py </dev/null
w tests/unit/test_screens.py <<'EOF'
import unittest

from screens.dashboard import rows
from screens.reports import export_csv, report_rows
from screens.team_assign import selectable_projects


class DashboardTests(unittest.TestCase):
    def test_dashboard_lists_every_project(self):
        self.assertEqual(len(rows()), 4)

    def test_dashboard_lists_active_projects(self):
        self.assertIn("P001", rows())


class ReportTests(unittest.TestCase):
    def test_report_has_code_and_name(self):
        self.assertIn(("P001", "North Road"), report_rows())

    def test_export_has_a_header(self):
        self.assertTrue(export_csv().startswith("code,name,status"))


class TeamTests(unittest.TestCase):
    def test_active_projects_are_selectable(self):
        self.assertIn("P004", selectable_projects())
EOF

w tests/integration/__init__.py </dev/null
w tests/integration/test_portfolio_view.py <<'EOF'
import os
import sqlite3
import unittest

from app.projects import all_projects

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


class PortfolioViewTests(unittest.TestCase):
    def setUp(self):
        self.conn = sqlite3.connect(":memory:")
        self.conn.execute("CREATE TABLE projects (id INTEGER PRIMARY KEY, code TEXT, name TEXT, status TEXT)")
        for p in all_projects():
            self.conn.execute("INSERT INTO projects VALUES (?, ?, ?, ?)", (p["id"], p["code"], p["name"], p["status"]))
        with open(os.path.join(ROOT, "sql", "portfolio_view.sql"), encoding="utf-8") as handle:
            self.conn.executescript(handle.read())

    def tearDown(self):
        self.conn.close()

    def codes(self):
        return [row[0] for row in self.conn.execute("SELECT code FROM portfolio")]

    def test_active_projects_are_in_the_portfolio(self):
        self.assertIn("P001", self.codes())

    def test_portfolio_is_ordered_by_name(self):
        names = [row[0] for row in self.conn.execute("SELECT name FROM portfolio")]
        self.assertEqual(names, sorted(names))
EOF

w AGENTS.md <<'EOF'
# Project contract

## Commands

All suites run with the standard library only. No database server and no Docker.

```
./run-tests.sh unit          # unit tests
./run-tests.sh integration   # integration tests (SQLite in memory)
./run-tests.sh smoke         # smoke tests
```

## Risk areas

- `sql/` holds the views that the reporting tools read.
EOF

commit 2026-09-01T09:00:00+10:00 'Add project screens and tests'

# ---------------------------------------------------------------- main, commit 2: a later change on main

w README.md <<'EOF'
# Project list

A small app with three screens that list projects. See AGENTS.md for the test commands.
EOF
commit 2026-09-15T09:00:00+10:00 'Add README'

# ---------------------------------------------------------------- the PR branch

g checkout -q -b pr/42-hide-archived-projects
python3 - "$DEST" <<'PY'
import sys

root = sys.argv[1]


def edit(rel, old, new):
    path = root + "/" + rel
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
    assert text.count(old) == 1, (rel, old)
    with open(path, "w", encoding="utf-8") as handle:
        handle.write(text.replace(old, new))


edit(
    "app/projects.py",
    "def all_projects():\n    return [dict(p) for p in PROJECTS]\n",
    "def all_projects():\n    return [dict(p) for p in PROJECTS]\n\n\n"
    "def visible_projects():\n"
    '    return [p for p in all_projects() if p["status"] != "Archived"]\n',
)
edit("screens/dashboard.py", "from app.projects import all_projects", "from app.projects import visible_projects")
edit("screens/dashboard.py", "for p in all_projects()]", "for p in visible_projects()]")
edit(
    "screens/reports.py",
    "from app.projects import all_projects",
    "from app.projects import all_projects, visible_projects",
)
edit(
    "screens/reports.py",
    'return [(p["code"], p["name"]) for p in all_projects()]',
    'return [(p["code"], p["name"]) for p in visible_projects()]',
)
edit("sql/portfolio_view.sql", "FROM projects;", "FROM projects\nWHERE status NOT IN ('Archived', 'Closed');")
PY
commit 2026-10-20T09:00:00+11:00 '#42 Hide archived projects on screens'

# Remote refs, as a fetch from the team's server would leave them.
g update-ref refs/remotes/origin/main main
g update-ref refs/remotes/origin/pr/42-hide-archived-projects HEAD
g symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main

echo "head $(g rev-parse HEAD)"
