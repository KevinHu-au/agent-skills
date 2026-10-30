#!/usr/bin/env bash
# Tests for check-brief.sh. Each test builds a brief in a throwaway folder and runs the checker.
# It deletes nothing: the temp folders are left for the OS to clear, and listed at the end.
# Usage: tests/onboard/test-check-brief.sh
set -u

HERE=$(cd "$(dirname "$0")" && pwd -P)
CHECKER="$HERE/check-brief.sh"
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

new_dir() {
  D=$(mktemp -d)
  TMPS="$TMPS $D"
}

# write_brief <dir> [section...]: a good brief. Sections default to the ten in order.
# NO_SOURCES_FOR=<section> leaves that section's Sources line out.
write_brief() {
  local dir=$1 s
  shift
  [ $# -gt 0 ] || set -- "First-ticket checklist" "Purpose and users" "Use cases" "Start here" \
    "Architecture and patterns" "Data model" "External systems" "Run and verify" "Risks and delivery" "Unknowns"
  {
    printf '# Shop onboarding brief\n\n'
    printf 'Scanned commit: 0123456789abcdef0123456789abcdef01234567\n'
    printf 'Scanned on: 2026-10-21\n'
    printf 'Working tree: clean\n'
    printf 'Repo policy: tools both; files local only\n\n'
    for s in "$@"; do
      printf '## %s\n\n' "$s"
      case "$s" in
        "First-ticket checklist")
          printf '1. App purpose and users: [Purpose and users](#purpose-and-users)\n'
          printf '2. Main use cases: [Use cases](#use-cases), see [use-cases.md](use-cases.md#top)\n'
          printf '3. Run and check a change: [Run and verify](#run-and-verify)\n'
          printf '4. Pattern to copy: [Architecture and patterns](#architecture-and-patterns)\n'
          printf '5. Data entities: [Data model](#data-model)\n'
          printf '6. External systems: [External systems](#external-systems)\n'
          printf '7. Never do or commit: [Risks and delivery](#risks-and-delivery)\n'
          printf '8. unknown: ask the delivery owner how a ticket ships\n'
          printf '9. Feature code: [Start here](#start-here)\n\n'
          ;;
        "Start here")
          printf '```mermaid\nflowchart LR\n```\n\n'
          printf 'Feature to code map: [feature-to-code.md](feature-to-code.md)\n\n'
          [ "${NO_SOURCES_FOR:-}" = "$s" ] || printf 'Sources: README.md:1\n\n'
          ;;
        "Use cases")
          printf 'Clerks submit orders. See the [vendor guide](https://example.com/guide.md).\n\n'
          [ "${NO_SOURCES_FOR:-}" = "$s" ] || printf 'Sources: src/Shop.Api/Controllers/OrdersController.cs:12\n\n'
          ;;
        "Unknowns")
          printf -- '- unknown: who owns the nightly sync\n'
          ;;
        *)
          printf 'Text for %s.\n\n' "$s"
          [ "${NO_SOURCES_FOR:-}" = "$s" ] || printf 'Sources: README.md:1\n\n'
          ;;
      esac
    done
  } >"$dir/README.md"
  printf '# Use cases\n' >"$dir/use-cases.md"
  printf '# Feature to code\n\nScan: src/Shop.Api/Controllers/OrdersController.cs\nScan: src/Shop.Core/Order.cs\n' >"$dir/feature-to-code.md"
  [ "${NO_CONTRACT:-}" = 1 ] || write_contract "$dir" "read-only, told by the DBA"
}

# write_contract <dir> <access rule>: a contract.md with the five headings and one Data access row.
write_contract() {
  {
    printf '## Project contract\n\n### Commands\n\n- **Build:** inferred: from the pipeline\n\n### Verify\n\n'
    printf -- '- **Start the app:** unknown: ask the lead\n\n### Data access\n\n'
    printf '| Environment | URL | Database | Access rule | Who approves access |\n|---|---|---|---|---|\n'
    printf '| Dev | none | shop_dev | %s | the DBA |\n\n' "$2"
    printf '### Risk areas\n\n- **Database:** unknown: ask the DBA\n\n### External systems and owners\n\n- none\n'
  } >"$1/contract.md"
}

# R13
test_missing_repo_policy_warns() {
  new_dir
  write_brief "$D"
  edit_readme "$D" '/^Repo policy:/d'
  run_checker "$D"
  warn_only R13 "missing or malformed"
}

test_bad_repo_policy_warns() {
  new_dir
  write_brief "$D"
  edit_readme "$D" 's/^Repo policy: .*/Repo policy: tools Cursor; files maybe/'
  run_checker "$D"
  warn_only R13 "missing or malformed"
}

# R14
test_missing_contract_warns() {
  new_dir
  NO_CONTRACT=1 write_brief "$D"
  run_checker "$D"
  warn_only R14 "does not exist"
}

test_contract_headings_out_of_order_warn() {
  new_dir
  write_brief "$D"
  printf '## Project contract\n\n### Verify\n\n### Commands\n\n### Data access\n\n### Risk areas\n\n### External systems and owners\n' \
    >"$D/contract.md"
  run_checker "$D"
  warn_only R14 "headings"
}

# R15
test_inferred_access_rule_fails() {
  new_dir
  write_brief "$D"
  write_contract "$D" "inferred: read-only, the login name says reader"
  fails_only "$D" R15
}

test_access_rule_without_source_warns() {
  new_dir
  write_brief "$D"
  write_contract "$D" "read-only"
  run_checker "$D"
  warn_only R15 "cites no source"
}

# A backticked rule word is not a source. A backticked path is.
test_backticked_rule_word_warns() {
  new_dir
  write_brief "$D"
  write_contract "$D" '`read-only`'
  run_checker "$D"
  warn_only R15 "cites no source"
}

test_capitalised_rule_without_source_warns() {
  new_dir
  write_brief "$D"
  write_contract "$D" "Read only"
  run_checker "$D"
  warn_only R15 "cites no source"
}

# The rule column is found by its header, so a table in another column order is still checked.
test_inferred_rule_in_another_column_order_fails() {
  new_dir
  write_brief "$D"
  {
    printf '## Project contract\n\n### Commands\n\n### Verify\n\n### Data access\n\n'
    printf '| Access rule | Environment | Who approves access |\n|---|---|---|\n'
    printf '| inferred: read-only | Prod | the DBA |\n\n'
    printf '### Risk areas\n\n### External systems and owners\n'
  } >"$D/contract.md"
  fails_only "$D" R15
}

# An H4 under a heading is allowed.
test_contract_sub_heading_passes() {
  new_dir
  write_brief "$D"
  {
    printf '## Project contract\n\n### Commands\n\n### Verify\n\n### Data access\n\n#### Prod notes\n\n'
    printf '| Environment | URL | Database | Access rule | Who approves access |\n|---|---|---|---|---|\n'
    printf '| Prod | none | shop | none, told by the DBA | the DBA |\n\n'
    printf '### Risk areas\n\n### External systems and owners\n'
  } >"$D/contract.md"
  passes_clean "$D"
}

test_access_rule_with_a_document_passes() {
  new_dir
  write_brief "$D"
  write_contract "$D" 'read-only, `docs/access.md:3`'
  passes_clean "$D"
}

# run_checker <dir>: sets OUT and RC.
run_checker() {
  OUT=$("$CHECKER" "$1" 2>&1)
  RC=$?
}

