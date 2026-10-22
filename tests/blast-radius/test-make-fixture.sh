#!/usr/bin/env bash
# Tests for tests/blast-radius/make-fixture.sh: the fixture builds the same way every time, and the three
# scenarios' facts are real. Builds into a throwaway folder from mktemp. Nothing is deleted; the folders are listed
# at the end. The scenario branch is only ever read with git (git archive) and unpacked into the throwaway folder.
# Usage: tests/blast-radius/test-make-fixture.sh
set -u

HERE=$(cd "$(dirname "$0")" && pwd -P)
BUILDER="$HERE/make-fixture.sh"
export PYTHONDONTWRITEBYTECODE=1
PASS=0
FAIL=0
TMPS=""

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

ROOT=$(mktemp -d "${TMPDIR:-/tmp}/blast-radius.XXXXXX")
TMPS=" $ROOT"
F="$ROOT/shop"
OUT1=$(bash "$BUILDER" "$F" 2>&1)
STATUS1=$?
OUT2=$(bash "$BUILDER" "$ROOT/shop2" 2>&1)

# Read-only copies of the code, one for each use. The branch is unpacked, never checked out in the fixture.
BR="$ROOT/branch-tree"
MAIN="$ROOT/main-tree"
S1="$ROOT/s1"
S3="$ROOT/s3"
mkdir -p "$BR" "$MAIN" "$S1/code" "$S3/code"
git -C "$F" archive change/coupon-casefold | tar -x -C "$BR"
git -C "$F" archive main | tar -x -C "$MAIN"
git -C "$F" archive main | tar -x -C "$S1/code"
git -C "$F" archive main | tar -x -C "$S3/code"
cp "$F/data/shop.db" "$S1/before.db"
cp "$F/data/shop.db" "$S1/after.db"
sqlite3 "$S1/after.db" "ALTER TABLE orders RENAME COLUMN total TO grand_total"

# sql <query>: run a read-only query against the fixture database and print the rows.
sql() { sqlite3 -readonly "$F/data/shop.db" "$1"; }

# pyedit <file> <old> <new>: replace text that occurs exactly once (used on the scratch copies only).
pyedit() {
  python3 - "$1" "$2" "$3" <<'PY'
import sys

path, old, new = sys.argv[1:4]
with open(path, encoding="utf-8") as handle:
    text = handle.read()
assert text.count(old) == 1, old
with open(path, "w", encoding="utf-8") as handle:
    handle.write(text.replace(old, new))
PY
}

# unit_tests_pass <tree> <count>: the unit tests print "Ran <count> tests" and OK.
unit_tests_pass() {
  local out
  out=$(cd "$1" && python3 -m unittest discover -s tests 2>&1) || return 1
  printf '%s\n' "$out" | grep -qE "^Ran $2 tests in [0-9.]+s\$" && printf '%s\n' "$out" | grep -qx 'OK'
}

# proof <tree>: run the real shop.coupons over every code point. Exits non-zero when a code that CODE_RE accepts
# has lower() different from casefold().
proof() {
  (cd "$1" && python3 - <<'PY'
import string

from shop import coupons

accepted = []
for cp in range(0x110000):
    text = chr(cp) * 4
    if coupons.CODE_RE.fullmatch(text):
        accepted.append(chr(cp))
        assert text.lower() == text.casefold(), hex(cp)
assert set(accepted) == set(string.ascii_letters + string.digits), len(accepted)
assert "\u017f".lower() != "\u017f".casefold() and not coupons.CODE_RE.fullmatch("\u017f" * 4)
assert "\u212a".lower() == "\u212a".casefold() == "k" and not coupons.CODE_RE.fullmatch("\u212a" * 4)
differ = [cp for cp in range(0x110000) if chr(cp).lower() != chr(cp).casefold()]
assert differ and not any(coupons.CODE_RE.fullmatch(chr(cp) * 4) for cp in differ)
print("checked 1114112 code points; %d accepted; %d differ" % (len(accepted), len(differ)))
PY
  )
}

