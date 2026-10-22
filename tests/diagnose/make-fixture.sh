#!/usr/bin/env bash
# Builds a small synthetic git repository, a Python and SQLite shop, to test agentd-diagnose.
# Usage: make-fixture.sh <dest>
#   <dest> must not exist. The build makes three commits, then seeds data/shop.db (git-ignored).
# Prints "head <hash>".
# Four problems are seeded, one for each ticket in tests/diagnose/tickets:
#   1. bug:         a fixed-amount coupon is applied once per order line, not once per order (shop/pricing.py).
#   2. data:        duplicate customers that differ only in email case, since the importer stopped lower-casing.
#   3. performance: the yearly revenue report runs a query for every order and every item (shop/reports.py).
#   4. gate:        nothing in the fixture fails for customer 912034, who exists only in production.
# The fixture uses a fake local identity, ignores your git config, global ignore file, hooks and environment
# variables, and uses fixed commit dates, so the hash and the database are the same on every build.
# Needs bash, git and Python 3. Exit: 0 = built, 1 = destination exists, 2 = bad arguments.
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

write_agents() {
  w AGENTS.md <<EOF
# Shop

A small order and invoicing tool for a wholesaler. Python 3 and SQLite. Command line only.

## Project contract

### Commands

Run from: the repository root.

- **Prerequisites:** Python 3.10 or later. No packages to install.
- **Build:** none.
- **Unit tests:** \`python3 -m unittest discover -s tests\`
- **Integration tests:** none.
- **Run one test:** \`python3 -m unittest tests.test_pricing.PricingTests.test_no_coupon\`
- **Lint and format:** none.
- **Run locally:** \`python3 -m shop <command>\`. See Verify.
- **Count check:** the unit tests print \`Ran $1 tests\` and \`OK\`.
- **Known failing on a clean main:** nothing.

### Verify

- **Start the app:** there is no server. Each command runs once and exits.
- **Sign in:** not needed.
- **Test data:** \`python3 scripts/seed_db.py\` builds \`data/shop.db\`. It refuses to overwrite an existing file.
  \`data/shop.db\` is git-ignored.
- **Key flows to drive:**

  | Flow | Command | Expected result |
  |---|---|---|
  | Order total | \`python3 -m shop total <order id>\` | the order total with the coupon applied |
  | Customer list | \`python3 -m shop customers\` | one line for each customer |
  | Yearly revenue | \`python3 -m shop report <year>\` | one line for each customer with revenue |
  | Invoice export | \`python3 -m shop export <customer id> <file>\` | a CSV file with one row for each order |

- **Automated checks of the running app:** none.

### Data access

| Environment | URL | Database | Access rule | Who approves access |
|---|---|---|---|---|
| Test | none | \`data/shop.db\` (SQLite file) | read-only for diagnosis: SELECT only, open it with \`sqlite3 -readonly\` | the engineer |
| Production | none | unknown | none: no access from this repository | unknown: ask the support lead |

- **Network:** none needed for the test environment.
- **Query safely:** \`sqlite3 -readonly data/shop.db "SELECT ..."\`. Limit the rows.
- **Never do:** write to \`data/shop.db\` by hand, or run \`scripts/seed_db.py\` over a file you want to keep.
- **Schema changes:** the schema is in \`shop/db.py\`. There are no migrations yet.
- **Sensitive data:** customer names and emails are personal data in production. This test data is made up, but
  treat it the same way: write IDs and counts in reports, not emails.

### Risk areas

- **Public contracts:** the invoice CSV columns (\`customer, order_id, date, total\`). Finance reads them.
- **Database:** the schema in \`shop/db.py\`. Customer identity is the email address.
- **Authorisation:** none. The tool has no users.
- **Generated files:** none.
- **Business-critical calculations:** order totals and coupons in \`shop/pricing.py\`. Money is in cents. A change
  moves the revenue that finance reports.
- **Never commit:** \`data/shop.db\`.

### External systems and owners

| System | Direction | Our endpoints and services that depend on it | Features that depend on it | Owner | Test environment |
|---|---|---|---|---|---|
| Finance spreadsheet import | outbound | the invoice CSV from \`shop/export.py\` | weekly invoicing | the finance team | none |

- **Failure behaviour:** a failed export prints an error and exits with a non-zero code.
- **Other side of the boundary:** how finance imports the CSV is \`unknown: ask the finance team\`.
EOF
}

write_gitignore() {
  w .gitignore <<'EOF'
data/shop.db
__pycache__/
EOF
}

write_db() {
  w shop/__init__.py </dev/null
  w shop/db.py <<'EOF'
import sqlite3

SCHEMA = """
CREATE TABLE customers (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    created_at TEXT NOT NULL
);
CREATE TABLE products (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    price_cents INTEGER NOT NULL
);
CREATE TABLE coupons (
    code TEXT PRIMARY KEY,
    kind TEXT NOT NULL CHECK (kind IN ('fixed', 'percent')),
    amount_cents INTEGER,
    percent INTEGER
);
CREATE TABLE orders (
    id INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(id),
    coupon_code TEXT REFERENCES coupons(code),
    created_at TEXT NOT NULL
);
CREATE TABLE order_items (
    id INTEGER PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES orders(id),
    product_id INTEGER NOT NULL REFERENCES products(id),
    quantity INTEGER NOT NULL
);
CREATE INDEX idx_order_items_order_id ON order_items(order_id);
"""


def connect(path):
    return sqlite3.connect(path)
EOF
}

write_pricing() {
  w shop/pricing.py <<'EOF'
"""Order pricing. All money is in cents."""


def line_total(price_cents, quantity):
    return price_cents * quantity


def apply_coupon(amount_cents, coupon):
    if coupon is None:
        return amount_cents
    if coupon["kind"] == "percent":
        return amount_cents - amount_cents * coupon["percent"] // 100
    return max(amount_cents - coupon["amount_cents"], 0)


def order_total(lines, coupon=None):
    """lines is a list of (price_cents, quantity). Returns the order total in cents."""
    total = 0
    for price_cents, quantity in lines:
        total += apply_coupon(line_total(price_cents, quantity), coupon)
    return total


def load_coupon(conn, code):
    if code is None:
        return None
    row = conn.execute(
        "SELECT kind, amount_cents, percent FROM coupons WHERE code = ?", (code,)
    ).fetchone()
    if row is None:
        return None
    return {"kind": row[0], "amount_cents": row[1], "percent": row[2]}


def order_total_for(conn, order_id):
    coupon_code = conn.execute(
        "SELECT coupon_code FROM orders WHERE id = ?", (order_id,)
    ).fetchone()[0]
    rows = conn.execute(
        "SELECT p.price_cents, i.quantity FROM order_items i "
        "JOIN products p ON p.id = i.product_id WHERE i.order_id = ?",
        (order_id,),
    ).fetchall()
    return order_total(rows, load_coupon(conn, coupon_code))
EOF
}

write_customers_v1() {
  w shop/customers.py <<'EOF'
def import_customers(conn, rows):
    """Add customers from (name, email, created_at) rows. A customer whose email exists is skipped."""
    added = 0
    for name, email, created_at in rows:
        email = email.strip().lower()
        found = conn.execute(
            "SELECT 1 FROM customers WHERE email = ?", (email,)
        ).fetchone()
        if found:
            continue
        conn.execute(
            "INSERT INTO customers (name, email, created_at) VALUES (?, ?, ?)",
            (name, email, created_at),
        )
        added += 1
    conn.commit()
    return added


def list_customers(conn):
    return conn.execute(
        "SELECT id, name, email, created_at FROM customers ORDER BY id"
    ).fetchall()
EOF
}

write_customers_v2() {
  w shop/customers.py <<'EOF'
def import_customers(conn, rows):
    """Add customers from (name, email, created_at) rows. A customer whose email exists is skipped."""
    added = 0
    for name, email, created_at in rows:
        email = email.strip()
        found = conn.execute(
            "SELECT 1 FROM customers WHERE email = ?", (email,)
        ).fetchone()
        if found:
            continue
        conn.execute(
            "INSERT INTO customers (name, email, created_at) VALUES (?, ?, ?)",
            (name, email, created_at),
        )
        added += 1
    conn.commit()
    return added


def list_customers(conn):
    return conn.execute(
        "SELECT id, name, email, created_at FROM customers ORDER BY id"
    ).fetchall()
EOF
}

write_reports() {
  w shop/reports.py <<'EOF'
from shop.pricing import load_coupon, order_total


def revenue_report(conn, year):
    """Revenue in cents for each customer for a year. Returns a sorted list of (customer_id, cents)."""
    start, end = f"{year}-01-01", f"{year + 1}-01-01"
    orders = conn.execute(
        "SELECT id, customer_id, coupon_code FROM orders "
        "WHERE created_at >= ? AND created_at < ?",
        (start, end),
    ).fetchall()
    totals = {}
    for order_id, customer_id, coupon_code in orders:
        coupon = load_coupon(conn, coupon_code)
        items = conn.execute(
            "SELECT product_id, quantity FROM order_items WHERE order_id = ?",
            (order_id,),
        ).fetchall()
        lines = []
        for product_id, quantity in items:
            price = conn.execute(
                "SELECT price_cents FROM products WHERE id = ?", (product_id,)
            ).fetchone()[0]
            lines.append((price, quantity))
        totals[customer_id] = totals.get(customer_id, 0) + order_total(lines, coupon)
    return sorted(totals.items())
EOF
}

write_export() {
  w shop/export.py <<'EOF'
import csv

from shop.pricing import order_total_for


def money(cents):
    return f"{cents // 100}.{cents % 100:02d}"


def export_invoices(conn, customer_id, out_path):
    """Write one CSV row for each order of a customer: customer, order id, date, total. Returns the row count."""
    customer = conn.execute(
        "SELECT name FROM customers WHERE id = ?", (customer_id,)
    ).fetchone()
    if customer is None:
        raise LookupError(f"customer {customer_id} not found")
    orders = conn.execute(
        "SELECT id, created_at FROM orders WHERE customer_id = ? ORDER BY id",
        (customer_id,),
    ).fetchall()
    with open(out_path, "w", newline="", encoding="utf-8") as handle:
        writer = csv.writer(handle)
        writer.writerow(["customer", "order_id", "date", "total"])
        for order_id, created_at in orders:
            total = order_total_for(conn, order_id)
            writer.writerow([customer[0], order_id, created_at[:10], money(total)])
    return len(orders)
EOF
}

write_cli_v1() {
  w shop/__main__.py <<'EOF'
import os
import sys

from shop import customers, db, pricing


def money(cents):
    return f"{cents // 100}.{cents % 100:02d}"


def main(argv):
    conn = db.connect(os.environ.get("SHOP_DB", "data/shop.db"))
    if len(argv) == 2 and argv[0] == "total":
        print(money(pricing.order_total_for(conn, int(argv[1]))))
    elif argv == ["customers"]:
        for row in customers.list_customers(conn):
            print("\t".join(str(value) for value in row))
    else:
        print("usage: python3 -m shop total <order id> | customers", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
EOF
}

write_cli_v3() {
  w shop/__main__.py <<'EOF'
import os
import sys

from shop import customers, db, export, pricing, reports


def money(cents):
    return f"{cents // 100}.{cents % 100:02d}"


def main(argv):
    conn = db.connect(os.environ.get("SHOP_DB", "data/shop.db"))
    if len(argv) == 2 and argv[0] == "total":
        print(money(pricing.order_total_for(conn, int(argv[1]))))
    elif argv == ["customers"]:
        for row in customers.list_customers(conn):
            print("\t".join(str(value) for value in row))
    elif len(argv) == 2 and argv[0] == "report":
        for customer_id, cents in reports.revenue_report(conn, int(argv[1])):
            print(customer_id, money(cents))
    elif len(argv) == 3 and argv[0] == "export":
        try:
            export.export_invoices(conn, int(argv[1]), argv[2])
        except LookupError as error:
            print(f"error: {error}", file=sys.stderr)
            return 1
    else:
        print(
            "usage: python3 -m shop total <order id> | customers | report <year> | export <customer id> <file>",
            file=sys.stderr,
        )
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
EOF
}

write_seed() {
  w scripts/seed_db.py <<'EOF'
"""Builds data/shop.db with fixed test data. Usage: python3 scripts/seed_db.py [path]

Refuses to overwrite an existing file. The data is made up and has no randomness."""
import datetime
import os
import sqlite3
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from shop import customers, db

START = datetime.date(2026, 1, 1)
END = datetime.date(2026, 10, 21)
CUSTOMERS = 400
ORDERS = 80000
COUPONS = [("SAVE5", "fixed", 500, None), ("SAVE20", "fixed", 2000, None), ("TEN", "percent", None, 10)]


def main(path):
    if os.path.exists(path):
        print(f"seed_db.py: {path} already exists", file=sys.stderr)
        return 1
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    conn = sqlite3.connect(path)
    conn.executescript(db.SCHEMA)
    conn.executemany("INSERT INTO coupons VALUES (?, ?, ?, ?)", COUPONS)
    products = [(i, f"Product {i:03d}", 500 + 250 * (i % 17)) for i in range(1, 51)]
    products += [(9001, "Notebook", 1000), (9002, "Backpack", 2000)]
    conn.executemany("INSERT INTO products VALUES (?, ?, ?)", products)

    people = []
    for i in range(1, CUSTOMERS + 1):
        created = START + datetime.timedelta(days=(i - 1) * 290 // CUSTOMERS)
        name = f"Customer {i:04d}" + (" Zoë" if i % 50 == 0 else "")
        people.append((name, f"user{i:04d}@example.test", created))
    # Some customers register a second time, two weeks after their first registration.
    returning_from = datetime.date(2026, 3, 11)
    for i in range(7, CUSTOMERS + 1, 7):
        name, _, created = people[i - 1]
        again = created + datetime.timedelta(days=14)
        if returning_from <= again <= END:
            people.append((name, f"User{i:04d}@Example.test", again))
    customers.import_customers(conn, [(n, e, c.isoformat()) for n, e, c in people])

    order_rows = []
    item_rows = []
    cycle = ["SAVE5", "TEN", "SAVE20"]
    for k in range(1, ORDERS + 1):
        customer_id = k % len(people) + 1
        created = people[customer_id - 1][2]
        span = (END - created).days
        day = created + datetime.timedelta(days=(k * 7919) % (span + 1))
        coupon = cycle[(k // 5) % 3] if k % 5 == 0 else None
        order_rows.append((k, customer_id, coupon, f"{day.isoformat()} 10:{k % 60:02d}:00"))
        for j in range(1 + k % 3):
            item_rows.append((k, (k * 7 + j * 13) % 50 + 1, 1 + (k + j) % 3))
    order_rows.append((90001, 1, "SAVE5", "2026-10-19 09:00:00"))
    item_rows += [(90001, 9001, 2), (90001, 9002, 1)]
    conn.executemany("INSERT INTO orders VALUES (?, ?, ?, ?)", order_rows)
    conn.executemany(
        "INSERT INTO order_items (order_id, product_id, quantity) VALUES (?, ?, ?)", item_rows
    )
    conn.commit()
    conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "data/shop.db"))
EOF
}

write_tests_v1() {
  w tests/__init__.py </dev/null
  w tests/test_pricing.py <<'EOF'
import unittest

from shop.pricing import order_total

PERCENT = {"kind": "percent", "amount_cents": None, "percent": 10}
FIXED = {"kind": "fixed", "amount_cents": 500, "percent": None}


class PricingTests(unittest.TestCase):
    def test_no_coupon(self):
        self.assertEqual(order_total([(1000, 2), (2000, 1)]), 4000)

    def test_percent_coupon(self):
        self.assertEqual(order_total([(1000, 2), (2000, 1)], PERCENT), 3600)

    def test_fixed_coupon_on_a_single_line_order(self):
        self.assertEqual(order_total([(2000, 1)], FIXED), 1500)


if __name__ == "__main__":
    unittest.main()
EOF
  w tests/test_customers.py <<'EOF'
import sqlite3
import unittest

from shop import customers, db


class CustomerTests(unittest.TestCase):
    def setUp(self):
        self.conn = sqlite3.connect(":memory:")
        self.conn.executescript(db.SCHEMA)

    def test_import_adds_a_new_customer(self):
        added = customers.import_customers(self.conn, [("Ann", "ann@example.test", "2026-01-12")])
        self.assertEqual(added, 1)

    def test_import_skips_an_existing_email(self):
        row = ("Ann", "ann@example.test", "2026-01-12")
        customers.import_customers(self.conn, [row])
        self.assertEqual(customers.import_customers(self.conn, [row]), 0)


if __name__ == "__main__":
    unittest.main()
EOF
}

write_tests_v3() {
  w tests/test_reports.py <<'EOF'
import sqlite3
import unittest

from shop import db, reports


class ReportTests(unittest.TestCase):
    def test_revenue_for_one_customer(self):
        conn = sqlite3.connect(":memory:")
        conn.executescript(db.SCHEMA)
        conn.execute("INSERT INTO customers VALUES (1, 'Ann', 'ann@example.test', '2026-01-01')")
        conn.execute("INSERT INTO products VALUES (1, 'Pen', 1000)")
        conn.execute("INSERT INTO orders VALUES (1, 1, NULL, '2026-02-01 10:00:00')")
        conn.execute("INSERT INTO order_items VALUES (1, 1, 1, 2)")
        self.assertEqual(reports.revenue_report(conn, 2026), [(1, 2000)])


if __name__ == "__main__":
    unittest.main()
EOF
  w tests/test_export.py <<'EOF'
import os
import sqlite3
import tempfile
import unittest

from shop import db, export


class ExportTests(unittest.TestCase):
    def setUp(self):
        self.conn = sqlite3.connect(":memory:")
        self.conn.executescript(db.SCHEMA)
        self.conn.execute("INSERT INTO customers VALUES (1, 'Ann', 'ann@example.test', '2026-01-01')")

    def test_export_writes_a_header_and_one_row_for_each_order(self):
        self.conn.execute("INSERT INTO products VALUES (1, 'Pen', 1000)")
        self.conn.execute("INSERT INTO orders VALUES (1, 1, NULL, '2026-02-01 10:00:00')")
        self.conn.execute("INSERT INTO order_items VALUES (1, 1, 1, 2)")
        with tempfile.TemporaryDirectory() as folder:
            path = os.path.join(folder, "out.csv")
            self.assertEqual(export.export_invoices(self.conn, 1, path), 1)
            with open(path, encoding="utf-8") as handle:
                lines = handle.read().splitlines()
        self.assertEqual(lines, ["customer,order_id,date,total", "Ann,1,2026-02-01,20.00"])

    def test_export_of_an_unknown_customer_raises(self):
        with self.assertRaises(LookupError):
            export.export_invoices(self.conn, 2, os.devnull)


if __name__ == "__main__":
    unittest.main()
EOF
}

write_readme() {
  w README.md <<EOF
# Shop

A small order and invoicing tool for a wholesaler. Python 3 and SQLite.

    python3 scripts/seed_db.py
    python3 -m shop total <order id>
$1
See AGENTS.md for the commands, how to verify a change, and the risk areas.
EOF
}

git init -q --template= -b main "$DEST"
g config user.name Fixture
g config user.email fixture@example.invalid

write_gitignore
write_db
write_pricing
write_customers_v1
write_cli_v1
write_seed
write_tests_v1
write_agents 5
write_readme "    python3 -m shop customers"
commit 2026-01-12T09:00:00+11:00 'Add orders, coupons and customer import'

write_customers_v2
commit 2026-03-10T09:00:00+11:00 'Simplify customer import'

write_reports
write_export
write_cli_v3
write_tests_v3
write_agents 8
write_readme "    python3 -m shop customers
    python3 -m shop report 2026
    python3 -m shop export <customer id> <file>"
commit 2026-04-02T09:00:00+11:00 'Add revenue report and invoice export'

(cd "$DEST" && python3 scripts/seed_db.py >/dev/null)
echo "head $(g rev-parse HEAD)"