# edit_readme <dir> <sed-script>: BSD sed has no safe -i, so write a new file and move it.
edit_readme() {
  sed "$2" "$1/README.md" >"$1/README.md.new" && mv "$1/README.md.new" "$1/README.md"
}

# fails_only <dir> <rule>: exit 1, at least one FAIL, and every FAIL is for <rule>.
fails_only() {
  run_checker "$1"
  [ "$RC" -eq 1 ] || return 1
  printf '%s\n' "$OUT" | grep -q "^FAIL $2:" || return 1
  ! printf '%s\n' "$OUT" | grep '^FAIL ' | grep -qv "^FAIL $2:"
}

passes_clean() {
  run_checker "$1"
  [ "$RC" -eq 0 ] && ! printf '%s\n' "$OUT" | grep -q '^FAIL \|^WARN '
}

test_missing_readme_fails() {
  new_dir
  fails_only "$D" R1 || return 1
  fails_only "$D/not-there" R1
}

test_no_argument_prints_usage_and_exits_2() {
  "$CHECKER" >/dev/null 2>&1
  [ $? -eq 2 ]
}

test_good_brief_passes() {
  new_dir
  write_brief "$D"
  passes_clean "$D"
}

test_missing_header_field_fails() {
  local f
  for f in 'Scanned commit:' 'Scanned on:' 'Working tree:'; do
    new_dir
    write_brief "$D"
    edit_readme "$D" "/^$f/d"
    fails_only "$D" R2 || return 1
  done
}

test_bad_header_value_fails() {
  local pair
  for pair in 'Scanned commit: xyz' 'Scanned on: 21/10/2026' 'Working tree: maybe'; do
    new_dir
    write_brief "$D"
    edit_readme "$D" "s|^${pair%%:*}:.*|$pair|"
    fails_only "$D" R2 || return 1
  done
}

test_commit_length_bounds() {
  local hash
  for hash in abc1234 0123456789abcdef0123456789abcdef01234567; do
    new_dir
    write_brief "$D"
    edit_readme "$D" "s|^Scanned commit: .*|Scanned commit: $hash|"
    passes_clean "$D" || return 1
  done
  for hash in abc123 0123456789abcdef0123456789abcdef012345678; do
    new_dir
    write_brief "$D"
    edit_readme "$D" "s|^Scanned commit: .*|Scanned commit: $hash|"
    run_checker "$D"
    # A 41 character value is not a valid hash, so R6 reads it as a token as well as R2 rejecting it.
    [ "$RC" -eq 1 ] && printf '%s\n' "$OUT" | grep -q '^FAIL R2:' || return 1
    ! printf '%s\n' "$OUT" | grep '^FAIL ' | grep -qvE '^FAIL (R2|R6):' || return 1
  done
}

test_missing_checklist_item_fails() {
  new_dir
  write_brief "$D"
  edit_readme "$D" '/^5\. /d'
  fails_only "$D" R3
}

test_checklist_item_without_link_or_unknown_fails() {
  new_dir
  write_brief "$D"
  edit_readme "$D" 's|^5\. .*|5. Data entities are described somewhere|'
  fails_only "$D" R3
}

test_item_outside_checklist_does_not_count() {
  new_dir
  write_brief "$D"
  edit_readme "$D" '/^8\. /d'
  printf '8. unknown: hidden in the wrong section\n' >>"$D/README.md"
  fails_only "$D" R3
}

test_missing_checklist_item_9_fails() {
  new_dir
  write_brief "$D"
  edit_readme "$D" '/^9\. /d'
  fails_only "$D" R3
}

test_start_here_with_two_mermaid_blocks_fails() {
  new_dir
  write_brief "$D"
  awk '{ print } /^## Start here$/ { print ""; print "```mermaid"; print "flowchart LR"; print "```" }' \
    "$D/README.md" >"$D/README.md.new" && mv "$D/README.md.new" "$D/README.md"
  fails_only "$D" R11
}

test_start_here_with_no_mermaid_block_fails() {
  new_dir
  write_brief "$D"
  edit_readme "$D" '/^```mermaid$/,/^```$/d'
  fails_only "$D" R11
}

test_key_concept_unknown_passes() {
  new_dir
  write_brief "$D"
  awk '/^```mermaid$/ { skip = 1; print "Key concept: unknown: ask the product owner"; next } skip && /^```$/ { skip = 0; next } !skip' \
    "$D/README.md" >"$D/README.md.new" && mv "$D/README.md.new" "$D/README.md"
  grep -q '^Key concept: unknown:' "$D/README.md" || return 1
  passes_clean "$D"
}

test_missing_feature_to_code_fails_r12() {
  new_dir
  write_brief "$D"
  # Move the file aside instead of deleting it, and drop the link, so R7 stays quiet.
  mv "$D/feature-to-code.md" "$D/feature-to-code.md.gone"
  edit_readme "$D" '/feature-to-code\.md/d'
  run_checker "$D"
  [ "$RC" -eq 1 ] && printf '%s\n' "$OUT" | grep -q '^FAIL R12:'
}

test_missing_feature_to_code_link_fails_only_r12() {
  new_dir
  write_brief "$D"
  # Keep feature-to-code.md and drop only the link line, so R7 stays quiet.
  edit_readme "$D" '/feature-to-code\.md/d'
  fails_only "$D" R12
}

test_missing_start_here_fails_only_r4() {
  new_dir
  write_brief "$D" "First-ticket checklist" "Purpose and users" "Use cases" "Architecture and patterns" \
    "Data model" "External systems" "Run and verify" "Risks and delivery" "Unknowns"
  fails_only "$D" R4
}

test_missing_section_fails() {
  new_dir
  write_brief "$D" "First-ticket checklist" "Purpose and users" "Use cases" "Architecture and patterns" \
    "Data model" "Run and verify" "Risks and delivery" "Unknowns"
  fails_only "$D" R4
}

test_section_order_fails() {
  new_dir
  write_brief "$D" "First-ticket checklist" "Purpose and users" "Data model" "Use cases" "Architecture and patterns" \
    "External systems" "Run and verify" "Risks and delivery" "Unknowns"
  fails_only "$D" R4 || return 1
  new_dir
  write_brief "$D" "Purpose and users" "First-ticket checklist" "Use cases" "Architecture and patterns" \
    "Data model" "External systems" "Run and verify" "Risks and delivery" "Unknowns"
  fails_only "$D" R4
}

test_missing_sources_line_fails() {
  new_dir
  NO_SOURCES_FOR="Use cases" write_brief "$D"
  fails_only "$D" R5 || return 1
  new_dir
  NO_SOURCES_FOR="Risks and delivery" write_brief "$D"
  fails_only "$D" R5
}

test_secret_value_fails() {
  local line
  for line in 'Password=FIXTURE-NOT-A-SECRET' 'pwd=FIXTURE-NOT-A-SECRET' 'AccountKey=FIXTURE' 'SharedAccessKey=FIXTURE' \
    '-----BEGIN FAKE KEY-----' 'FIXTURENOTASECRET12FIXTURENOTASECRET'; do
    new_dir
    write_brief "$D"
    printf '%s\n' "$line" >>"$D/README.md"
    fails_only "$D" R6 || return 1
  done
}

test_secret_in_side_file_fails() {
  new_dir
  write_brief "$D"
  printf 'Password=FIXTURE-NOT-A-SECRET\n' >"$D/integrations.md"
  fails_only "$D" R6
}

test_long_word_without_digit_is_not_a_secret() {
  new_dir
  write_brief "$D"
  printf 'OrderSubmissionServiceFactoryProviderImplementation\n' >>"$D/README.md"
  passes_clean "$D"
}