# lookups <tree> <db>: print what find_coupon returns for a fixed list of inputs, read from the database read-only.
lookups() {
  python3 - "$1" "$2" <<'PY'
import random
import sys

tree, path = sys.argv[1:3]
sys.path.insert(0, tree)
from shop import coupons, db

conn = db.connect(path, readonly=True)
codes = [row["code"] for row in conn.execute("SELECT code FROM coupons ORDER BY id")]
cases = []
for code in codes:
    cases += [code, code.lower(), code.swapcase(), code.title()]
    cases += [code.replace("S", "\u017f"), code.replace("K", "\u212a"), code.replace("SS", "\u00df")]
cases += ["STRASSE", "stra\u00dfe", "\u01c5\u01c5\u01c5\u01c5", "\ufb01\ufb01\ufb01\ufb01", "SAVE10 ", " save10", "save10\n"]
rng = random.Random(7)
pool = "abcxyzSAVE0189\u017f\u00df\u212a\u0130\u0131\ufb01\u03c3\u03c2\u03a3 "
for _ in range(2000):
    cases.append("".join(rng.choice(pool) for _ in range(rng.randint(3, 13))))
for case in cases:
    row = coupons.find_coupon(conn, case)
    print(ascii(case), None if row is None else row["id"])
PY
}

test_build_succeeds_and_prints_the_head_hash() {
  # The scoring key (expected-findings.md) names these commits. If the builder changes on purpose,
  # update the key and these hashes together.
  [ "$STATUS1" -eq 0 ] && [ "$OUT1" = "head 3fc4ff26b6100be382115baff8de48aec48919cb" ] &&
    [ "$(git -C "$F" rev-parse change/coupon-casefold)" = "d8641e70033aa7f72cdbe34c5a4b22806ce74487" ]
}

test_two_builds_are_identical() {
  [ -f "$F/data/shop.db" ] && [ -f "$ROOT/shop2/data/shop.db" ] &&
    printf '%s\n' "$OUT1" | grep -qE '^head [0-9a-f]{40}$' &&
    [ "$OUT1" = "$OUT2" ] &&
    [ "$(git -C "$F" rev-parse change/coupon-casefold)" = "$(git -C "$ROOT/shop2" rev-parse change/coupon-casefold)" ] &&
    [ "$(sqlite3 "$F/data/shop.db" .dump | shasum)" = "$(sqlite3 "$ROOT/shop2/data/shop.db" .dump | shasum)" ]
}

test_existing_destination_exits_1_and_no_argument_exits_2() {
  local a b
  bash "$BUILDER" "$F" >/dev/null 2>&1
  a=$?
  bash "$BUILDER" >/dev/null 2>&1
  b=$?
  [ "$a" -eq 1 ] && [ "$b" -eq 2 ]
}

test_agents_md_has_the_project_contract_headings() {
  local h
  for h in '## Project contract' '### Commands' '### Verify' '### Data access' '### Risk areas' '### External systems and owners'; do
    grep -qxF "$h" "$F/AGENTS.md" || return 1
  done
}

test_agents_md_states_the_data_access_and_the_two_external_systems() {
  grep -qF '`data/shop.db` (SQLite file)' "$F/AGENTS.md" &&
    grep -qF 'sqlite3 -readonly' "$F/AGENTS.md" &&
    grep -qF '| Shop mobile app | inbound |' "$F/AGENTS.md" &&
    grep -qF 'Mobile team (Priya)' "$F/AGENTS.md" &&
    grep -qF 'old app versions stay installed for months' "$F/AGENTS.md" &&
    grep -qF '| Partner fulfilment feed | outbound |' "$F/AGENTS.md" &&
    grep -qF '`shop.fulfilment.write_feed`' "$F/AGENTS.md" &&
    grep -qF 'order dispatch' "$F/AGENTS.md" &&
    grep -qF 'Fulfilment team (Marcus)' "$F/AGENTS.md" &&
    grep -qF "import code is not in this repository" "$F/AGENTS.md" &&
    [ "$(grep -c '| none |$' "$F/AGENTS.md")" -ge 2 ]
}

test_agents_md_risk_areas_name_no_hidden_file() {
  local risk
  risk=$(sed -n '/^### Risk areas/,/^### External systems/p' "$F/AGENTS.md")
  printf '%s\n' "$risk" | grep -qF 'GET /orders' &&
    printf '%s\n' "$risk" | grep -qF 'schema' &&
    printf '%s\n' "$risk" | grep -qF 'partner feed' &&
    ! printf '%s\n' "$risk" | grep -qiE 'clients/|order_summary|reports/|monthly|export_revenue|run_report|mobile|total'
}

