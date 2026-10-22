#!/usr/bin/env bash
# Builds a small synthetic git repository, a Python and SQLite shop, to test agentd-blast-radius.
# Usage: make-fixture.sh <dest>
#   <dest> must not exist. The build makes eight commits on main, one more commit on the branch
#   change/coupon-casefold, leaves HEAD on main, then seeds data/shop.db (git-ignored).
# Prints "head <hash>", the hash of main.
# Three change inputs are scored on it, one file each in tests/blast-radius/changes. The scoring key is
# tests/blast-radius/expected-findings.md. Nothing in the fixture itself names the answers.
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

write_gitignore() {
  w .gitignore <<'EOF'
data/shop.db
__pycache__/
EOF
}

write_db() {
  w shop/__init__.py </dev/null
  w shop/db.py <<'EOF'
import os
import sqlite3
from pathlib import Path

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_PATH = os.path.join(ROOT, "data", "shop.db")
MIGRATIONS = os.path.join(ROOT, "migrations")


def connect(path=DEFAULT_PATH, readonly=False):
    if readonly:
        conn = sqlite3.connect(Path(path).resolve().as_uri() + "?mode=ro", uri=True)
    else:
        conn = sqlite3.connect(path)
    conn.row_factory = sqlite3.Row
    return conn


def migrate(conn, folder=MIGRATIONS):
    """Apply every .sql file in the folder that is not applied yet, in file name order."""
    conn.execute("CREATE TABLE IF NOT EXISTS schema_migrations (name TEXT PRIMARY KEY)")
    applied = {row[0] for row in conn.execute("SELECT name FROM schema_migrations")}
    for name in sorted(os.listdir(folder)):
        if not name.endswith(".sql") or name in applied:
            continue
        with open(os.path.join(folder, name), encoding="utf-8") as handle:
            conn.executescript(handle.read())
        conn.execute("INSERT INTO schema_migrations (name) VALUES (?)", (name,))
        conn.commit()


def build(path=DEFAULT_PATH):
    """Create a database file with every migration applied."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    conn = connect(path)
    migrate(conn)
    return conn
EOF
  w migrations/0001_create_customers_and_orders.sql <<'EOF'
CREATE TABLE customers (
    id INTEGER PRIMARY KEY,
    email TEXT NOT NULL UNIQUE
);

CREATE TABLE orders (
    id INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers (id),
    placed_at TEXT NOT NULL,
    status TEXT NOT NULL,
    total REAL NOT NULL
);

CREATE INDEX orders_customer_id ON orders (customer_id);
EOF
  w migrations/0002_create_order_items.sql <<'EOF'
CREATE TABLE order_items (
    id INTEGER PRIMARY KEY,
    order_id INTEGER NOT NULL REFERENCES orders (id),
    sku TEXT NOT NULL,
    qty INTEGER NOT NULL,
    price REAL NOT NULL
);

CREATE INDEX order_items_order_id ON order_items (order_id);
EOF
  w tests/test_db.py <<'EOF'
import os
import sqlite3
import tempfile
import unittest

from shop import db


class MigrationTests(unittest.TestCase):
    def test_migrate_creates_the_tables(self):
        conn = db.connect(":memory:")
        db.migrate(conn)
        names = {row[0] for row in conn.execute("SELECT name FROM sqlite_master WHERE type = 'table'")}
        self.assertTrue({"customers", "orders", "order_items"} <= names)

    def test_migrate_twice_applies_each_file_once(self):
        conn = db.connect(":memory:")
        db.migrate(conn)
        db.migrate(conn)
        files = [name for name in os.listdir(db.MIGRATIONS) if name.endswith(".sql")]
        count = conn.execute("SELECT count(*) FROM schema_migrations").fetchone()[0]
        self.assertEqual(count, len(files))

    def test_a_read_only_connection_rejects_writes(self):
        with tempfile.TemporaryDirectory() as folder:
            path = os.path.join(folder, "shop.db")
            db.build(path).close()
            conn = db.connect(path, readonly=True)
            with self.assertRaises(sqlite3.OperationalError):
                conn.execute("INSERT INTO customers (email) VALUES ('buyer0001@shop.invalid')")
            conn.close()


if __name__ == "__main__":
    unittest.main()
EOF
}

write_fulfilment() {
  w shop/fulfilment.py <<'EOF'
import csv
import datetime
import os

FEED_COLUMNS = ["order_id", "placed_at", "sku", "qty"]


def format_placed_at(value):
    parsed = datetime.datetime.strptime(value, "%Y-%m-%d %H:%M:%S")
    return parsed.strftime("%d/%m/%Y %H:%M")


def write_feed(conn, folder, day=None):
    """Write the dispatch file for the paid orders into the folder and return its path."""
    day = day or datetime.date.today()
    path = os.path.join(folder, "fulfilment_%s.csv" % day.strftime("%Y%m%d"))
    rows = conn.execute(
        "SELECT o.id, o.placed_at, i.sku, i.qty"
        " FROM orders o JOIN order_items i ON i.order_id = o.id"
        " WHERE o.status = 'paid' ORDER BY o.id, i.id"
    ).fetchall()
    with open(path, "w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(FEED_COLUMNS)
        for order_id, placed_at, sku, qty in rows:
            writer.writerow([order_id, format_placed_at(placed_at), sku, qty])
    return path
EOF
  w docs/partner-feed.md <<'EOF'
# Partner feed

Every night `shop.fulfilment.write_feed` writes one CSV file for the fulfilment partner. The file is named
`fulfilment_YYYYMMDD.csv`, where the date is the day it was written.

The first line holds the column names. Each following line is one item of one paid order.

| Column | Content |
|---|---|
| `order_id` | our order number |
| `placed_at` | when the order was placed, `DD/MM/YYYY HH:MM` |
| `sku` | the product code |
| `qty` | the number of units |
EOF
  w tests/test_fulfilment.py <<'EOF'
import datetime
import os
import tempfile
import unittest

from shop import db, fulfilment


class WriteFeedTests(unittest.TestCase):
    def setUp(self):
        self.conn = db.connect(":memory:")
        db.migrate(self.conn)
        self.conn.execute("INSERT INTO customers VALUES (1, 'buyer0001@shop.invalid')")
        self.conn.executemany(
            "INSERT INTO orders VALUES (?, ?, ?, ?, ?)",
            [
                (1, 1, "2024-03-05 10:00:00", "paid", 33.0),
                (2, 1, "2024-03-06 11:30:00", "shipped", 14.0),
                (3, 1, "2024-03-07 09:15:00", "pending", 9.5),
            ],
        )
        self.conn.executemany(
            "INSERT INTO order_items VALUES (?, ?, ?, ?, ?)",
            [
                (1, 1, "SKU-1001", 2, 9.5),
                (2, 1, "SKU-1004", 1, 14.0),
                (3, 2, "SKU-1002", 1, 14.0),
                (4, 3, "SKU-1001", 1, 9.5),
            ],
        )

    def write(self, day):
        with tempfile.TemporaryDirectory() as folder:
            path = fulfilment.write_feed(self.conn, folder, day)
            with open(path, encoding="utf-8", newline="") as handle:
                return os.path.basename(path), handle.read().splitlines()

    def test_feed_has_a_line_for_each_item_of_a_paid_order(self):
        name, lines = self.write(datetime.date(2024, 3, 5))
        self.assertEqual(
            lines,
            [
                "order_id,placed_at,sku,qty",
                "1,05/03/2024 10:00,SKU-1001,2",
                "1,05/03/2024 10:00,SKU-1004,1",
            ],
        )

    def test_feed_file_is_named_after_the_day(self):
        name, _ = self.write(datetime.date(2024, 3, 5))
        self.assertEqual(name, "fulfilment_20240305.csv")

    def test_feed_is_only_a_header_when_no_order_is_paid(self):
        self.conn.execute("UPDATE orders SET status = 'shipped'")
        _, lines = self.write(datetime.date(2024, 3, 5))
        self.assertEqual(lines, ["order_id,placed_at,sku,qty"])


if __name__ == "__main__":
    unittest.main()
EOF
}

write_coupons() {
  w migrations/0003_create_coupons.sql <<'EOF'
CREATE TABLE coupons (
    id INTEGER PRIMARY KEY,
    code TEXT NOT NULL UNIQUE CHECK (length(code) BETWEEN 4 AND 12 AND code NOT GLOB '*[^A-Z0-9]*'),
    percent INTEGER NOT NULL CHECK (percent BETWEEN 1 AND 100)
);
EOF
  w shop/coupons.py <<'EOF'
import re

CODE_RE = re.compile(r"[A-Za-z0-9]{4,12}", re.ASCII)


def find_coupon(conn, code):
    """Return the coupon row for a code that a customer typed, or None."""
    if not CODE_RE.fullmatch(code):
        return None
    wanted = code.lower()
    for row in conn.execute("SELECT id, code, percent FROM coupons ORDER BY id"):
        if row["code"].lower() == wanted:
            return row
    return None
EOF
  w tests/test_coupons.py <<'EOF'
import unittest

from shop import db
from shop.coupons import find_coupon


class FindCouponTests(unittest.TestCase):
    def setUp(self):
        self.conn = db.connect(":memory:")
        db.migrate(self.conn)
        self.conn.executemany(
            "INSERT INTO coupons VALUES (?, ?, ?)",
            [(1, "SAVE10", 10), (2, "SPRING15", 15)],
        )

    def test_exact_code(self):
        self.assertEqual(find_coupon(self.conn, "SAVE10")["percent"], 10)

    def test_lower_case_code(self):
        self.assertEqual(find_coupon(self.conn, "spring15")["id"], 2)

    def test_unknown_code_returns_none(self):
        self.assertIsNone(find_coupon(self.conn, "NOPE99"))

    def test_too_short_code_returns_none(self):
        self.assertIsNone(find_coupon(self.conn, "SAV"))

    def test_code_with_a_space_returns_none(self):
        self.assertIsNone(find_coupon(self.conn, "SAVE 10"))


if __name__ == "__main__":
    unittest.main()
EOF
}

write_api() {
  w shop/api.py <<'EOF'
import json


def order_to_dict(row):
    return {
        "id": row["id"],
        "customer_id": row["customer_id"],
        "placed_at": row["placed_at"],
        "status": row["status"],
        "total": round(row["total"], 2),
    }


def list_orders(conn, status=None, limit=50):
    sql = "SELECT id, customer_id, placed_at, status, total FROM orders"
    args = []
    if status is not None:
        sql += " WHERE status = ?"
        args.append(status)
    sql += " ORDER BY id LIMIT ?"
    args.append(limit)
    return [order_to_dict(row) for row in conn.execute(sql, args)]


def get_orders(conn, query=None):
    """Handle GET /orders. Return the HTTP status and the JSON body."""
    query = query or {}
    try:
        limit = int(query.get("limit", 50))
    except ValueError:
        return 400, json.dumps({"error": "limit must be a whole number"})
    return 200, json.dumps(list_orders(conn, query.get("status"), limit))
EOF
  w tests/test_api.py <<'EOF'
import json
import unittest

from shop import api, db


class OrdersApiTests(unittest.TestCase):
    def setUp(self):
        self.conn = db.connect(":memory:")
        db.migrate(self.conn)
        self.conn.execute("INSERT INTO customers VALUES (1, 'buyer0001@shop.invalid')")
        self.conn.executemany(
            "INSERT INTO orders VALUES (?, ?, ?, ?, ?)",
            [
                (1, 1, "2024-03-05 10:00:00", "paid", 25.5),
                (2, 1, "2024-03-06 11:30:00", "shipped", 40.0),
                (3, 1, "2024-04-02 09:15:00", "cancelled", 12.25),
            ],
        )

    def test_order_to_dict_lists_the_fields_of_one_order(self):
        row = self.conn.execute("SELECT * FROM orders WHERE id = 1").fetchone()
        self.assertEqual(
            api.order_to_dict(row),
            {"id": 1, "customer_id": 1, "placed_at": "2024-03-05 10:00:00", "status": "paid", "total": 25.5},
        )

    def test_list_orders_can_filter_by_status(self):
        orders = api.list_orders(self.conn, status="shipped")
        self.assertEqual([order["id"] for order in orders], [2])

    def test_get_orders_returns_the_orders_as_json(self):
        status, body = api.get_orders(self.conn, {"limit": "2"})
        self.assertEqual(status, 200)
        self.assertEqual([order["id"] for order in json.loads(body)], [1, 2])

    def test_get_orders_rejects_a_limit_that_is_not_a_number(self):
        status, body = api.get_orders(self.conn, {"limit": "many"})
        self.assertEqual(status, 400)
        self.assertIn("error", json.loads(body))


if __name__ == "__main__":
    unittest.main()
EOF
}

write_client() {
  w clients/mobile/order_summary.js <<'EOF'
// Turns the orders from the API into the rows on the orders screen.
export function formatAmount(value) {
  return "$" + Number(value).toFixed(2);
}

export function orderRows(orders) {
  return orders.map((order) => ({
    key: String(order.id),
    title: `Order #${order.id}`,
    date: order.placed_at.slice(0, 10),
    status: order.status,
    amount: formatAmount(order.total),
  }));
}
EOF
  w clients/mobile/orders_api.js <<'EOF'
import { orderRows } from "./order_summary";

const PAGE_SIZE = 50;

export async function fetchOrders(baseUrl) {
  const response = await fetch(`${baseUrl}/orders?limit=${PAGE_SIZE}`);
  if (!response.ok) {
    throw new Error(`orders request failed with status ${response.status}`);
  }
  return orderRows(await response.json());
}
EOF
}

write_report() {
  w reports/monthly_revenue.sql <<'EOF'
SELECT substr(placed_at, 1, 7) AS month,
       COUNT(*) AS orders,
       SUM(total) AS revenue
FROM orders
WHERE status IN ('paid', 'shipped')
GROUP BY substr(placed_at, 1, 7)
ORDER BY month;
EOF
  w scripts/run_report.py <<'EOF'
"""Run a report from the reports folder: run_report.py <name> [--db <file>]. Prints tab-separated rows."""
import argparse
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)

from shop import db  # noqa: E402


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("name", help="the file name in reports/, without .sql")
    parser.add_argument("--db", default=db.DEFAULT_PATH)
    args = parser.parse_args(argv)
    with open(os.path.join(ROOT, "reports", args.name + ".sql"), encoding="utf-8") as handle:
        sql = handle.read()
    cursor = db.connect(args.db, readonly=True).execute(sql)
    print("\t".join(column[0] for column in cursor.description))
    for row in cursor:
        print("\t".join(str(value) for value in row))


if __name__ == "__main__":
    main()
EOF
}

write_export() {
  w scripts/export_revenue.py <<'EOF'
"""Write the paid and shipped orders to a CSV file: export_revenue.py <file> [--db <file>]."""
import argparse
import csv
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)

from shop import db  # noqa: E402

COLUMNS = ["id", "placed_at", "total"]


def export(conn, path):
    query = "SELECT " + ", ".join(COLUMNS) + " FROM orders WHERE status IN ('paid', 'shipped') ORDER BY id"
    rows = conn.execute(query).fetchall()
    with open(path, "w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(COLUMNS)
        writer.writerows(rows)
    return len(rows)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("file")
    parser.add_argument("--db", default=db.DEFAULT_PATH)
    args = parser.parse_args(argv)
    print("%d orders written" % export(db.connect(args.db, readonly=True), args.file))


if __name__ == "__main__":
    main()
EOF
}

write_cli() {
  w shop/__main__.py <<'EOF'
import sys

from shop import api, coupons, db, fulfilment

USAGE = "usage: python3 -m shop orders [limit] | coupon <code> | feed <folder>"


def main(argv):
    if not argv:
        print(USAGE, file=sys.stderr)
        return 2
    command, args = argv[0], argv[1:]
    conn = db.connect(readonly=True)
    if command == "orders" and len(args) <= 1:
        status, body = api.get_orders(conn, {"limit": args[0]} if args else {})
        print(body)
        return 0 if status == 200 else 1
    if command == "coupon" and len(args) == 1:
        row = coupons.find_coupon(conn, args[0])
        if row is None:
            print("no such coupon")
            return 1
        print("%s %d" % (row["code"], row["percent"]))
        return 0
    if command == "feed" and len(args) == 1:
        print(fulfilment.write_feed(conn, args[0]))
        return 0
    print(USAGE, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
EOF
}

write_seed() {
  w scripts/seed_db.py <<'EOF'
"""Build data/shop.db with made-up test data. It refuses to overwrite an existing file."""
import datetime
import os
import random
import string
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)

from shop import db  # noqa: E402

PRICES = {
    "SKU-1001": 9.5,
    "SKU-1002": 14.0,
    "SKU-1003": 22.25,
    "SKU-1004": 14.0,
    "SKU-1005": 7.75,
    "SKU-1006": 31.0,
    "SKU-1007": 5.5,
    "SKU-1008": 18.0,
    "SKU-1009": 42.5,
    "SKU-1010": 12.0,
    "SKU-1011": 27.5,
    "SKU-1012": 3.25,
}
STATUSES = ["paid", "shipped", "cancelled", "pending"]
STATUS_WEIGHTS = [4, 10, 1, 2]


def main(path=db.DEFAULT_PATH):
    if os.path.exists(path):
        print("seed_db.py: %s already exists" % path, file=sys.stderr)
        return 1
    rng = random.Random(42)
    conn = db.build(path)

    conn.executemany(
        "INSERT INTO customers VALUES (?, ?)",
        [(n, "buyer%04d@shop.invalid" % n) for n in range(1, 61)],
    )

    orders, items = [], []
    placed = datetime.datetime(2025, 10, 1, 8, 0, 0)
    for order_id in range(1, 301):
        placed += datetime.timedelta(minutes=rng.randint(60, 2500))
        amount = 0.0
        for sku in rng.sample(sorted(PRICES), rng.randint(1, 4)):
            qty = rng.randint(1, 5)
            items.append((len(items) + 1, order_id, sku, qty, PRICES[sku]))
            amount += qty * PRICES[sku]
        orders.append((
            order_id,
            rng.randint(1, 60),
            placed.strftime("%Y-%m-%d %H:%M:%S"),
            rng.choices(STATUSES, STATUS_WEIGHTS)[0],
            round(amount, 2),
        ))
    conn.executemany("INSERT INTO orders VALUES (?, ?, ?, ?, ?)", orders)
    conn.executemany("INSERT INTO order_items VALUES (?, ?, ?, ?, ?)", items)

    percents = {"SAVE10": 10, "SPRING15": 15}
    alphabet = string.ascii_uppercase + string.digits
    while len(percents) < 20:
        code = "".join(rng.choice(alphabet) for _ in range(rng.randint(4, 12)))
        if code not in percents:
            percents[code] = rng.choice([5, 10, 15, 20, 25])
    conn.executemany(
        "INSERT INTO coupons VALUES (?, ?, ?)",
        [(n, code, percent) for n, (code, percent) in enumerate(percents.items(), 1)],
    )
    conn.commit()
    conn.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
EOF
}

# write_agents <test count>: the project contract. The count is what a run of the unit tests on main prints.
write_agents() {
  sed "s/@TESTS@/$1/" <<'EOF' | w AGENTS.md
# Shop

A small order tool: an orders API, coupon codes, a nightly fulfilment feed and some reports. Python 3 and SQLite.

## Project contract

### Commands

Run from: the repository root.

- **Prerequisites:** Python 3.9 or later. No packages to install. The `sqlite3` command line tool helps for queries.
- **Build:** none.
- **Unit tests:** `python3 -m unittest discover -s tests`
- **Integration tests:** none.
- **Run one test:** `python3 -m unittest tests.test_coupons.FindCouponTests.test_exact_code`
- **Lint and format:** none.
- **Run locally:** `python3 -m shop <command>`. See Verify.
- **Count check:** on main the unit tests print `Ran @TESTS@ tests` and `OK`.
- **Known failing on a clean main:** nothing.

### Verify

- **Start the app:** there is no server in this repository. `shop.api.get_orders` handles `GET /orders`, and
  `python3 -m shop <command>` runs it once and exits.
- **Sign in:** not needed.
- **Test data:** `python3 scripts/seed_db.py` builds `data/shop.db` with made-up data, the same on every run.
  It refuses to overwrite an existing file. `data/shop.db` is git-ignored.
- **Key flows to drive:**

  | Flow | Command | Expected result |
  |---|---|---|
  | Orders JSON | `python3 -m shop orders 3` | the JSON text of three orders |
  | Coupon lookup | `python3 -m shop coupon SAVE10` | `SAVE10 10` |
  | Fulfilment feed | `python3 -m shop feed <folder>` | the path of `fulfilment_YYYYMMDD.csv`, one line for each item of each paid order |

- **Automated checks of the running app:** none.

### Data access

| Environment | URL | Database | Access rule | Who approves access |
|---|---|---|---|---|
| Local | none | `data/shop.db` (SQLite file) | read-only for investigation: SELECT only, open it with `sqlite3 -readonly` | the engineer |

- **Network:** none needed. There is no other environment: no test server and no production database can be
  reached from this repository.
- **Query safely:** `sqlite3 -readonly data/shop.db "SELECT ..."`. Limit the rows.
- **Never do:** write to `data/shop.db` by hand.
- **Schema changes:** SQL files in `migrations/`, named `NNNN_name.sql`. `shop/db.py` applies them in file name order.
  An applied file is never edited.
- **Sensitive data:** none. The data is made up, and emails look like `buyer0001@shop.invalid`.

### Risk areas

- **Public contracts:** the JSON that `GET /orders` returns (its field names and types), and the file format of the
  nightly partner feed (its columns and the format of each value). Programs outside this repository read both.
- **Database:** the schema in `migrations/`.
- **Authorisation:** none. The tool has no users.
- **Generated files:** the nightly feed `fulfilment_YYYYMMDD.csv`. Regenerate it with `python3 -m shop feed <folder>`.
- **Business-critical calculations:** none.
- **Never commit:** `data/shop.db`.

### External systems and owners

| System | Direction | Our endpoints and services that depend on it | Features that depend on it | Owner | Test environment |
|---|---|---|---|---|---|
| Shop mobile app | inbound | `GET /orders` JSON, served by `shop.api` | the orders list in the app | Mobile team (Priya) | none |
| Partner fulfilment feed | outbound | nightly CSV file drop written by `shop.fulfilment.write_feed` | order dispatch | Fulfilment team (Marcus) | none |

- **Failure behaviour:** `python3 -m shop feed` exits with a non-zero code when it cannot write the file.
- **Other side of the boundary:** old app versions stay installed for months, so the apps in the field may be older
  than the code in this repository. Which fields they read is `unknown: ask Mobile team (Priya)`. The partner's
  import code is not in this repository: how it reads the CSV file is `unknown: ask Fulfilment team (Marcus)`.
EOF
}

write_readme() {
  w README.md <<'EOF'
# Shop

A small order tool: an orders API, coupon codes, a nightly fulfilment feed and some reports. Python 3 and SQLite.

    python3 scripts/seed_db.py
    python3 -m shop orders 3
    python3 -m shop coupon SAVE10
    python3 -m shop feed <folder>

See AGENTS.md for the commands, how to verify a change, and the risk areas.
EOF
}

git init -q --template= -b main "$DEST"
g config user.name Fixture
g config user.email fixture@example.invalid

write_gitignore
write_db
commit 2021-03-08T09:00:00+11:00 'Add orders database'

write_fulfilment
commit 2021-06-14T09:00:00+10:00 'Add fulfilment feed'

write_coupons
commit 2022-09-12T09:00:00+10:00 'Add coupon lookup'

write_api
commit 2023-04-03T09:00:00+10:00 'Add orders API'

write_client
commit 2023-05-22T09:00:00+10:00 'Add orders list to the client'

write_report
commit 2024-01-15T09:00:00+11:00 'Add monthly revenue report'

write_export
commit 2024-08-19T09:00:00+10:00 'Add revenue export'

write_cli
write_seed
write_agents 15
write_readme
commit 2026-05-11T09:00:00+10:00 'Add command line, test data and project contract'

g checkout -q -b change/coupon-casefold
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


edit("shop/coupons.py", "wanted = code.lower()", "wanted = code.casefold()")
edit("shop/coupons.py", 'row["code"].lower() == wanted', 'row["code"].casefold() == wanted')
edit(
    "tests/test_coupons.py",
    "    def test_unknown_code_returns_none(self):",
    "    def test_mixed_case_code(self):\n"
    '        self.assertEqual(find_coupon(self.conn, "sPrInG15")["id"], 2)\n'
    "\n"
    "    def test_unknown_code_returns_none(self):",
)
PY
commit 2026-10-20T09:00:00+11:00 'Use casefold for coupon code matching'
g checkout -q main

(cd "$DEST" && python3 scripts/seed_db.py)
echo "head $(g rev-parse main)"
