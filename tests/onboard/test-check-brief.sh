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

# write_brief <dir> [section...]: a good brief. Sections default to the nine in order.
# NO_SOURCES_FOR=<section> leaves that section's Sources line out.
write_brief() {
  local dir=$1 s
  shift
  [ $# -gt 0 ] || set -- "First-ticket checklist" "Purpose and users" "Use cases" "Architecture and patterns" \
    "Data model" "External systems" "Run and verify" "Risks and delivery" "Unknowns"
  {
    printf '# Shop onboarding brief\n\n'
    printf 'Scanned commit: 0123456789abcdef0123456789abcdef01234567\n'
    printf 'Scanned on: 2026-10-21\n'
    printf 'Working tree: clean\n\n'
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
          printf '8. unknown: ask the delivery owner how a ticket ships\n\n'
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
    '-----BEGIN FAKE KEY-----' 'FIXTURENOTASECRETFIXTURENOTASECRET12'; do
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
check "missing section fails R4" test_missing_section_fails
check "wrong section order fails R4" test_section_order_fails
check "missing Sources line fails R5" test_missing_sources_line_fails
check "secret-like text fails R6" test_secret_value_fails
check "secret in a side file fails R6" test_secret_in_side_file_fails
check "long word without a digit is not a secret" test_long_word_without_digit_is_not_a_secret
check "broken side link fails R7" test_broken_side_link_fails
check "long brief warns R8 but passes" test_long_brief_warns_but_passes
check "provider token formats fail R6" test_provider_secret_formats_fail
check "the Scanned commit exemption covers only a valid hash line" test_scanned_commit_exemption_covers_only_a_valid_hash_line
check "a ## line inside a code fence is not a heading" test_heading_marks_inside_a_code_fence_are_not_headings
check "links with a title or angle brackets are checked by R7" test_link_forms_with_a_title_or_angle_brackets_are_checked
check "a CRLF brief is checked like an LF brief" test_crlf_brief_is_checked_like_an_lf_brief
check "an empty Sources line warns R5 but passes" test_empty_sources_line_warns_but_passes
check "a stray byte does not hide a secret or print it" test_a_stray_byte_does_not_hide_a_secret

echo
echo "passed=$PASS failed=$FAIL"
echo "temp folders left in place:$TMPS"
[ "$FAIL" -eq 0 ]