test_repository_is_clean_on_main_with_one_scenario_branch_and_an_ignored_database() {
  [ -z "$(git -C "$F" status --porcelain)" ] &&
    [ "$(git -C "$F" symbolic-ref --short HEAD)" = "main" ] &&
    [ "$(git -C "$F" rev-list --count main)" -eq 8 ] &&
    [ "$(git -C "$F" for-each-ref --format='%(refname:short)' refs/heads | sort | tr '\n' ' ')" = "change/coupon-casefold main " ] &&
    [ "$(git -C "$F" rev-list --count main..change/coupon-casefold)" -eq 1 ] &&
    [ "$(git -C "$F" rev-list --count change/coupon-casefold..main)" -eq 0 ] &&
    [ -f "$F/data/shop.db" ] &&
    git -C "$F" check-ignore -q data/shop.db &&
    ! git -C "$F" ls-files --error-unmatch data/shop.db
}

test_the_database_has_the_agreed_tables_and_rows() {
  [ "$(sql "SELECT group_concat(name) FROM pragma_table_info('customers')")" = "id,email" ] &&
    [ "$(sql "SELECT group_concat(name) FROM pragma_table_info('orders')")" = "id,customer_id,placed_at,status,total" ] &&
    [ "$(sql "SELECT group_concat(name) FROM pragma_table_info('order_items')")" = "id,order_id,sku,qty,price" ] &&
    [ "$(sql "SELECT group_concat(name) FROM pragma_table_info('coupons')")" = "id,code,percent" ] &&
    [ "$(sql "SELECT count(*) FROM customers")" = "60" ] &&
    [ "$(sql "SELECT count(*) FROM orders")" = "300" ] &&
    [ "$(sql "SELECT count(*) FROM coupons")" = "20" ] &&
    [ "$(sql "SELECT count(*) FROM order_items")" -gt 300 ] &&
    [ "$(sql "SELECT email FROM customers WHERE id = 1")" = "buyer0001@shop.invalid" ] &&
    [ "$(sql "SELECT count(*) FROM orders WHERE typeof(total) <> 'real'")" = "0" ] &&
    [ "$(sql "SELECT count(*) FROM orders WHERE status = 'paid'")" -gt 0 ] &&
    [ "$(sql "SELECT count(*) FROM coupons WHERE length(code) NOT BETWEEN 4 AND 12 OR code GLOB '*[^A-Z0-9]*'")" = "0" ]
}

test_unit_tests_pass_on_main_and_agents_md_gives_the_count() {
  local n
  n=$(sed -n 's/.*`Ran \([0-9]*\) tests` and `OK`.*/\1/p' "$F/AGENTS.md")
  [ "$n" = "15" ] && unit_tests_pass "$F" 15
}

test_unit_tests_pass_on_the_scenario_branch() {
  unit_tests_pass "$BR" 16
}

test_no_fixture_text_names_the_answers() {
  local words='hidden|trap|blast|consumer'
  # Every file on main, every commit message on both branches, every line any main commit added or removed.
  ! git -C "$F" grep -iqE "$words|casefold" main -- &&
    ! git -C "$F" grep -iqE "$words" change/coupon-casefold -- &&
    ! git -C "$F" ls-tree -r --name-only change/coupon-casefold | grep -iE "$words|casefold" &&
    ! git -C "$F" log --all --format='%an %ae %cn %ce %B' | grep -iE "$words|mobile" &&
    ! git -C "$F" log main --format=%B | grep -i casefold &&
    ! git -C "$F" log -p main | grep -vE '^(diff --git|index |--- |\+\+\+ )' | grep -iE "$words|casefold" &&
    [ "$(git -C "$F" grep -il mobile main -- | tr '\n' ' ')" = "main:AGENTS.md " ] &&
    [ "$(git -C "$F" ls-tree -r --name-only main | grep -i mobile | tr '\n' ' ')" = "clients/mobile/order_summary.js clients/mobile/orders_api.js " ]
}