# R6: a plain identifier (letters, then at most four trailing digits) is not a secret, however long.
test_long_identifier_with_trailing_digits_is_not_a_secret() {
  new_dir
  write_brief "$D"
  printf 'GetCustomerOrderSummaryForPeriod2024\n' >>"$D/README.md"
  passes_clean "$D"
}

test_long_hex_token_still_fails() {
  new_dir
  write_brief "$D"
  printf 'abcdef0123456789abcdef0123456789\n' >>"$D/README.md"
  fails_only "$D" R6
}

test_long_token_with_digits_in_the_middle_still_fails() {
  new_dir
  write_brief "$D"
  printf 'abcdefghij1234567890abcdefghij12\n' >>"$D/README.md"
  fails_only "$D" R6
}

test_long_letters_then_five_digits_still_fails() {
  new_dir
  write_brief "$D"
  printf 'OrderSubmissionServiceFactoryProvider12345\n' >>"$D/README.md"
  fails_only "$D" R6
}

# looks_secret follows the same rule: an identifier is shown in an R9 message, a token with digits in the middle is hidden.
test_looks_secret_shows_a_plain_identifier() {
  new_repo
  set_f2c "$PACK" '`src/GetCustomerOrderSummaryForPeriod2024`' none
  run_checker_root "$PACK" "$REPO"
  printf '%s\n' "$OUT" | grep -q "^FAIL R9: feature-to-code.md: 'src/GetCustomerOrderSummaryForPeriod2024' " || return 1
  new_repo
  set_f2c "$PACK" '`src/abcdefghij1234567890abcdefghij12`' none
  run_checker_root "$PACK" "$REPO"
  printf '%s\n' "$OUT" | grep -q '^FAIL R9:' && ! printf '%s\n' "$OUT" | grep -q 'abcdefghij1234567890'
}

test_broken_side_link_fails() {
  new_dir
  write_brief "$D"
  printf 'See [missing](nope.md).\n' >>"$D/README.md"
  fails_only "$D" R7
}

