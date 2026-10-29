#!/usr/bin/env bash
# Tests for make-fixture.sh. Each test builds the fixture in a throwaway folder.
# It deletes nothing: the temp folders are left for the OS to clear, and listed at the end.
# Usage: tests/onboard/test-make-fixture.sh
set -u

HERE=$(cd "$(dirname "$0")" && pwd -P)
BUILDER="$HERE/make-fixture.sh"
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

# build [--v2]: builds into a new folder. Sets F (fixture path), BOUT (output) and BRC (exit code).
build() {
  local base
  base=$(mktemp -d)
  TMPS="$TMPS $base"
  F="$base/shop"
  BOUT=$("$BUILDER" "$F" "$@" 2>&1)
  BRC=$?
}

commit_count() { git -C "$F" rev-list --count HEAD; }
has_text() { grep -q -- "$2" "$F/$1"; }

V1_FILES="README.md azure-pipelines.yml docs/userGuide/orders.md
src/Shop.Api/Shop.Api.csproj src/Shop.Api/Program.cs src/Shop.Api/appsettings.json
src/Shop.Api/Controllers/OrdersController.cs src/Shop.Api/Controllers/CustomersController.cs
src/Shop.Api/Services/OrderSubmissionService.cs src/Shop.Api/Services/InvoiceService.cs
src/Shop.Api/Jobs/NightlySyncJob.cs
src/Shop.Integration/LegacyBusClient.cs
src/Shop.Domain/AppRole.cs src/Shop.Domain/Order.cs src/Shop.Domain/Invoice.cs src/Shop.Domain/Customer.cs
src/Shop.Data/Scripts/001_create_orders.sql src/Shop.Data/Scripts/002_create_invoices.sql
src/Shop.Data/Scripts/003_add_order_status.sql src/Shop.Data/StoredProcedures/GetOrderTotals.sql
tests/Shop.Tests/OrderSubmissionTests.cs"

test_v1_has_one_commit() {
  build
  [ "$BRC" -eq 0 ] || return 1
  [ "$(commit_count)" -eq 1 ] || return 1
  [ "$(printf '%s\n' "$BOUT" | grep -cE '^v1 [0-9a-f]{40}$')" -eq 1 ] &&
    [ "$(printf '%s\n' "$BOUT" | grep -c '^v2 ')" -eq 0 ] &&
    [ "$(printf '%s\n' "$BOUT" | sed -n 's/^v1 //p')" = "$(git -C "$F" rev-parse HEAD)" ]
}

test_v2_has_two_commits() {
  build --v2
  [ "$BRC" -eq 0 ] || return 1
  [ "$(commit_count)" -eq 2 ] || return 1
  [ "$(printf '%s\n' "$BOUT" | sed -n 's/^v1 //p')" = "$(git -C "$F" rev-parse HEAD~1)" ] &&
    [ "$(printf '%s\n' "$BOUT" | sed -n 's/^v2 //p')" = "$(git -C "$F" rev-parse HEAD)" ]
}

test_expected_files_exist() {
  local f
  build
  for f in $V1_FILES; do [ -f "$F/$f" ] || return 1; done
  [ ! -e "$F/docs/userGuide/cancel.md" ]
}

test_working_tree_is_clean_after_build() {
  build --v2
  [ "$BRC" -eq 0 ] && [ "$(commit_count)" -eq 2 ] && [ -z "$(git -C "$F" status --porcelain)" ]
}

test_fixture_identity_is_not_real() {
  local emails
  build --v2
  emails=$(git -C "$F" log --format='%ae%n%ce')
  [ -n "$emails" ] || return 1
  ! printf '%s\n' "$emails" | grep -qv '\.invalid$' &&
    [ "$(git -C "$F" config --local user.email)" = "fixture@example.invalid" ]
}

test_refuses_existing_dest() {
  local base
  base=$(mktemp -d)
  TMPS="$TMPS $base"
  "$BUILDER" "$base" >/dev/null 2>&1
  [ $? -eq 1 ] && [ ! -e "$base/.git" ] && [ -z "$(ls -A "$base")" ]
}

test_bad_arguments_exit_2() {
  "$BUILDER" >/dev/null 2>&1
  [ $? -eq 2 ] || return 1
  "$BUILDER" "$(mktemp -u)/x" --v3 >/dev/null 2>&1
  [ $? -eq 2 ]
}

test_build_is_deterministic() {
  local first
  build
  first=$(git -C "$F" rev-parse HEAD)
  [ "$BRC" -eq 0 ] && [ -n "$first" ] || return 1
  build
  [ "$first" = "$(git -C "$F" rev-parse HEAD)" ]
}