test_the_branch_diff_changes_only_the_comparison_and_adds_one_ascii_test() {
  local diff
  diff=$(git -C "$F" diff main change/coupon-casefold)
  [ "$(git -C "$F" diff --name-only main change/coupon-casefold | tr '\n' ' ')" = "shop/coupons.py tests/test_coupons.py " ] &&
    [ "$(git -C "$F" diff main change/coupon-casefold -- shop/coupons.py | grep -cE '^[-+] ')" -eq 4 ] &&
    git -C "$F" diff main change/coupon-casefold -- shop/coupons.py | grep -qF -- '-        if row["code"].lower() == wanted:' &&
    git -C "$F" diff main change/coupon-casefold -- shop/coupons.py | grep -qF -- '+        if row["code"].casefold() == wanted:' &&
    ! printf '%s\n' "$diff" | grep -E '^[-+]' | grep -qE 'CODE_RE|re\.' &&
    [ -z "$(printf '%s\n' "$diff" | grep -E '^\+' | grep -v '^+++' | LC_ALL=C grep -n '[^ -~]')" ]
}

test_s1_the_hidden_places_exist_and_a_search_for_the_function_does_not_find_them() {
  [ "$(git -C "$F" grep -l order_to_dict main -- | sed 's/^main://' | sort | tr '\n' ' ')" = "shop/api.py tests/test_api.py " ] &&
    grep -qF 'amount: formatAmount(order.total),' "$F/clients/mobile/order_summary.js" &&
    grep -qF 'SUM(total)' "$F/reports/monthly_revenue.sql" &&
    grep -qF '"reports"' "$F/scripts/run_report.py" &&
    ! grep -qi total "$F/scripts/run_report.py" &&
    grep -qF 'COLUMNS = ["id", "placed_at", "total"]' "$F/scripts/export_revenue.py" &&
    ! grep -qi 'python\|\.py\|order_to_dict' "$F/clients/mobile/order_summary.js" &&
    [ "$(git -C "$F" grep -il total main -- | sed 's/^main://' | sort | tr '\n' ' ')" = "clients/mobile/order_summary.js migrations/0001_create_customers_and_orders.sql reports/monthly_revenue.sql scripts/export_revenue.py shop/api.py tests/test_api.py " ] &&
    [ ! -e "$F/migrations/0004_rename_total.sql" ] &&
    [ "$(ls "$F/migrations" | wc -l | tr -d ' ')" = "3" ]
}

test_s1_both_scripts_work_now_and_fail_with_no_such_column_after_the_rename() {
  local out
  python3 "$F/scripts/run_report.py" monthly_revenue --db "$S1/before.db" >/dev/null 2>&1 || return 1
  python3 "$F/scripts/export_revenue.py" "$S1/before.csv" --db "$S1/before.db" >/dev/null 2>&1 || return 1
  out=$(python3 "$F/scripts/run_report.py" monthly_revenue --db "$S1/after.db" 2>&1) && return 1
  printf '%s\n' "$out" | grep -q 'no such column: total' || return 1
  out=$(python3 "$F/scripts/export_revenue.py" "$S1/after.csv" --db "$S1/after.db" 2>&1) && return 1
  printf '%s\n' "$out" | grep -q 'no such column: total'
}

test_s1_after_the_rename_the_api_json_has_no_total_and_only_the_api_test_fails() {
  local code="$S1/code" out failing
  pyedit "$code/shop/api.py" '"total": round(row["total"], 2)' '"grand_total": round(row["grand_total"], 2)' || return 1
  pyedit "$code/shop/api.py" 'status, total FROM orders' 'status, grand_total FROM orders' || return 1
  printf 'ALTER TABLE orders RENAME COLUMN total TO grand_total;\n' >"$code/migrations/0004_rename_total.sql"
  out=$(cd "$code" && python3 - "$S1/after.db" <<'PY'
import sys

from shop import api, db

orders = api.list_orders(db.connect(sys.argv[1], readonly=True), limit=5)
assert len(orders) == 5 and all("grand_total" in o and "total" not in o for o in orders), orders
print("ok")
PY
  ) || return 1
  [ "$out" = "ok" ] || return 1
  out=$(cd "$code" && python3 -m unittest discover -s tests 2>&1)
  failing=$(printf '%s\n' "$out" | grep -E '^(FAIL|ERROR):')
  [ -n "$failing" ] && ! printf '%s\n' "$failing" | grep -qv 'OrdersApiTests'
}

test_s2_the_proof_passes_on_the_branch_and_main() {
  local out
  out=$(proof "$BR") || return 1
  printf '%s\n' "$out" | grep -qE '^checked 1114112 code points; 62 accepted; [0-9]+ differ$' || return 1
  proof "$MAIN" >/dev/null 2>&1 || return 1
  proof "$F" >/dev/null 2>&1
}