test_long_brief_warns_but_passes() {
  new_dir
  write_brief "$D"
  awk 'BEGIN { for (i = 0; i < 2500; i++) printf "word "; printf "\n" }' >>"$D/README.md"
  run_checker "$D"
  [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -q '^WARN R8:' && ! printf '%s\n' "$OUT" | grep -q '^FAIL '
}

test_provider_secret_formats_fail() {
  local line
  for line in 'xo''xb-000000000000-000000000000-FAKEFAKEFAKEFAKE' 'sk_li''ve_FAKEFAKEFAKE' 'AKI''AFAKEFAKEFAKEFAKE' \
    'gh''p_FAKEFAKEFAKEFAKEFAKEFAKE' 'ey''JFAKEFAKEFAKE.eyJFAKEFAKEFAKE.FAKEFAKEFAKE'; do
    new_dir
    write_brief "$D"
    printf '%s\n' "$line" >>"$D/README.md"
    fails_only "$D" R6 || return 1
  done
}

test_scanned_commit_exemption_covers_only_a_valid_hash_line() {
  new_dir
  write_brief "$D"
  printf 'Scanned commit: Aq9Zr3Tt7Yy1Uu5Ii8Oo2Pp4Ll6Kk0Jj3Hh\n' >>"$D/README.md"
  fails_only "$D" R6 || return 1
  new_dir
  write_brief "$D"
  printf 'Scanned commit: Aq9Zr3Tt7Yy1Uu5Ii8Oo2Pp4Ll6Kk0Jj3Hh\n' >"$D/open-questions.md"
  fails_only "$D" R6 || return 1
  new_dir
  write_brief "$D"
  printf 'Scanned commit: 0123456789abcdef0123456789abcdef01234567\nScanned on: 2026-10-21\n' >"$D/open-questions.md"
  passes_clean "$D"
}

test_heading_marks_inside_a_code_fence_are_not_headings() {
  new_dir
  write_brief "$D"
  awk '{ print } /^Text for Run and verify\.$/ { print ""; print "```bash"; print "## a shell comment, not a heading"; print "```" }' \
    "$D/README.md" >"$D/README.md.new" && mv "$D/README.md.new" "$D/README.md"
  grep -q '^## a shell comment' "$D/README.md" || return 1
  passes_clean "$D"
}

test_link_forms_with_a_title_or_angle_brackets_are_checked() {
  new_dir
  write_brief "$D"
  printf 'See [a](nope.md "a title").\n' >>"$D/README.md"
  fails_only "$D" R7 || return 1
  new_dir
  write_brief "$D"
  printf 'See [b](<nope2.md>).\n' >>"$D/README.md"
  fails_only "$D" R7 || return 1
  new_dir
  write_brief "$D"
  printf 'See [c](use-cases.md "a title") and [d](<use-cases.md>).\n' >>"$D/README.md"
  passes_clean "$D"
}

test_crlf_brief_is_checked_like_an_lf_brief() {
  new_dir
  write_brief "$D"
  awk '{ printf "%s\r\n", $0 }' "$D/README.md" >"$D/README.md.new" && mv "$D/README.md.new" "$D/README.md"
  passes_clean "$D"
}

test_empty_sources_line_warns_but_passes() {
  new_dir
  write_brief "$D"
  edit_readme "$D" 's|^Sources: README.md:1$|Sources:|'
  run_checker "$D"
  [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -q '^WARN R5:' && ! printf '%s\n' "$OUT" | grep -q '^FAIL ' || return 1
  edit_readme "$D" 's|^Sources:$|Sources: told by the engineer|'
  passes_clean "$D"
}

test_a_stray_byte_does_not_hide_a_secret() {
  # Under a UTF-8 locale, grep, sed and awk choke on an invalid byte. The checker must not depend on the locale.
  locale -a 2>/dev/null | grep -qix 'en_US.UTF-8' || return 0
  new_dir
  write_brief "$D"
  printf 'caf\222 Password=FIXTURE-NOT-A-SECRET\n' >>"$D/README.md"
  LC_ALL=en_US.UTF-8 run_checker "$D"
  [ "$RC" -eq 1 ] && printf '%s\n' "$OUT" | grep -q '^FAIL R6:' && ! printf '%s\n' "$OUT" | grep -q 'FIXTURE-NOT-A-SECRET'
}

# Start from a clean git environment, as make-fixture.sh:30-33 does. Nothing the caller exported (GIT_*, EMAIL) or
# keeps in a global config may change the fixture repositories or the checker's git calls.
for v in $(env | sed -n 's/^\(GIT_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$v"; done
unset EMAIL
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
g() { git -C "$REPO" -c core.hooksPath=/dev/null -c core.excludesFile=/dev/null -c commit.gpgsign=false "$@"; }

# new_repo: sets REPO (a git repository with src/app.txt, 20 lines and no final newline, and src/terms.txt) and
# PACK ($REPO/docs/onboarding, an untracked good brief). The identity is local, as in make-fixture.sh:477-479.
new_repo() {
  REPO=$(mktemp -d)
  TMPS="$TMPS $REPO"
  git init -q --template= -b main "$REPO"
  g config user.name Fixture
  g config user.email fixture@example.invalid
  mkdir -p "$REPO/src"
  awk 'BEGIN { for (i = 1; i <= 20; i++) { printf "line %d", i; if (i < 20) printf "\n" } }' >"$REPO/src/app.txt"
  printf '%s\n' 'shp_dt' "it's" '-x' 'a.b[0]' >"$REPO/src/terms.txt"
  g add src
  g commit -q -m "Add src"
  PACK="$REPO/docs/onboarding"
  mkdir -p "$PACK"
  write_brief "$PACK"
}

# set_f2c <dir> <loads-cell> <calcs-cell> [<term-rows>]: feature-to-code.md with one use case block.
# The cells and term rows are written as given, so a test can put backticks, markers or CRLF-free text in them.
set_f2c() {
  {
    printf '# Feature to code\n\nScanned commit: 0123456789abcdef0123456789abcdef01234567\nScanned on: 2026-10-21\n\n'
    printf '## Submit order\n\n| Layer | Data loads in | Calculations and rules in |\n|---|---|---|\n'
    printf '| api | %s | %s |\n\n' "$2" "$3"
    printf '### Search terms\n\n| Business term | api | db |\n|---|---|---|\n'
    if [ $# -ge 4 ]; then printf '%s\n' "$4"; else printf '| order value | `shp_dt` | none |\n'; fi
    printf '\nSources: src/app.txt:1\n'
  } >"$1/feature-to-code.md"
}

# add_start_line <dir> <text>: a line in Start here, straight after the feature-to-code.md link.
add_start_line() {
  awk -v t="$2" '{ print } /^Feature to code map:/ { print t }' "$1/README.md" >"$1/README.md.new" &&
    mv "$1/README.md.new" "$1/README.md"
}

# run_checker_root <dir> <root>: sets OUT and RC.
run_checker_root() {
  OUT=$("$CHECKER" "$1" "$2" 2>&1)
  RC=$?
}

# passes_root: exit 0, no FAIL or WARN, and no NOTE (so R9 and R10 did run).
passes_root() {
  run_checker_root "$PACK" "$REPO"
  [ "$RC" -eq 0 ] && ! printf '%s\n' "$OUT" | grep -q '^FAIL \|^WARN \|^NOTE R9:\|^NOTE R10:'
}

# root_fails_only <rule>: exit 1, at least one FAIL, and every FAIL is for <rule>.
root_fails_only() {
  run_checker_root "$PACK" "$REPO"
  [ "$RC" -eq 1 ] || return 1
  printf '%s\n' "$OUT" | grep -q "^FAIL $1:" || return 1
  ! printf '%s\n' "$OUT" | grep '^FAIL ' | grep -qv "^FAIL $1:"
}

test_three_arguments_print_usage_and_exit_2() {
  OUT=$("$CHECKER" a b c 2>&1)
  RC=$?
  [ "$RC" -eq 2 ] && printf '%s\n' "$OUT" | grep -q '^usage:'
}

test_root_that_is_not_a_repository_exits_2() {
  new_repo
  new_dir
  run_checker_root "$PACK" "$D"
  [ "$RC" -eq 2 ] && printf '%s\n' "$OUT" | grep -q '^usage:'
}

test_subfolder_root_exits_2() {
  new_repo
  run_checker_root "$PACK" "$REPO/src"
  [ "$RC" -eq 2 ] && printf '%s\n' "$OUT" | grep -q '^usage:'
}

test_one_argument_skips_repo_checks_with_a_note() {
  new_dir
  write_brief "$D"
  passes_clean "$D" || return 1
  printf '%s\n' "$OUT" | grep -q '^NOTE R9: skipped, no repository root' &&
    printf '%s\n' "$OUT" | grep -q '^NOTE R10: skipped, no repository root'
}

test_good_paths_and_terms_pass_with_a_root() {
  new_repo
  add_start_line "$PACK" 'Open: `./src/app.txt`'
  set_f2c "$PACK" '`src/app.txt:20`' '`src/` and `src/terms.txt:4`' \
    "$(printf '%s\n' '| order value | `shp_dt` | `it'"'"'s` |' '| other | `-x` | `a.b[0]` |')"
  passes_root
}

test_missing_path_fails_r9() {
  new_repo
  set_f2c "$PACK" '`src/nope.txt`' none
  root_fails_only R9 || return 1
  printf '%s\n' "$OUT" | grep -q "^FAIL R9: feature-to-code.md: 'src/nope.txt' "
}

# The columns after the layer are named by the pack's author. R9 reads every one of them, however many there are.
set_f2c_columns() {
  {
    printf '# Feature to code\n\nScanned commit: 0123456789abcdef0123456789abcdef01234567\nScanned on: 2026-10-21\n\n'
    printf '## Submit order\n\n%s\n%s\n%s\n\n' "$2" "$3" "$4"
    printf '### Search terms\n\n| Business term | api | db |\n|---|---|---|\n| order value | `shp_dt` | none |\n\nSources: src/app.txt:1\n'
  } >"$1/feature-to-code.md"
}

test_one_path_column_with_any_title_passes_r9() {
  new_repo
  set_f2c_columns "$PACK" '| Layer | Entry point |' '|---|---|' '| api | `src/app.txt:1` |'
  passes_root
}

test_path_in_a_fourth_column_is_checked_by_r9() {
  new_repo
  set_f2c_columns "$PACK" '| Layer | Entry point | Key business logic | Tests |' '|---|---|---|---|' '| api | `src/app.txt:1` | none | `src/nope.txt` |'
  root_fails_only R9 || return 1
  printf '%s\n' "$OUT" | grep -q "^FAIL R9: feature-to-code.md: 'src/nope.txt' "
}

test_missing_start_here_path_fails_r9() {
  new_repo
  add_start_line "$PACK" 'Pattern: `src/nope.txt`'
  root_fails_only R9 || return 1
  printf '%s\n' "$OUT" | grep -q "^FAIL R9: README.md: 'src/nope.txt' "
}

test_line_past_end_of_file_fails_r9() {
  new_repo
  set_f2c "$PACK" '`src/app.txt:21`' none
  root_fails_only R9
}

test_line_range_is_checked_by_its_end() {
  new_repo
  set_f2c "$PACK" '`src/app.txt:13-24`' none
  root_fails_only R9 || return 1
  set_f2c "$PACK" '`src/app.txt:13-20`' none
  passes_root
}

test_folder_path_passes_without_a_line_number() {
  new_repo
  set_f2c "$PACK" '`src/`' '`src`'
  passes_root || return 1
  set_f2c "$PACK" '`src/:3`' none
  root_fails_only R9
}

test_untracked_file_passes_r9() {
  new_repo
  printf 'one\ntwo\n' >"$REPO/src/new.txt"
  set_f2c "$PACK" '`src/new.txt:2`' '`src/new.txt`'
  passes_root
}

test_untracked_term_passes_r10() {
  new_repo
  printf 'brand_new_term\n' >"$REPO/src/new.txt"
  set_f2c "$PACK" none none '| order value | `brand_new_term` | none |'
  passes_root
}

test_header_separator_and_marker_cells_are_skipped() {
  new_repo
  {
    printf '# Feature to code\n\n## Submit order\n\n'
    printf '| Layer | `no_such_path` | `no_such_path2` |\n|---|---|---|\n'
    printf '| api | none | unknown: ask the owner |\n'
    printf '| db | inferred: no caller found | none |\n\n'
    printf '### Search terms\n\n| Business term | `no_such_term` | `no_such_term2` |\n|---|---|---|\n'
    printf '| order value | none | unknown: ask the owner |\n'
    printf '| other | inferred: no caller found | none |\n'
  } >"$PACK/feature-to-code.md"
  passes_root
}

test_changed_marker_cell_is_read() {
  new_repo
  set_f2c "$PACK" 'changed: `src/missing.txt`' none
  root_fails_only R9 || return 1
  set_f2c "$PACK" 'changed: `src/app.txt`' none
  passes_root || return 1
  set_f2c "$PACK" none none '| order value | changed: `no_such_term` | none |'
  root_fails_only R10 || return 1
  set_f2c "$PACK" none none '| order value | changed: `shp_dt` | none |'
  passes_root
}

test_run_line_and_search_terms_are_not_paths() {
  new_repo
  printf 'GetTotals\n' >"$REPO/src/GetTotals.sql"
  add_start_line "$PACK" 'Run: `make build app.sln`'
  set_f2c "$PACK" none none '| order value | `GetTotals` | none |'
  passes_root
}

test_missing_search_term_fails_r10() {
  new_repo
  set_f2c "$PACK" none none '| order value | `no_such_term` | none |'
  root_fails_only R10 || return 1
  printf '%s\n' "$OUT" | grep -q "^FAIL R10: 'no_such_term' not found outside docs/onboarding"
}

test_term_search_is_case_sensitive() {
  new_repo
  set_f2c "$PACK" none none '| order value | `SHP_DT` | none |'
  root_fails_only R10
}

test_term_found_only_in_the_pack_fails_r10() {
  new_repo
  set_f2c "$PACK" none none '| order value | `only_in_pack_term` | none |'
  g add docs
  g commit -q -m "Add pack"
  root_fails_only R10 || return 1
  # The same term in code passes, so the failure above came from the exclusion and not from a broken run.
  printf 'only_in_pack_term\n' >"$REPO/src/new.txt"
  passes_root
}

test_pack_under_a_symlinked_temp_path_is_excluded() {
  local link
  new_repo
  set_f2c "$PACK" none none '| order value | `only_in_pack_term` | none |'
  # The pack stays untracked, so only the exclusion keeps the term from matching. REPO is the raw mktemp path
  # (/var/... on macOS, which git resolves to /private/var/...).
  root_fails_only R10 || return 1
  # An explicit symlink to the repository gives the same result on every platform.
  new_dir
  link="$D/link"
  ln -s "$REPO" "$link"
  OUT=$("$CHECKER" "$link/docs/onboarding" "$link" 2>&1)
  RC=$?
  [ "$RC" -eq 1 ] && printf '%s\n' "$OUT" | grep -q "^FAIL R10: 'only_in_pack_term' " &&
    ! printf '%s\n' "$OUT" | grep '^FAIL ' | grep -qv '^FAIL R10:'
}

test_pack_outside_the_root_prints_a_note() {
  new_repo
  new_dir
  write_brief "$D"
  set_f2c "$D" none none '| order value | `shp_dt` | none |'
  run_checker_root "$D" "$REPO"
  [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -q '^NOTE R10: onboarding folder is outside the root, no exclusion' &&
    ! printf '%s\n' "$OUT" | grep -q '^FAIL '
}

test_business_term_column_is_not_searched() {
  new_repo
  set_f2c "$PACK" none none '| zz_nowhere_in_code | `shp_dt` | none |'
  passes_root
}

test_crlf_feature_to_code_is_checked_like_lf() {
  new_repo
  set_f2c "$PACK" '`src/app.txt:20`' '`src/`' '| order value | `shp_dt` | `a.b[0]` |'
  awk '{ printf "%s\r\n", $0 }' "$PACK/feature-to-code.md" >"$PACK/f.new" && mv "$PACK/f.new" "$PACK/feature-to-code.md"
  passes_root || return 1
  set_f2c "$PACK" '`src/nope.txt:2`' '`src/app.txt:21`' '| order value | `no_such_term` | none |'
  awk '{ printf "%s\r\n", $0 }' "$PACK/feature-to-code.md" >"$PACK/f.new" && mv "$PACK/f.new" "$PACK/feature-to-code.md"
  run_checker_root "$PACK" "$REPO"
  [ "$RC" -eq 1 ] && printf '%s\n' "$OUT" | grep -q "^FAIL R9: feature-to-code.md: 'src/nope.txt:2' " &&
    printf '%s\n' "$OUT" | grep -q "^FAIL R9: feature-to-code.md: 'src/app.txt:21' " &&
    printf '%s\n' "$OUT" | grep -q "^FAIL R10: 'no_such_term' "
}

test_relative_and_trailing_slash_root_work() {
  local parent base
  new_repo
  parent=$(dirname "$REPO")
  base=$(basename "$REPO")
  set_f2c "$PACK" '`src/app.txt:20`' none
  OUT=$(cd "$parent" && "$CHECKER" "$base/docs/onboarding/" "$base/" 2>&1)
  RC=$?
  [ "$RC" -eq 0 ] && ! printf '%s\n' "$OUT" | grep -q '^FAIL \|^NOTE R9:\|^NOTE R10:' || return 1
  OUT=$(cd "$REPO" && "$CHECKER" docs/onboarding .// 2>&1)
  RC=$?
  [ "$RC" -eq 0 ] && ! printf '%s\n' "$OUT" | grep -q '^FAIL \|^NOTE R9:\|^NOTE R10:' || return 1
  # The rules really ran: a bad path and a bad term fail in both forms.
  set_f2c "$PACK" '`src/nope.txt`' none '| order value | `no_such_term` | none |'
  OUT=$(cd "$parent" && "$CHECKER" "$base/docs/onboarding/" "$base/" 2>&1)
  RC=$?
  [ "$RC" -eq 1 ] && printf '%s\n' "$OUT" | grep -q '^FAIL R9:' && printf '%s\n' "$OUT" | grep -q '^FAIL R10:' || return 1
  OUT=$(cd "$REPO" && "$CHECKER" docs/onboarding .// 2>&1)
  RC=$?
  [ "$RC" -eq 1 ] && printf '%s\n' "$OUT" | grep -q '^FAIL R9:' && printf '%s\n' "$OUT" | grep -q '^FAIL R10:'
}

test_secret_like_path_value_is_not_printed() {
  new_repo
  set_f2c "$PACK" '`src/AKI''AFAKEFAKEFAKEFAKE`' none
  run_checker_root "$PACK" "$REPO"
  # R6 scans every .md file, so it flags this AKIA-shaped token in feature-to-code.md too. R9 reads the same value
  # as a path. The test proves both rules fail and that neither message prints the value.
  printf '%s\n' "$OUT" | grep -q '^FAIL R6:' && printf '%s\n' "$OUT" | grep -q '^FAIL R9:' &&
    ! printf '%s\n' "$OUT" | grep -q 'AKI''AFAKEFAKEFAKEFAKE'
}

# C1: R12 accepts a ./ link, like R7.
test_r12_accepts_a_dot_slash_link() {
  new_dir
  write_brief "$D"
  edit_readme "$D" 's|(feature-to-code.md)|(./feature-to-code.md)|'
  grep -q '(\./feature-to-code.md)' "$D/README.md" || return 1
  passes_clean "$D" || return 1
  edit_readme "$D" 's|(\./feature-to-code.md)|(other.md)|'
  printf '# o\n' >"$D/other.md"
  fails_only "$D" R12
}

# C2: a reversed range fails R9.
test_reversed_line_range_fails_r9() {
  new_repo
  set_f2c "$PACK" '`src/app.txt:15-5`' none
  root_fails_only R9 || return 1
  printf '%s\n' "$OUT" | grep -q "^FAIL R9: feature-to-code.md: 'src/app.txt:15-5' .*starts after" || return 1
  set_f2c "$PACK" '`src/app.txt:30-5`' none
  root_fails_only R9 || return 1
  set_f2c "$PACK" '`src/app.txt:5-5` and `src/app.txt:5-15`' none
  passes_root
}

# C3: bullet and bold forms of Open: and Pattern: are read. Run: never is.
test_bullet_and_bold_start_lines_are_read() {
  local form
  for form in '- Open: `src/nope.txt`' '* Pattern: `src/nope.txt`' '**Open:** `src/nope.txt`' \
    '- **Pattern:** `src/nope.txt`' '* **Open:** `src/nope.txt`'; do
    new_repo
    add_start_line "$PACK" "$form"
    root_fails_only R9 || return 1
    printf '%s\n' "$OUT" | grep -q "^FAIL R9: README.md: 'src/nope.txt' " || return 1
  done
  new_repo
  add_start_line "$PACK" '- Open: `src/app.txt:20`'
  add_start_line "$PACK" '**Pattern:** `src/`'
  passes_root || return 1
  new_repo
  add_start_line "$PACK" '- Run: `src/nope.txt`'
  add_start_line "$PACK" '* Run: `src/nope2.txt`'
  add_start_line "$PACK" '**Run:** `src/nope3.txt`'
  add_start_line "$PACK" '- **Run:** `src/nope4.txt`'
  passes_root
}

# C4: a marker skips a cell only as a whole token, and also after a changed: prefix.
test_marker_skip_matches_whole_tokens() {
  new_repo
  set_f2c "$PACK" 'changed: inferred: `src/nope.txt`' 'none. `src/nope2.txt`' \
    '| order value | changed: inferred: `no_such_term` | unknown: ask `no_such_term2` |'
  passes_root || return 1
  set_f2c "$PACK" 'inferred: note `src/nope.txt`' 'unknown: ask `src/nope2.txt`' \
    '| order value | none | inferred: note `no_such_term` |'
  passes_root || return 1
  set_f2c "$PACK" 'nonetheless `src/nope.txt`' none
  root_fails_only R9 || return 1
  set_f2c "$PACK" none none '| order value | nonetheless `no_such_term` | none |'
  root_fails_only R10 || return 1
  set_f2c "$PACK" 'changed: `src/nope.txt`' none
  root_fails_only R9
}

# C5: a path that leaves the root fails R9 with a clear message.
test_path_that_leaves_the_root_fails_r9() {
  local v
  for v in '../x' 'src/../../x' './../x' 'src/..' '../x:3'; do
    new_repo
    set_f2c "$PACK" "\`$v\`" none
    root_fails_only R9 || return 1
    printf '%s\n' "$OUT" | grep -q "^FAIL R9: feature-to-code.md: '$v' leaves the repository root" || return 1
  done
  new_repo
  add_start_line "$PACK" 'Open: `../x`'
  root_fails_only R9 || return 1
  printf '%s\n' "$OUT" | grep -q "^FAIL R9: README.md: '../x' leaves the repository root" || return 1
  new_repo
  printf 'x\n' >"$REPO/src/..hidden"
  printf 'x\n' >"$REPO/src/a..b"
  set_f2c "$PACK" '`src/..hidden` and `src/a..b`' none
  passes_root
}

# C6: the pack-folder pathspec is literal, so glob characters in the folder name do not change the match.
test_pack_folder_with_glob_characters_is_excluded() {
  new_repo
  PACK="$REPO/docs/[x]"
  mkdir -p "$PACK"
  write_brief "$PACK"
  set_f2c "$PACK" none none '| order value | `only_in_pack_term` | none |'
  root_fails_only R10 || return 1
  printf '%s\n' "$OUT" | grep -q "^FAIL R10: 'only_in_pack_term' not found outside docs/\[x\]" || return 1
  # A sibling folder that the pattern [x] would match is searched, not excluded.
  mkdir -p "$REPO/docs/x"
  printf 'only_in_pack_term\n' >"$REPO/docs/x/notes.txt"
  passes_root || return 1
  # A star in the folder name must not widen the exclusion to a sibling folder.
  new_repo
  PACK="$REPO/docs/a*"
  mkdir -p "$PACK" "$REPO/docs/abc"
  write_brief "$PACK"
  set_f2c "$PACK" none none '| order value | `only_in_pack_term` | none |'
  root_fails_only R10 || return 1
  printf 'only_in_pack_term\n' >"$REPO/docs/abc/notes.txt"
  passes_root
}

# C7: looks_secret and R6 share one set of patterns.
test_secret_patterns_live_in_one_place() {
  [ "$(grep -c 'AKIA\[0-9A-Z\]{16}' "$CHECKER")" -eq 1 ] &&
    [ "$(grep -c 'sk_(live|test)' "$CHECKER")" -eq 1 ] &&
    [ "$(grep -c 'sharedaccesskey' "$CHECKER")" -eq 1 ] &&
    [ "$(grep -c '{32,}' "$CHECKER")" -eq 1 ]
}

test_looks_secret_follows_r6_case_rules() {
  # R6 matches provider shapes case-sensitively. A lowercase look-alike is not flagged by R6, so it may be shown.
  new_repo
  set_f2c "$PACK" '`src/akiafakefakefakefake`' none
  run_checker_root "$PACK" "$REPO"
  printf '%s\n' "$OUT" | grep -q "^FAIL R9: feature-to-code.md: 'src/akiafakefakefakefake' " || return 1
  # The keywords stay case-insensitive: this value is hidden.
  new_repo
  set_f2c "$PACK" '`src/PASSWORD=abc`' none
  run_checker_root "$PACK" "$REPO"
  printf '%s\n' "$OUT" | grep -q '^FAIL R9:' && ! printf '%s\n' "$OUT" | grep -qi 'PASSWORD=abc'
}

# C9: CRLF line endings in Start here. One fence passes, two fences fail, no fence and no Key concept fails.
crlf_start_here() {
  awk '/^## / { on = ($0 == "## Start here") } on { printf "%s\r\n", $0; next } { print }' \
    "$1/README.md" >"$1/README.md.new" && mv "$1/README.md.new" "$1/README.md"
}

test_crlf_start_here_one_mermaid_fence() {
  local cr
  cr=$(printf '\r')
  new_dir
  write_brief "$D"
  crlf_start_here "$D"
  # Meaningful: the fence line really ends in CR, and the next section does not.
  grep -q "^\`\`\`mermaid$cr\$" "$D/README.md" || return 1
  ! grep -q "^## Architecture and patterns$cr\$" "$D/README.md" || return 1
  passes_clean "$D" || return 1
  new_dir
  write_brief "$D"
  awk '{ print } /^## Start here$/ { print ""; print "```mermaid"; print "flowchart LR"; print "```" }' \
    "$D/README.md" >"$D/README.md.new" && mv "$D/README.md.new" "$D/README.md"
  crlf_start_here "$D"
  fails_only "$D" R11 || return 1
  new_dir
  write_brief "$D"
  edit_readme "$D" '/^```mermaid$/,/^```$/d'
  crlf_start_here "$D"
  fails_only "$D" R11
}

# I1: a pack folder that is the repository root excludes feature-to-code.md only, so a term found only there fails R10.
test_pack_folder_equal_to_the_root_still_checks_r10() {
  new_repo
  write_brief "$REPO"
  set_f2c "$REPO" none none '| order value | `only_in_pack_term` | none |'
  run_checker_root "$REPO" "$REPO"
  [ "$RC" -eq 1 ] && printf '%s\n' "$OUT" | grep -q "^FAIL R10: 'only_in_pack_term' " &&
    ! printf '%s\n' "$OUT" | grep -q '^NOTE R10: onboarding folder is outside' || return 1
  # The same term in code passes, so the failure came from the exclusion and not from a broken run.
  printf 'only_in_pack_term\n' >"$REPO/src/new.txt"
  run_checker_root "$REPO" "$REPO"
  [ "$RC" -eq 0 ] && ! printf '%s\n' "$OUT" | grep -q '^FAIL \|^NOTE R10:'
}

# warn_only <rule> <text>: exit 0 (a WARN never changes the exit status), a WARN line for the rule that holds the text,
# and no FAIL.
warn_only() {
  [ "$RC" -eq 0 ] && printf '%s\n' "$OUT" | grep -q "^WARN $1: .*$2" && ! printf '%s\n' "$OUT" | grep -q '^FAIL '
}

# I2a: a table without leading pipes is not read, so R9 and R10 warn instead of passing silently.
test_f2c_table_without_leading_pipes_warns() {
  new_repo
  {
    printf '# Feature to code\n\n## Submit order\n\nLayer | Data loads in | Calculations and rules in\n---|---|---\n'
    printf 'api | `src/nope.txt` | none\n\n### Search terms\n\nBusiness term | api | db\n---|---|---\n'
    printf 'order value | `no_such_term` | none\n'
  } >"$PACK/feature-to-code.md"
  run_checker_root "$PACK" "$REPO"
  warn_only R9 "feature-to-code.md: .*Submit order" || return 1
  # A block with a pipe table raises no such warning.
  set_f2c "$PACK" '`src/app.txt:1`' none
  passes_root
}

# I2b: an Open: line with the list on the following lines has no value on the line itself, so it warns.
test_empty_open_line_warns() {
  new_repo
  add_start_line "$PACK" 'Open:'
  run_checker_root "$PACK" "$REPO"
  warn_only R9 "README.md: .*Open:" || return 1
  # A value on the line, or a marker such as none, does not warn.
  new_repo
  add_start_line "$PACK" 'Open: `src/app.txt`'
  add_start_line "$PACK" 'Pattern: none'
  passes_root
}

# I2c: an Open: value without backticks is not read, so it warns.
test_open_value_without_backticks_warns() {
  new_repo
  add_start_line "$PACK" 'Open: src/nope.txt'
  run_checker_root "$PACK" "$REPO"
  warn_only R9 "README.md: .*Open:" || return 1
  new_repo
  add_start_line "$PACK" '- **Pattern:** src/nope.txt'
  run_checker_root "$PACK" "$REPO"
  warn_only R9 "README.md: .*Pattern:"
}

# M1: an escaped pipe inside a cell does not split the cell. The term is the rendered text, with a plain pipe.
test_escaped_pipe_in_a_term_is_read() {
  new_repo
  set_f2c "$PACK" none none '| order value | `al\|pha` | none |'
  root_fails_only R10 || return 1
  printf 'x al|pha y\n' >"$REPO/src/new.txt"
  passes_root
}

# M2: R11 tracks code fences in Start here. A "## " line in a fence does not end the section, and ~~~mermaid counts.
test_r11_tracks_fences_in_start_here() {
  new_dir
  write_brief "$D"
  awk '{ print } /^## Start here$/ { print ""; print "```bash"; print "## comment"; print "```" }' \
    "$D/README.md" >"$D/README.md.new" && mv "$D/README.md.new" "$D/README.md"
  passes_clean "$D" || return 1
  new_dir
  write_brief "$D"
  edit_readme "$D" '/^```mermaid$/,/^```$/ { s/^```mermaid$/~~~mermaid/; s/^```$/~~~/; }'
  grep -q '^~~~mermaid$' "$D/README.md" || return 1
  passes_clean "$D" || return 1
  # Two tilde diagrams still fail.
  awk '{ print } /^## Start here$/ { print ""; print "~~~mermaid"; print "flowchart LR"; print "~~~" }' \
    "$D/README.md" >"$D/README.md.new" && mv "$D/README.md.new" "$D/README.md"
  fails_only "$D" R11
}

# M3: an exported CDPATH does not change how the root is read.
test_exported_cdpath_does_not_break_the_root() {
  local parent base
  new_repo
  set_f2c "$PACK" '`src/app.txt:20`' none
  parent=$(dirname "$REPO")
  base=$(basename "$REPO")
  OUT=$(cd "$parent" && CDPATH="$parent" "$CHECKER" "$base/docs/onboarding" "$base" 2>&1)
  RC=$?
  [ "$RC" -eq 0 ] && ! printf '%s\n' "$OUT" | grep -q '^FAIL \|^NOTE R9:\|^NOTE R10:'
}

# M4: an empty root argument is bad usage, not "the current folder".
test_empty_root_argument_exits_2() {
  new_repo
  OUT=$(cd "$REPO" && "$CHECKER" "$PACK" "" 2>&1)
  RC=$?
  [ "$RC" -eq 2 ] && printf '%s\n' "$OUT" | grep -q '^usage:'
}

# M5: the root is the git toplevel, so a root typed in another letter case works where the folder is
# case-insensitive (the macOS default). The case test is skipped on a case-sensitive filesystem.
test_root_in_another_letter_case_works() {
  local upper
  new_repo
  set_f2c "$PACK" '`src/app.txt:20`' none
  upper=$(printf '%s' "$REPO" | tr 'a-z' 'A-Z')
  if [ "$upper" != "$REPO" ] && [ -d "$upper" ]; then
    OUT=$("$CHECKER" "$upper/docs/onboarding" "$upper" 2>&1)
    RC=$?
    [ "$RC" -eq 0 ] && ! printf '%s\n' "$OUT" | grep -q '^FAIL \|^NOTE R9:\|^NOTE R10:' || return 1
  else
    echo "  (skipped: case-sensitive filesystem)" >&2
  fi
  # The reason a root is refused is printed before the usage line.
  run_checker_root "$PACK" "$REPO/src"
  printf '%s\n' "$OUT" | grep -qi 'subfolder' || return 1
  new_dir
  run_checker_root "$PACK" "$D"
  printf '%s\n' "$OUT" | grep -qi 'not a git repository'
}

# M6: a line number with more than 9 digits is a FAIL with a message, and nothing reaches stderr.
test_huge_line_number_fails_without_a_shell_error() {
  new_repo
  set_f2c "$PACK" '`src/app.txt:99999999999999999999`' '`src/app.txt:1-99999999999999999999`'
  run_checker_root "$PACK" "$REPO"
  [ "$RC" -eq 1 ] && printf '%s\n' "$OUT" | grep -q "^FAIL R9: .*more than 9 digits" &&
    ! printf '%s\n' "$OUT" | grep -q 'integer expression' &&
    ! printf '%s\n' "$OUT" | grep '^FAIL ' | grep -qv '^FAIL R9:'
}

echo "check-brief.sh"
check "missing README fails R1" test_missing_readme_fails
check "no argument prints usage and exits 2" test_no_argument_prints_usage_and_exits_2
check "good brief passes with no FAIL or WARN" test_good_brief_passes
check "each missing header field fails R2" test_missing_header_field_fails
check "bad header values fail R2" test_bad_header_value_fails
check "commit hash length 7 and 40 pass, 6 and 41 fail" test_commit_length_bounds
check "missing checklist item fails R3" test_missing_checklist_item_fails
check "checklist item with no link or unknown: fails R3" test_checklist_item_without_link_or_unknown_fails
check "checklist item outside the checklist section does not count" test_item_outside_checklist_does_not_count
check "missing checklist item 9 fails R3" test_missing_checklist_item_9_fails
check "two mermaid blocks in Start here fail R11" test_start_here_with_two_mermaid_blocks_fails
check "no mermaid block in Start here fails R11" test_start_here_with_no_mermaid_block_fails
check "Key concept: unknown: in place of the diagram passes" test_key_concept_unknown_passes
check "missing feature-to-code.md fails R12" test_missing_feature_to_code_fails_r12
check "missing link to feature-to-code.md fails only R12" test_missing_feature_to_code_link_fails_only_r12
check "missing Start here section fails only R4" test_missing_start_here_fails_only_r4
check "missing section fails R4" test_missing_section_fails
check "wrong section order fails R4" test_section_order_fails
check "missing Sources line fails R5" test_missing_sources_line_fails
check "secret-like text fails R6" test_secret_value_fails
check "secret in a side file fails R6" test_secret_in_side_file_fails
check "long word without a digit is not a secret" test_long_word_without_digit_is_not_a_secret
check "long identifier with trailing digits is not a secret" test_long_identifier_with_trailing_digits_is_not_a_secret
check "long hex token still fails R6" test_long_hex_token_still_fails
check "long token with digits in the middle still fails R6" test_long_token_with_digits_in_the_middle_still_fails
check "long letters then five digits still fails R6" test_long_letters_then_five_digits_still_fails
check "looks_secret shows a plain identifier" test_looks_secret_shows_a_plain_identifier
check "broken side link fails R7" test_broken_side_link_fails
check "long brief warns R8 but passes" test_long_brief_warns_but_passes
check "provider token formats fail R6" test_provider_secret_formats_fail
check "the Scanned commit exemption covers only a valid hash line" test_scanned_commit_exemption_covers_only_a_valid_hash_line
check "a ## line inside a code fence is not a heading" test_heading_marks_inside_a_code_fence_are_not_headings
check "links with a title or angle brackets are checked by R7" test_link_forms_with_a_title_or_angle_brackets_are_checked
check "a CRLF brief is checked like an LF brief" test_crlf_brief_is_checked_like_an_lf_brief
check "an empty Sources line warns R5 but passes" test_empty_sources_line_warns_but_passes
check "a stray byte does not hide a secret or print it" test_a_stray_byte_does_not_hide_a_secret
check "three arguments print usage and exit 2" test_three_arguments_print_usage_and_exit_2
check "a root that is not a repository exits 2" test_root_that_is_not_a_repository_exits_2
check "a subfolder root exits 2" test_subfolder_root_exits_2
check "one argument skips R9 and R10 with a NOTE" test_one_argument_skips_repo_checks_with_a_note
check "good paths and terms pass with a root" test_good_paths_and_terms_pass_with_a_root
check "a missing feature-to-code.md path fails R9" test_missing_path_fails_r9
check "a missing Start here path fails R9" test_missing_start_here_path_fails_r9
check "one path column with any title passes R9" test_one_path_column_with_any_title_passes_r9
check "a path in a fourth column is checked by R9" test_path_in_a_fourth_column_is_checked_by_r9
check "a line past the end of the file fails R9" test_line_past_end_of_file_fails_r9
check "a line range is checked by its end" test_line_range_is_checked_by_its_end
check "a folder passes without a line number" test_folder_path_passes_without_a_line_number
check "an untracked file passes R9" test_untracked_file_passes_r9
check "an untracked term passes R10" test_untracked_term_passes_r10
check "header, separator and marker cells are skipped" test_header_separator_and_marker_cells_are_skipped
check "a changed: marker cell is read" test_changed_marker_cell_is_read
check "Run lines and search terms are not paths" test_run_line_and_search_terms_are_not_paths
check "a missing search term fails R10" test_missing_search_term_fails_r10
check "the term search is case-sensitive" test_term_search_is_case_sensitive
check "a term found only in the pack fails R10" test_term_found_only_in_the_pack_fails_r10
check "a pack under a symlinked temp path is excluded" test_pack_under_a_symlinked_temp_path_is_excluded
check "a pack outside the root prints a NOTE" test_pack_outside_the_root_prints_a_note
check "the Business term column is not searched" test_business_term_column_is_not_searched
check "a CRLF feature-to-code.md is checked like LF" test_crlf_feature_to_code_is_checked_like_lf
check "a relative or trailing-slash root works" test_relative_and_trailing_slash_root_work
check "a secret-like path value is not printed" test_secret_like_path_value_is_not_printed
check "R12 accepts a ./ link to feature-to-code.md" test_r12_accepts_a_dot_slash_link
check "a reversed line range fails R9" test_reversed_line_range_fails_r9
check "bullet and bold Open: and Pattern: lines are read, Run: never" test_bullet_and_bold_start_lines_are_read
check "a marker skips a cell only as a whole token" test_marker_skip_matches_whole_tokens
check "a path that leaves the root fails R9" test_path_that_leaves_the_root_fails_r9
check "a pack folder with glob characters is excluded literally" test_pack_folder_with_glob_characters_is_excluded
check "the secret patterns live in one place" test_secret_patterns_live_in_one_place
check "looks_secret follows the R6 case rules" test_looks_secret_follows_r6_case_rules
check "CRLF line endings in Start here: one fence passes, two or none fail R11" test_crlf_start_here_one_mermaid_fence
check "a pack folder equal to the root still checks R10" test_pack_folder_equal_to_the_root_still_checks_r10
check "a feature-to-code.md table without leading pipes warns R9" test_f2c_table_without_leading_pipes_warns
check "an empty Open: line warns R9" test_empty_open_line_warns
check "an Open: value without backticks warns R9" test_open_value_without_backticks_warns
check "an escaped pipe in a cell does not split it" test_escaped_pipe_in_a_term_is_read
check "R11 tracks fences in Start here and counts ~~~mermaid" test_r11_tracks_fences_in_start_here
check "an exported CDPATH does not break the root" test_exported_cdpath_does_not_break_the_root
check "an empty root argument exits 2" test_empty_root_argument_exits_2
check "a root in another letter case works, and a refused root says why" test_root_in_another_letter_case_works
check "a line number over 9 digits fails R9 with no shell error" test_huge_line_number_fails_without_a_shell_error
check "a missing Repo policy line warns R13" test_missing_repo_policy_warns
check "a malformed Repo policy line warns R13" test_bad_repo_policy_warns
check "a missing contract.md warns R14" test_missing_contract_warns
check "contract.md headings out of order warn R14" test_contract_headings_out_of_order_warn
check "an access rule marked inferred: fails R15" test_inferred_access_rule_fails
check "an access rule with no source warns R15" test_access_rule_without_source_warns
check "a backticked rule word alone warns R15" test_backticked_rule_word_warns
check "an access rule that cites a document passes" test_access_rule_with_a_document_passes
check "a capitalised rule word with no source warns R15" test_capitalised_rule_without_source_warns
check "an inferred: rule in another column order fails R15" test_inferred_rule_in_another_column_order_fails
check "an H4 sub-heading in contract.md does not warn" test_contract_sub_heading_passes

echo
echo "passed=$PASS failed=$FAIL"
echo "temp folders left in place:$TMPS"
[ "$FAIL" -eq 0 ]