test_ignores_the_users_git_hooks() {
  local base hooks
  base=$(mktemp -d)
  TMPS="$TMPS $base"
  hooks="$base/hooks"
  mkdir "$hooks"
  printf '#!/bin/sh\nexit 1\n' >"$hooks/pre-commit"
  chmod +x "$hooks/pre-commit"
  printf '[core]\n\thooksPath = %s\n' "$hooks" >"$base/gitconfig"
  F="$base/shop"
  GIT_CONFIG_GLOBAL="$base/gitconfig" "$BUILDER" "$F" >/dev/null 2>&1
  [ $? -eq 0 ] && [ "$(commit_count)" -eq 1 ]
}

test_build_ignores_the_callers_git_environment() {
  local base first
  build
  first=$(git -C "$F" rev-parse HEAD)
  [ "$BRC" -eq 0 ] && [ -n "$first" ] || return 1
  base=$(mktemp -d)
  TMPS="$TMPS $base"
  mkdir -p "$base/xdg/git"
  printf '*.sql\nappsettings.json\n' >"$base/xdg/git/ignore"
  F="$base/shop"
  GIT_AUTHOR_NAME=Someone GIT_AUTHOR_EMAIL=real@example.com GIT_COMMITTER_NAME=Someone GIT_COMMITTER_EMAIL=real@example.com \
    GIT_AUTHOR_DATE=2001-01-01T00:00:00 EMAIL=real@example.com GIT_DIR="$base/elsewhere.git" XDG_CONFIG_HOME="$base/xdg" \
    "$BUILDER" "$F" >/dev/null 2>&1
  [ $? -eq 0 ] || return 1
  [ ! -e "$base/elsewhere.git" ] &&
    [ "$(git -C "$F" rev-parse HEAD)" = "$first" ] &&
    git -C "$F" ls-files | grep -q 'Scripts/001_create_orders.sql' &&
    git -C "$F" ls-files | grep -q 'src/Shop.Api/appsettings.json'
}

# fake_git_failing_commit <dir> <n>: puts a git in <dir>/bin that works until its n-th `commit`, which fails.
fake_git_failing_commit() {
  local dir=$1 n=$2 realgit
  realgit=$(command -v git)
  mkdir -p "$dir/bin"
  printf '#!/bin/sh\nfor a in "$@"; do\n  if [ "$a" = commit ]; then\n    c=$(cat "%s/count" 2>/dev/null || echo 0)\n    c=$((c + 1))\n    echo "$c" >"%s/count"\n    [ "$c" -ge %s ] && exit 1\n  fi\ndone\nexec %s "$@"\n' \
    "$dir" "$dir" "$n" "$realgit" >"$dir/bin/git"
  chmod +x "$dir/bin/git"
}

test_a_failing_git_commit_fails_the_build() {
  local base
  base=$(mktemp -d)
  TMPS="$TMPS $base"
  fake_git_failing_commit "$base" 1
  PATH="$base/bin:$PATH" "$BUILDER" "$base/shop" >"$base/out" 2>&1
  [ $? -ne 0 ] && ! grep -q '^v1 ' "$base/out" || return 1
  # The second commit is the case that matters: the first one has already given HEAD a value.
  base=$(mktemp -d)
  TMPS="$TMPS $base"
  fake_git_failing_commit "$base" 2
  PATH="$base/bin:$PATH" "$BUILDER" "$base/shop" --v2 >"$base/out" 2>&1
  [ $? -ne 0 ] && grep -q '^v1 ' "$base/out" && ! grep -q '^v2 ' "$base/out"
}

test_legacy_bus_callers_include_the_hidden_one() {
  local callers
  build
  callers=$(cd "$F" && grep -rl 'LegacyBusClient' src | xargs -n1 basename | sort | tr '\n' ' ')
  [ "$callers" = "InvoiceService.cs LegacyBusClient.cs NightlySyncJob.cs OrderSubmissionService.cs Program.cs " ]
}

test_customers_has_no_bus_dependency() {
  build
  ! grep -qi 'LegacyBus' "$F/src/Shop.Api/Controllers/CustomersController.cs" &&
    has_text src/Shop.Api/Controllers/CustomersController.cs 'api/customers'
}