test_s2_the_fact_is_not_trivial_lower_and_casefold_differ_but_the_validator_rejects_those_characters() {
  python3 - <<'PY'
import re

klass = re.compile(r"[A-Za-z0-9]{4,12}")
ignore = re.compile(r"[A-Za-z0-9]{4,12}", re.IGNORECASE)
both = re.compile(r"[A-Za-z0-9]{4,12}", re.IGNORECASE | re.ASCII)
sharp_s, long_s, kelvin = "\u00df", "\u017f", "\u212a"
assert long_s.lower() != long_s.casefold() and sharp_s.lower() != sharp_s.casefold()
assert kelvin.lower() == kelvin.casefold() == "k"
for char in (long_s, sharp_s, kelvin):
    assert not klass.fullmatch(char * 4), hex(ord(char))
    assert not both.fullmatch(char * 4), hex(ord(char))
assert ignore.fullmatch(long_s * 4) and ignore.fullmatch(kelvin * 4)
PY
}

test_s2_the_proof_can_fail_when_the_validator_is_loosened() {
  local loose="$ROOT/loose-tree"
  cp -R "$BR" "$loose" || return 1
  pyedit "$loose/shop/coupons.py" 're.ASCII)' 're.IGNORECASE)' || return 1
  ! proof "$loose" >/dev/null 2>&1
}

test_s2_stored_codes_are_ascii_and_the_schema_keeps_them_so() {
  local conn_out
  conn_out=$(cd "$F" && python3 - <<'PY'
import re
import sqlite3

from shop import db

conn = db.connect(":memory:")
db.migrate(conn)
for bad in ("STRA\u00dfE1", "abcd", "AB", "ABCDEFGHIJKLM", "SAVE 10", "\u017fAVE10"):
    try:
        conn.execute("INSERT INTO coupons (code, percent) VALUES (?, 5)", (bad,))
    except sqlite3.IntegrityError:
        continue
    raise SystemExit("accepted " + repr(bad))
conn.execute("INSERT INTO coupons (code, percent) VALUES ('SAVE10', 5)")
stored = db.connect("data/shop.db", readonly=True)
codes = [row[0] for row in stored.execute("SELECT code FROM coupons")]
assert len(codes) == 20 and all(re.fullmatch(r"[A-Z0-9]{4,12}", c, re.ASCII) for c in codes)
print("ok")
PY
  )
  [ "$conn_out" = "ok" ]
}

test_s2_main_and_branch_answer_the_same_for_every_probe_and_the_probe_can_tell_them_apart() {
  local a b c
  a=$(lookups "$MAIN" "$F/data/shop.db") || return 1
  b=$(lookups "$BR" "$F/data/shop.db") || return 1
  [ "$a" = "$b" ] || return 1
  [ "$(printf '%s\n' "$a" | wc -l | tr -d ' ')" -gt 2000 ] || return 1
  [ "$(printf '%s\n' "$a" | grep -vc ' None$')" -gt 40 ] || return 1
  # Without the validator the branch would match 'ſPRING15'; main does not.
  local noguard="$ROOT/noguard-tree"
  cp -R "$BR" "$noguard" || return 1
  pyedit "$noguard/shop/coupons.py" '    if not CODE_RE.fullmatch(code):
        return None
' '' || return 1
  c=$(lookups "$noguard" "$F/data/shop.db") || return 1
  [ "$a" != "$c" ]
}

test_s3_nothing_in_the_repository_reads_the_feed_back() {
  ! git -C "$F" grep -iqE 'csv\.reader|DictReader|read_csv|fromisoformat|pandas' main -- &&
    [ "$(git -C "$F" grep -h strptime main -- | wc -l | tr -d ' ')" = "1" ] &&
    git -C "$F" grep -h strptime main -- | grep -qF '"%Y-%m-%d %H:%M:%S"' &&
    [ "$(git -C "$F" grep -l '%d/%m/%Y' main -- | sed 's/^main://' | tr '\n' ' ')" = "shop/fulfilment.py " ] &&
    [ "$(git -C "$F" grep -l 'write_feed' main -- | sed 's/^main://' | sort | tr '\n' ' ')" = "AGENTS.md docs/partner-feed.md shop/__main__.py shop/fulfilment.py tests/test_fulfilment.py " ] &&
    [ "$(git -C "$F" grep -l 'fulfilment_' main -- | sed 's/^main://' | sort | tr '\n' ' ')" = "AGENTS.md docs/partner-feed.md shop/fulfilment.py tests/test_fulfilment.py " ]
}

test_s3_the_stale_document_gives_the_old_format_and_nothing_about_the_partner_parsing() {
  grep -qF '`DD/MM/YYYY HH:MM`' "$F/docs/partner-feed.md" &&
    ! grep -qiE 'iso|8601|pars|import|accept|partner.*(read|load)' "$F/docs/partner-feed.md" &&
    [ "$(git -C "$F" log --format=%as -- docs/partner-feed.md)" = "2021-06-14" ] &&
    [ "$(git -C "$F" log --format=%as -- shop/fulfilment.py)" = "2021-06-14" ]
}

test_s3_the_existing_test_asserts_the_old_date_format() {
  grep -qF '"1,05/03/2024 10:00,SKU-1001,2",' "$F/tests/test_fulfilment.py" &&
    ! grep -qF 'T10:00:00Z' "$F/tests/test_fulfilment.py"
}

test_s3_the_feed_runs_in_a_scratch_folder_in_the_old_format() {
  local out="$S3/out" file
  mkdir -p "$out" || return 1
  (cd "$F" && python3 -m shop feed "$out") >/dev/null || return 1
  file=$(ls "$out"/fulfilment_*.csv) || return 1
  printf '%s\n' "$file" | grep -qE '/fulfilment_[0-9]{8}\.csv$' &&
    [ "$(sed -n 1p "$file" | tr -d '\r')" = "order_id,placed_at,sku,qty" ] &&
    sed -n 2p "$file" | grep -qE '^1,01/10/2025 16:36,SKU-1012,3' &&
    [ "$(sed -n '2,$p' "$file" | grep -cvE '^[0-9]+,[0-9]{2}/[0-9]{2}/[0-9]{4} [0-9]{2}:[0-9]{2},SKU-[0-9]+,[0-9]+')" = "0" ] &&
    [ ! -e "$F/fulfilment_$(date +%Y%m%d).csv" ]
}

test_s3_the_proposed_change_writes_iso_dates_and_only_the_feed_test_fails() {
  local code="$S3/code" out failing file
  pyedit "$code/shop/fulfilment.py" 'parsed.strftime("%d/%m/%Y %H:%M")' 'parsed.strftime("%Y-%m-%dT%H:%M:%SZ")' || return 1
  mkdir -p "$code/data" "$S3/iso" && cp "$F/data/shop.db" "$code/data/shop.db" || return 1
  (cd "$code" && python3 -m shop feed "$S3/iso") >/dev/null || return 1
  file=$(ls "$S3/iso"/fulfilment_*.csv) || return 1
  sed -n 2p "$file" | grep -qE '^1,2025-10-01T16:36:00Z,SKU-1012,3' || return 1
  out=$(cd "$code" && python3 -m unittest discover -s tests 2>&1)
  failing=$(printf '%s\n' "$out" | grep -E '^(FAIL|ERROR):')
  [ -n "$failing" ] && ! printf '%s\n' "$failing" | grep -qv 'WriteFeedTests'
}

test_the_three_change_inputs_exist_and_do_not_name_the_answers() {
  local f line
  for f in 01-rename 02-casefold 03-partner-dates; do [ -s "$HERE/changes/$f.md" ] || return 1; done
  for f in 01-rename 03-partner-dates; do
    grep -qx 'Confidence: confirmed' "$HERE/changes/$f.md" || return 1
    for line in Task 'Root cause' 'Failing test first' 'Proposed fix' 'Do not change' 'Risk areas' Verification Follow-on; do
      [ "$(grep -c "^$line: " "$HERE/changes/$f.md")" -eq 1 ] || return 1
    done
  done
  grep -qxF 'Risk areas: callers of order_to_dict: shop/api.py and tests/test_api.py' "$HERE/changes/01-rename.md" &&
    grep -qF 'migrations/0004_rename_total.sql' "$HERE/changes/01-rename.md" &&
    grep -qF 'ALTER TABLE orders RENAME COLUMN total TO grand_total' "$HERE/changes/01-rename.md" &&
    ! grep -qiE 'mobile|clients/|reports/|export_revenue|run_report|monthly_revenue' "$HERE/changes/01-rename.md" &&
    grep -qF 'change/coupon-casefold' "$HERE/changes/02-casefold.md" &&
    grep -qF 'git diff' "$HERE/changes/02-casefold.md" &&
    ! grep -qiE 'ascii|CODE_RE|contained|validat' "$HERE/changes/02-casefold.md" &&
    grep -qF '2024-03-05T10:00:00Z' "$HERE/changes/03-partner-dates.md" &&
    grep -qF 'reporting tool' "$HERE/changes/03-partner-dates.md" &&
    ! grep -qiE 'unknown|marcus|unproven|importer|accepts' "$HERE/changes/03-partner-dates.md"
}