test_endpoints_and_roles_are_discoverable() {
  build
  local c=src/Shop.Api/Controllers/OrdersController.cs
  has_text "$c" '"api/orders"' && has_text "$c" 'HttpPost("{id}/submit")' && has_text "$c" 'HttpGet("{id}/invoice")' &&
    has_text "$c" 'Roles = "Clerk"' && has_text "$c" 'Roles = "Manager"' &&
    has_text src/Shop.Domain/AppRole.cs 'Clerk' && has_text src/Shop.Domain/AppRole.cs 'Manager' &&
    has_text src/Shop.Domain/AppRole.cs 'Admin' &&
    has_text src/Shop.Api/Jobs/NightlySyncJob.cs 'IHostedService'
}

test_runtime_conflict_is_planted() {
  build
  has_text README.md '\.NET 6' && has_text src/Shop.Api/Shop.Api.csproj 'net8.0'
}

test_secret_and_endpoint_key_are_planted() {
  build
  has_text src/Shop.Api/appsettings.json 'Password=FIXTURE-NOT-A-SECRET' &&
    has_text src/Shop.Api/appsettings.json '"LegacyBus"' && has_text src/Shop.Api/appsettings.json '"Endpoint"'
}

test_pipeline_has_four_stages() {
  local s
  build
  for s in 'Build' 'Deploy Dev' 'Deploy Test' 'Deploy Prod'; do has_text azure-pipelines.yml "displayName: $s" || return 1; done
}

test_v2_changes_are_the_expected_ones() {
  build --v2
  [ "$(git -C "$F" diff --name-only HEAD~1 HEAD | sort | tr '\n' ' ')" = \
    "docs/userGuide/cancel.md src/Shop.Api/Controllers/OrdersController.cs src/Shop.Api/Shop.Api.csproj src/Shop.Integration/LegacyBusClient.cs " ] || return 1
  has_text src/Shop.Api/Shop.Api.csproj 'net9.0' && ! has_text src/Shop.Api/Shop.Api.csproj 'net8.0' &&
    has_text src/Shop.Api/Controllers/OrdersController.cs 'HttpPost("{id}/cancel")' &&
    has_text src/Shop.Integration/LegacyBusClient.cs 'CancelAsync' &&
    git -C "$F" show HEAD~1:src/Shop.Api/Shop.Api.csproj | grep -q 'net8.0'
}

test_expected_facts_covers_every_question() {
  local n f="$HERE/expected-facts.md"
  [ -f "$f" ] || return 1
  for n in 1 2 3 4 5 6 7 8 9; do grep -q "^## Q$n " "$f" || return 1; done
  grep -q '^## After --v2' "$f"
}

test_user_guide_term_differs_from_code_name() {
  build
  grep -qi 'order value' "$F/docs/userGuide/orders.md" &&
    ! grep -rqi 'order value' "$F/src"
}

echo "make-fixture.sh"
check "v1 has one commit and prints its hash" test_v1_has_one_commit
check "--v2 has two commits and prints both hashes" test_v2_has_two_commits
check "all expected files exist, and cancel.md only in v2" test_expected_files_exist
check "working tree is clean after the build" test_working_tree_is_clean_after_build
check "author and committer emails are not real" test_fixture_identity_is_not_real
check "refuses a destination that exists" test_refuses_existing_dest
check "bad arguments exit 2" test_bad_arguments_exit_2
check "two builds give the same commit hash" test_build_is_deterministic
check "the user's git hooks are not run" test_ignores_the_users_git_hooks
check "the caller's git environment and global ignore file are ignored" test_build_ignores_the_callers_git_environment
check "a failing git commit fails the build" test_a_failing_git_commit_fails_the_build
check "LegacyBusClient has the three callers, including the hidden job" test_legacy_bus_callers_include_the_hidden_one
check "CustomersController has no LegacyBus dependency" test_customers_has_no_bus_dependency
check "endpoints, roles and the hosted service are discoverable" test_endpoints_and_roles_are_discoverable
check ".NET 6 in the README conflicts with net8.0 in the csproj" test_runtime_conflict_is_planted
check "the fake secret and the LegacyBus endpoint key are in appsettings.json" test_secret_and_endpoint_key_are_planted
check "the pipeline has Build and three Deploy stages" test_pipeline_has_four_stages
check "--v2 changes only the four expected files" test_v2_changes_are_the_expected_ones
check "expected-facts.md covers questions 1 to 9 and the --v2 changes" test_expected_facts_covers_every_question
check "the user guide says order value, and no file under src/ does" test_user_guide_term_differs_from_code_name

echo
echo "passed=$PASS failed=$FAIL"
echo "temp folders left in place:$TMPS"
[ "$FAIL" -eq 0 ]