test_the_lines_cited_in_expected_findings_are_the_lines_in_the_fixture() {
  sed -n 10p "$F/shop/api.py" | grep -qF '"total": round(row["total"], 2)' &&
    sed -n 15p "$F/shop/api.py" | grep -qF 'SELECT id, customer_id, placed_at, status, total FROM orders' &&
    sed -n 4p "$F/shop/api.py" | grep -qxF 'def order_to_dict(row):' &&
    sed -n 25p "$F/tests/test_api.py" | grep -qF '"total": 25.5' &&
    sed -n 11p "$F/migrations/0001_create_customers_and_orders.sql" | grep -qF 'total REAL NOT NULL' &&
    sed -n 12p "$F/clients/mobile/order_summary.js" | grep -qF 'formatAmount(order.total)' &&
    sed -n 3p "$F/reports/monthly_revenue.sql" | grep -qF 'SUM(total)' &&
    sed -n 17p "$F/scripts/run_report.py" | grep -qF '"reports"' &&
    sed -n 12p "$F/scripts/export_revenue.py" | grep -qF 'COLUMNS = ["id", "placed_at", "total"]' &&
    sed -n 16p "$F/scripts/export_revenue.py" | grep -qF 'query = "SELECT " + ", ".join(COLUMNS)' &&
    sed -n 3p "$F/shop/coupons.py" | grep -qF 'CODE_RE = re.compile(r"[A-Za-z0-9]{4,12}", re.ASCII)' &&
    sed -n 8p "$F/shop/coupons.py" | grep -qF 'CODE_RE.fullmatch(code)' &&
    sed -n 10p "$F/shop/coupons.py" | grep -qF 'wanted = code.lower()' &&
    sed -n 11p "$F/shop/coupons.py" | grep -qF 'SELECT id, code, percent FROM coupons' &&
    sed -n 12p "$F/shop/coupons.py" | grep -qF 'row["code"].lower() == wanted' &&
    sed -n 10p "$BR/shop/coupons.py" | grep -qF 'wanted = code.casefold()' &&
    sed -n 12p "$BR/shop/coupons.py" | grep -qF 'row["code"].casefold() == wanted' &&
    sed -n 3p "$F/migrations/0003_create_coupons.sql" | grep -qF "code NOT GLOB '*[^A-Z0-9]*'" &&
    sed -n 9p "$F/shop/fulfilment.py" | grep -qF 'strptime(value, "%Y-%m-%d %H:%M:%S")' &&
    sed -n 10p "$F/shop/fulfilment.py" | grep -qF 'parsed.strftime("%d/%m/%Y %H:%M")' &&
    sed -n 13p "$F/shop/fulfilment.py" | grep -qxF 'def write_feed(conn, folder, day=None):' &&
    sed -n 44p "$F/tests/test_fulfilment.py" | grep -qF '1,05/03/2024 10:00,SKU-1001,2' &&
    sed -n 11p "$F/docs/partner-feed.md" | grep -qF 'DD/MM/YYYY HH:MM' &&
    sed -n 19p "$F/shop/__main__.py" | grep -qF 'coupons.find_coupon(conn, args[0])' &&
    grep -qF "$(printf '%s\n' "$OUT1" | sed 's/^head //')" "$HERE/expected-findings.md" &&
    grep -qF "$(git -C "$F" rev-parse change/coupon-casefold)" "$HERE/expected-findings.md"
}

test_the_repository_is_still_clean_after_every_check() {
  [ -z "$(git -C "$F" status --porcelain)" ] &&
    [ "$(git -C "$F" symbolic-ref --short HEAD)" = "main" ] &&
    [ "$(git -C "$F" rev-parse main)" = "$(printf '%s\n' "$OUT1" | sed 's/^head //')" ] &&
    [ "$(sqlite3 "$F/data/shop.db" .dump | shasum)" = "$(sqlite3 "$ROOT/shop2/data/shop.db" .dump | shasum)" ] &&
    [ -z "$(find "$F" -newer "$F/data/shop.db" -type f -not -path '*/.git/*')" ]
}

echo "agentd-blast-radius fixture"
check "the build succeeds and prints the head hash" test_build_succeeds_and_prints_the_head_hash
check "two builds give the same hash, the same branch tip and the same database" test_two_builds_are_identical
check "an existing destination exits 1 and no argument exits 2" test_existing_destination_exits_1_and_no_argument_exits_2
check "AGENTS.md has the project contract headings" test_agents_md_has_the_project_contract_headings
check "AGENTS.md states the data access and the two external systems" test_agents_md_states_the_data_access_and_the_two_external_systems
check "AGENTS.md risk areas name no hidden file" test_agents_md_risk_areas_name_no_hidden_file
check "the repository is clean on main, has one scenario branch and ignores the database" test_repository_is_clean_on_main_with_one_scenario_branch_and_an_ignored_database
check "the database has the agreed tables, columns and rows" test_the_database_has_the_agreed_tables_and_rows
check "the unit tests pass on main (Ran 15 tests, OK, as AGENTS.md says)" test_unit_tests_pass_on_main_and_agents_md_gives_the_count
check "the unit tests pass on change/coupon-casefold (Ran 16 tests, OK)" test_unit_tests_pass_on_the_scenario_branch
check "no file, commit message or comment names the answers" test_no_fixture_text_names_the_answers
check "the branch diff changes only the comparison and adds one ASCII test" test_the_branch_diff_changes_only_the_comparison_and_adds_one_ascii_test
check "scenario 1: the other places that read the old name exist, and a search for the function misses them" test_s1_the_hidden_places_exist_and_a_search_for_the_function_does_not_find_them
check "scenario 1: both scripts work now and fail with 'no such column: total' after the rename" test_s1_both_scripts_work_now_and_fail_with_no_such_column_after_the_rename
check "scenario 1: after the rename the API JSON has no total, and only the API test fails" test_s1_after_the_rename_the_api_json_has_no_total_and_only_the_api_test_fails
check "scenario 2: the exhaustive proof passes on the branch and on main" test_s2_the_proof_passes_on_the_branch_and_main
check "scenario 2: lower and casefold differ, but the validator rejects those characters" test_s2_the_fact_is_not_trivial_lower_and_casefold_differ_but_the_validator_rejects_those_characters
check "scenario 2: the proof fails when the validator is loosened" test_s2_the_proof_can_fail_when_the_validator_is_loosened
check "scenario 2: stored codes are ASCII and the schema keeps them so" test_s2_stored_codes_are_ascii_and_the_schema_keeps_them_so
check "scenario 2: main and branch answer the same, and the probe tells them apart without the validator" test_s2_main_and_branch_answer_the_same_for_every_probe_and_the_probe_can_tell_them_apart
check "scenario 3: nothing in the repository reads the feed back" test_s3_nothing_in_the_repository_reads_the_feed_back
check "scenario 3: the stale document gives the old format and nothing about the partner" test_s3_the_stale_document_gives_the_old_format_and_nothing_about_the_partner_parsing
check "scenario 3: the existing test asserts the old date format" test_s3_the_existing_test_asserts_the_old_date_format
check "scenario 3: the feed runs in a scratch folder in the old format" test_s3_the_feed_runs_in_a_scratch_folder_in_the_old_format
check "scenario 3: the proposed change writes ISO dates and only the feed test fails" test_s3_the_proposed_change_writes_iso_dates_and_only_the_feed_test_fails
check "the three change inputs exist and do not name the answers" test_the_three_change_inputs_exist_and_do_not_name_the_answers
check "the lines cited in expected-findings.md are the lines in the fixture" test_the_lines_cited_in_expected_findings_are_the_lines_in_the_fixture
check "the repository is still clean and unchanged after every check" test_the_repository_is_still_clean_after_every_check

echo
echo "passed=$PASS failed=$FAIL"
echo "temp folders left in place:$TMPS"
[ "$FAIL" -eq 0 ]
