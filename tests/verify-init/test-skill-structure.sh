#!/usr/bin/env bash
# Structure and wording tests for the agentd-verify-init skill files. Reads the skill files and writes nothing.
# The check that every skill sets disable-model-invocation lives in tests/onboard/test-skill-structure.sh.
# Customer and project names are read from the git-ignored list .git/info/customer-names, never spelt out here.
# Usage: tests/verify-init/test-skill-structure.sh
set -u

HERE=$(cd "$(dirname "$0")" && pwd -P)
REPO=$(cd "$HERE/../.." && pwd -P)
SKILL_DIR=${SKILL_DIR:-$REPO/skills/agentd-verify-init}
SKILL="$SKILL_DIR/SKILL.md"
REFS="$SKILL_DIR/references"
TPLS="$SKILL_DIR/templates"
EVAL="$REPO/tests/verify-init/EVAL.md"
NAMES=$(git -C "$REPO" rev-parse --git-path info/customer-names 2>/dev/null)
case "$NAMES" in /*) ;; ?*) NAMES="$REPO/$NAMES" ;; esac
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

# frontmatter_value <key>: the value of a key in the first frontmatter block of SKILL.md.
frontmatter_value() {
  awk -v k="$1" '
    NR == 1 && $0 != "---" { exit 1 }
    /^---[ \t]*$/ { c++; if (c == 2) exit; next }
    c == 1 && index($0, k ": ") == 1 { print substr($0, length(k) + 3); exit }
  ' "$SKILL"
}

# joined: stdin as one line, runs of spaces squeezed, so a phrase that wraps across lines still matches.
joined() { tr '\n' ' ' | tr -s ' '; }

# has_all <file> <text>...: the file contains every text, ignoring case.
has_all() {
  local f=$1 t body
  shift
  [ -s "$f" ] || return 1
  body=$(joined <"$f")
  for t in "$@"; do printf '%s\n' "$body" | grep -qiF -- "$t" || return 1; done
}

# strip_fences <file>: the file without fenced code blocks, so a "## " line inside one is not read as a heading.
strip_fences() { awk '/^[ ]*(```|~~~)/ { f = !f; next } !f' "$1"; }

# strip_fences_off <file>: only the lines inside fenced blocks.
strip_fences_off() { awk '/^[ ]*(```|~~~)/ { f = !f; next } f' "$1"; }

# h2_list <file>: the H2 headings of a markdown file, in order, one per line. Fenced blocks are skipped.
h2_list() { strip_fences "$1" | grep -E '^## ' | sed 's/^## //; s/[[:space:]]*$//'; }

# section_of <file> <heading>: the lines under one H2 heading. Fenced blocks are skipped when finding headings.
section_of() {
  awk -v h="## $2" '
    /^[ ]*(```|~~~)/ { f = !f }
    !f && $0 == h { on = 1; next }
    !f && /^## / { on = 0 }
    on
  ' "$1"
}

# section_has <file> <heading> <text>...: the section contains every text, ignoring case.
section_has() {
  local f=$1 h=$2 body t
  shift 2
  body=$(section_of "$f" "$h" 2>/dev/null | joined)
  [ -n "$body" ] || return 1
  for t in "$@"; do printf '%s\n' "$body" | grep -qiF -- "$t" || return 1; done
}

# step_has <step name> <text>...: the Flow step with this name contains every text, ignoring case.
step_has() {
  local name=$1 body t
  shift
  body=$(section_of "$SKILL" Flow 2>/dev/null | awk -v n="**$name" '
    /^[0-9]+\. / { on = (index($0, n) > 0 && index($0, ". " n) > 0) }
    on' | joined)
  [ -n "$body" ] || return 1
  for t in "$@"; do printf '%s\n' "$body" | grep -qiF -- "$t" || return 1; done
}

# skill_files: every file the privacy and wording checks cover, one path per line. Missing files are left out.
skill_files() {
  local f
  for f in "$SKILL" "$REFS"/*.md "$TPLS"/*.md "$EVAL" "$REPO/skills/agentd-dev-rev/SKILL.md" \
    "$REPO/skills/agentd-pr-prep/SKILL.md"; do
    [ -f "$f" ] && printf '%s\n' "$f"
  done
  return 0
}

# none_contains <grep option> <text>: no covered file matches. Fails when SKILL.md is missing.
none_contains() {
  local opt=$1 text=$2 f
  [ -s "$SKILL" ] || return 1
  while IFS= read -r f; do
    joined <"$f" | grep -q "$opt" -- "$text" && return 1
  done < <(skill_files)
  return 0
}

# ---------------------------------------------------------------- SKILL.md

test_frontmatter_name_matches_folder() {
  [ "$(frontmatter_value name)" = "agentd-verify-init" ] && [ "$(basename "$SKILL_DIR")" = "agentd-verify-init" ]
}

test_description_starts_with_use_when_and_covers_the_job() {
  local d t
  d=$(frontmatter_value description)
  case "$d" in "Use when"*) ;; *) return 1 ;; esac
  for t in "project skill" "evidence report" "once per project" "update"; do
    printf '%s\n' "$d" | grep -qiF -- "$t" || return 1
  done
}

test_skill_is_manual_only() {
  [ -s "$SKILL" ] || return 1
  awk 'NR == 1 && $0 != "---" { exit } /^---[ \t]*$/ { c++; if (c == 2) exit; next } c == 1' "$SKILL" |
    grep -qx 'disable-model-invocation: true'
}

test_skill_is_at_most_120_lines() {
  [ -s "$SKILL" ] && [ "$(wc -l <"$SKILL")" -le 120 ]
}

test_required_h2_sections_in_order() {
  [ -s "$SKILL" ] || return 1
  [ "$(h2_list "$SKILL" | tr '\n' '|')" = "Prerequisite|Modes|Flow|Rules|" ]
}

test_modes_are_create_and_update() {
  section_has "$SKILL" Modes "Create" "Update" "references/update-mode.md" "this skill wrote"
}

test_flow_has_eight_numbered_steps_in_order() {
  local body
  body=$(section_of "$SKILL" Flow 2>/dev/null)
  [ -n "$body" ] || return 1
  [ "$(printf '%s\n' "$body" | grep -E '^[0-9]+\. \*\*' | sed -E 's/^([0-9]+)\. \*\*([^*]*)\*\*.*/\1 \2/; s/\.$//' |
    tr '\n' '|')" = '1 Read the project|2 Ask where the skill lives|3 Pick the features|4 Write the feature map and data setup|5 Write the helpers|6 Write the verify skill|7 Run the proof run|8 Report|' ]
}

test_asks_tool_and_commit() {
  section_has "$SKILL" Flow "allowed tool" "committed" ".github/skills/" ".claude/skills/" ".git/info/exclude"
}

test_committed_file_rules() {
  section_has "$SKILL" Rules "no personal paths" "no secrets" "no customer values" "environment variable" \
    "no password is written to a file" "the database reference says how" "one container per ticket" \
    "its own host port"
}

test_never_types_credentials() {
  section_has "$SKILL" Rules "never types credentials" "the engineer signs in"
}

test_never_reads_secrets() {
  section_has "$SKILL" Rules "user secrets" "connection string" "never read"
}

test_proof_run_is_required() {
  step_has "Run the proof run" "engineer present" "sign-in" "Doctor" "evidence" "cleanup"
}

test_no_sign_in_marks_draft_not_proven() {
  has_all "$SKILL" "draft: not proven" "Not proven:" "stop at sign-in" "first line of the body"
}

test_marker_is_written_nested() {
  [ -s "$SKILL" ] || return 1
  awk '
    /^[ ]*(```|~~~)/ { f = !f; prev = ""; if (f) { match($0, /^ */); ind = RLENGTH }; next }
    f { line = substr($0, ind + 1) }
    f && prev == "metadata:" && line == "  generated-by: agentd-verify-init" { ok = 1 }
    f { prev = line }
    END { exit !ok }
  ' "$SKILL"
}

test_six_independence_mechanisms_are_named() {
  has_all "$SKILL" "expectations before evidence" "a separate verifier in a fresh session" \
    "three-way match of screen, API and database" "recompute the figures on calculation tickets" \
    "check the neighbours" "try the edges"
}

test_no_reference_marks_inferred() {
  has_all "$SKILL" "no reference" "inferred:" "ask the engineer"
}

test_does_not_start_another_skill() {
  section_has "$SKILL" Rules "do not start another skill"
}

test_no_customer_names() {
  local f
  [ -s "$SKILL" ] && [ -s "$NAMES" ] || return 1
  while IFS= read -r f; do
    # Entries of 3 letters or fewer match whole words only, so a short name inside a longer word is fine.
    # Longer entries match anywhere, so a name inside a CamelCase type name is caught.
    grep -qiwF -f <(awk 'length($0) <= 3' "$NAMES") "$f" && return 1
    grep -qiF -f <(awk 'length($0) > 3' "$NAMES") "$f" && return 1
  done < <(skill_files; printf '%s\n' "$REPO/README.md" "$HERE/test-skill-structure.sh")
  return 0
}

test_no_absolute_home_paths() {
  local tmp="/var/""folders" f tok
  [ -s "$SKILL" ] || return 1
  while IFS= read -r f; do
    grep -qF -e "/Users/" -e "$tmp" "$f" && return 1
    # ~/ may appear only as ~/.<app>-verify (the evidence and state folder), or as the rm-scratch helper that
    # agentd-dev-rev already names.
    for tok in $(grep -oh '~/[^[:space:]`)]*' "$f"); do
      printf '%s\n' "$tok" | grep -qE '^~/\.[A-Za-z0-9<>_]+-verify(/|$)|^~/\.agents/bin/rm-scratch$' || return 1
    done
  done < <(skill_files)
  return 0
}

test_no_phrase_is_copied_from_pstack() {
  local p
  [ -s "$SKILL" ] || return 1
  for p in "refusing to double-drive a shared instance" "a draft, not a deliverable" \
    "A helper the reader has to reverse-engineer" "Interview the repo, not the user" \
    "Never weaken the journey to make it pass" "Ready means usable, not just that a process answers" \
    "Never kill by process name" "a cleanup that eats the proof"; do
    none_contains -iF "$p" || return 1
  done
}

# ---------------------------------------------------------------- references

# h2_exact <file> <h2 names joined with |>: the H2 headings equal this list, in order.
h2_exact() {
  [ -s "$1" ] || return 1
  [ "$(h2_list "$1" | tr '\n' '|')" = "$2|" ]
}

test_dotnet_reference_h2s_exact() {
  h2_exact "$REFS/dotnet.md" "Environment variables|Migrations|Doctor|dbup-run.ps1|api-start.ps1"
}

test_dotnet_reference_names_where_to_look() {
  local f="$REFS/dotnet.md"
  has_all "$f" "general knowledge" "not yet checked on a project" &&
    section_has "$f" "Environment variables" "__" "role override" "array index" "max(N,k)" "user secrets" &&
    section_has "$f" Migrations "DbUp" "EF Core" "journal" "SchemaVersions" &&
    section_has "$f" Doctor "DB_NAME()" "no health endpoint"
}

test_helpers_template_covers_a_stack_without_a_reference() {
  section_has "$HP" "When no reference matches" "mark the helper" "inferred:" \
    "refuses to start when a process this run did not start already holds the port" \
    "stops with \`blocked: <reason>\` and prints the fix command" "never falls back to a settings file" \
    "refuses to run unless the connection source names the per-ticket database" \
    "connectionConfirmedFor"
}

test_database_reference_states_its_dependency_on_the_migration_runner() {
  has_all "$DBA" "references/dotnet.md" "dbup-run.ps1" "another runner" "inferred:"
}

test_dotnet_reference_says_the_helper_contracts_follow_the_database_reference() {
  has_all "$DN" "assume the database from the database reference" "for another database" "inferred:" &&
    ! grep -qx '# .NET backends with SQL Server' "$DN"
}

# finding 8: every helper has exactly one contract, in the file that the index names
test_every_helper_has_one_contract_in_the_indexed_file() {
  local spec h want f n
  # <helper>:<the files that hold a contract for it; each holds exactly one, and no other file holds one>
  for spec in "common:$HP" "doctor:$HP" "cleanup:$HP" "db-start:$DBA $LDB" "db-restore:$DBA" \
    "dbup-run:$DN" "api-start:$DN $DNF" "ui-start:$RX $IOS"; do
    h=${spec%%:*}
    want=${spec#*:}
    for f in "$HP" "$DN" "$DNF" "$DBA" "$LDB" "$RX" "$IOS"; do
      n=$(grep -c -F -x "## $h.ps1" "$f")
      case " $want " in *" $f "*) [ "$n" -eq 1 ] || return 1 ;; *) [ "$n" -eq 0 ] || return 1 ;; esac
    done
  done
  section_has "$HP" "When no reference matches" "all the helpers" || return 1
  section_has "$HP" "Where the other contracts live" '`db-start.ps1` and `db-restore.ps1`: `references/sqlserver-docker.md`' \
    '`dbup-run.ps1` and `api-start.ps1`: `references/dotnet.md`' '`ui-start.ps1`: `references/react.md`' \
    "applies only when its reference was loaded" '`references/sqlserver-localdb.md`' '`references/dotnet-framework.md`' \
    '`references/ios.md`' \
    "the Doctor section of \`references/ios.md\` replaces it"
}

test_dotnet_framework_reference_h2s_exact() {
  h2_exact "$DNF" "Build and tools|Configuration|Start with IIS Express|One-time administrator steps|Sign-in|Doctor|api-start.ps1"
}

test_dotnet_framework_reference_names_where_to_look() {
  has_all "$DNF" "general knowledge" "not yet checked on a customer project" "inferred:" &&
    section_has "$DNF" "Build and tools" "vswhere" "vstest.console.exe" "MSBuild" "not on PATH" "git status --porcelain" &&
    section_has "$DNF" Configuration "web.config" "never edit" "LocalOnlyFiles" \
      "blocked: connection string not set for this ticket" "never falls back" &&
    section_has "$DNF" "Start with IIS Express" "/config:" "/site:" "applicationhost.config" "scratch copy" "never edit" &&
    section_has "$DNF" "One-time administrator steps" "netsh http add urlacl" "firewall" "never runs them" &&
    section_has "$DNF" Sign-in "debug token" "never type credentials" "never save or print" &&
    section_has "$DNF" Doctor "sys.dm_exec_sessions" "inferred:" &&
    section_has "$DNF" "api-start.ps1" "refuses to start when a process this run did not start holds the port" \
      "saves the process ID in \`state.json\`" "confirm"
}

test_localdb_reference_h2s_exact() {
  h2_exact "$LDB" "Instance and database|Bacpac|db-start.ps1"
}

test_localdb_reference_names_where_to_look() {
  has_all "$LDB" "general knowledge" "not yet checked on a customer project" "inferred:" &&
    section_has "$LDB" "Instance and database" "sqllocaldb" "(localdb)" \
      "never create, stop, delete or change an instance the engineer made" "one new database per ticket" &&
    section_has "$LDB" Bacpac "references/sqlserver-docker.md" "TargetServerName" "never reset" &&
    section_has "$LDB" db-start.ps1 "containerId" "<instance>\\<database>" "never drops any other database" \
      "database: new" "the instance and the per-ticket database"
}

test_ios_reference_h2s_exact() {
  h2_exact "$IOS" "Build and install|Driver|Sign-in|Doctor|Three-way match on iOS|Evidence and privacy|ui-start.ps1"
}

test_ios_reference_names_where_to_look() {
  has_all "$IOS" "general knowledge" "not yet checked on a customer project" "inferred:" &&
    section_has "$IOS" "Build and install" "-project" "contents.xcworkspacedata" "no schemes" "build-for-testing" \
      "-derivedDataPath" "git status --porcelain" "never restores" "DeviceHub" "bootstatus" "simctl install" &&
    section_has "$IOS" Driver "XCUIApplication(bundleIdentifier:)" "project.pbxproj" "continueAfterFailure = false" \
      "TEST_RUNNER_VERIFY_EVIDENCE_DIR" "child" &&
    section_has "$IOS" Sign-in "never type credentials" "30 seconds" "600 seconds" "already signed in" \
      "blocked: sign-in did not complete" "bearer" "NSURLErrorDomain" "spinner" &&
    section_has "$IOS" Doctor "simulator is booted" "plain request" "no token" "cached" &&
    section_has "$IOS" "Three-way match on iOS" "two legs" "API leg" "unknown:" "Not verified" \
      "does not make the result \`blocked\`" &&
    section_has "$IOS" "Evidence and privacy" "customer data" "outside every repository" "counts and identifiers" &&
    section_has "$IOS" "ui-start.ps1" "no schemes" "never installs a runtime" "project file stays unchanged"
}

test_host_powershell_reference_h2s_exact() {
  h2_exact "$HPS" "Rules|Windows PowerShell 5.1"
}

test_host_powershell_reference_names_where_to_look() {
  has_all "$HPS" "general knowledge" "not yet checked on a customer project" "inferred:" "powershell.exe" &&
    section_has "$HPS" Rules '${name}?' "variable is followed by" "only fails at run time" \
      "test that the key exists first" "strict mode" 'wrap query results in `@()`' "plain string" &&
    ! section_has "$HP" "Rules for every helper" "strict mode" &&
    section_has "$HPS" "Windows PowerShell 5.1" "&&" "execution policy" \
      "blocked: execution policy" "never changes the policy" "Stop-Process -Id" "owns the LocalDB instances"
}

test_host_shell_reference_h2s_exact() {
  h2_exact "$HSH" "Rules|State and queries"
}

test_host_shell_reference_names_where_to_look() {
  has_all "$HSH" "general knowledge" "not yet checked on a customer project" "inferred:" &&
    section_has "$HSH" Rules "#!/usr/bin/env bash" "set -u" "bash 3.2" "zsh" "not split" "quote every variable" \
      "mapfile" "sed -i" "kill <pid>" &&
    section_has "$HSH" "State and queries" "jq" "// empty" "temp file" "shasum -a 256"
}

test_skill_loads_the_host_references() {
  joined <"$SKILL" | grep -qF -- 'Helpers in PowerShell also load `references/host-powershell.md`; helpers in bash or zsh also load `references/host-shell.md`.' &&
    step_has "Write the helpers" 'references/host-powershell.md' 'references/host-shell.md'
}

test_helpers_index_names_the_host_references() {
  section_has "$HP" "Where the other contracts live" 'references/host-powershell.md' 'references/host-shell.md'
}

test_generated_gotchas_name_no_single_stack() {
  section_has "$VT" Gotchas "each gotcha that a loaded reference says to put here" &&
    ! section_has "$VT" Gotchas "Rosetta" &&
    ! section_has "$VT" Gotchas "DbUp" &&
    ! section_has "$VT" Gotchas '--urls'
}

test_generator_notes_cover_an_ios_driver() {
  has_all "$VT" 'For an iOS app, replace the `Browser and session` section' "references/ios.md" \
    '`Driver`, `Sign-in` and `Evidence and privacy`' \
    "drop the steps for helpers that the app does not have" "Write every helper name with the extension"
}

test_ios_doctor_replaces_the_generic_doctor() {
  section_has "$IOS" Doctor "replaces the \`doctor.ps1\` contract" "no container"
}

test_localdb_reference_covers_doctor_and_cleanup() {
  section_has "$LDB" db-start.ps1 "doctor.ps1" "sqllocaldb info" "Running" "docker inspect" "cleanup.ps1" "DROP DATABASE" \
    "never runs it"
}

test_framework_reference_covers_a_runner_that_reads_a_settings_file() {
  has_all "$DNF" "reads a settings file instead" "asks for the same confirmation" \
    "blocked: connection string not set for this ticket"
}

test_powershell_encoding_rule_is_complete() {
  section_has "$HPS" "Windows PowerShell 5.1" "WriteAllText" 'UTF8Encoding($false)' "without a byte order mark" \
    "-Encoding UTF8" "jq"
}

test_ios_privacy_filter_and_missing_xcodegen() {
  section_has "$IOS" Sign-in "templates/helpers.md" "authorize" "client_id" "code=" "email address" &&
    section_has "$IOS" Driver "blocked: xcodegen not found" "brew install xcodegen" "never install it" "signing team"
}

test_dotnet_api_start_puts_the_port_rule_in_the_gotchas() {
  section_has "$DN" api-start.ps1 "Gotchas of the generated skill" "AirPlay Receiver"
}

test_host_shell_warns_about_the_empty_array_under_set_u() {
  section_has "$HSH" Rules "unbound variable" "empty array" '${#list[@]}'
}

test_powershell_query_rule_covers_localdb() {
  section_has "$HPS" Rules "database query" "LocalDB" 'wrap query results in `@()`'
}

test_skill_picks_the_helper_language_first() {
  step_has "Write the helpers" "First pick the language of the helpers" "else the shell of the machine that runs them" \
    "use the extension of that language"
}

test_localdb_container_id_changes_when_the_database_is_recreated() {
  section_has "$LDB" db-start.ps1 "create_date" "sys.databases" "dropped and created again" "clears the stored state"
}

test_localdb_reference_holds_the_parallels_user_fact() {
  section_has "$LDB" "Instance and database" "prlctl exec" "--current-user" "SYSTEM" &&
    ! has_all "$HPS" "prlctl"
}

test_the_settings_file_confirmation_is_recorded_per_database() {
  section_has "$DNF" "api-start.ps1" "-ConnectionConfirmed" "connectionConfirmedFor" "containerId" "lapses" &&
    section_has "$HP" "common.ps1" "connectionConfirmedFor"
}

test_framework_roles_are_the_engineers_step() {
  section_has "$DNF" Sign-in "ignores \`roles\`" "blocked: roles differ" "nothing is restarted" "engineer's step"
}

test_framework_doctor_matches_the_process_id() {
  section_has "$DNF" Doctor '`host_process_id` is the IIS Express process ID' "program_name" "generic" "blocked: database target not shown" "inferred:"
}

test_ios_doctor_checks_the_installed_build_and_uses_one_log_filter() {
  section_has "$IOS" Doctor "get_app_container" "shasum -a 256" "the one this run built" &&
    section_has "$IOS" "Evidence and privacy" "named in the Sign-in section" "client_id" "email addresses"
}

test_ios_builds_the_app_with_build_not_build_for_testing() {
  section_has "$IOS" "Build and install" 'Use `build` for the app' "build-for-testing"
}

test_skill_asks_which_ui_the_ticket_drives() {
  joined <"$SKILL" | grep -qF -- 'ask the engineer which one it drives, and load only that reference'
}

test_sqlserver_docker_reference_h2s_exact() {
  h2_exact "$DBA" "Database in Docker|Bacpac|db-start.ps1|db-restore.ps1"
}

test_sqlserver_docker_reference_names_where_to_look() {
  has_all "$DBA" "general knowledge" "not yet checked on a project" &&
    section_has "$DBA" "Database in Docker" "Rosetta" "amd64" "docker inspect" &&
    section_has "$DBA" Bacpac "SqlPackage" "bacpac" "upgrade" "never reset" "SQLPACKAGE_PATH" "not on PATH"
}

test_bacpac_journal_conflict_is_blocked() {
  section_has "$DBA" Bacpac "already lists" "branch script" "blocked" "older bacpac"
}

test_react_reference_h2s_exact() {
  h2_exact "$REFS/react.md" "Build and ports|Sign-in|Selectors|Grids|Downloads|ui-start.ps1"
}

test_react_reference_names_where_to_look() {
  local f="$REFS/react.md"
  has_all "$f" "general knowledge" "not yet checked on a project" &&
    section_has "$f" "Build and ports" "Vite" &&
    section_has "$f" Sign-in "MSAL" "loginRedirect" "localStorage" &&
    section_has "$f" Selectors "data-testid" "MUI" &&
    section_has "$f" Grids "virtualised" &&
    section_has "$f" Downloads "download"
}

test_feature_map_reference_h2s_exact() {
  h2_exact "$REFS/feature-map.md" "Find the features|Rank|Confirm"
}

test_feature_map_reference_picks_about_five() {
  local f="$REFS/feature-map.md"
  section_has "$f" "Find the features" "routes" "menus" "user documents" "entry feature" &&
    section_has "$f" Rank "six months" "churn" &&
    section_has "$f" Confirm "about five" "confirm, swap or add"
}

test_skill_loads_the_framework_and_localdb_references() {
  joined <"$SKILL" | grep -qF -- 'A .NET Framework project (a `web.config`, a `Global.asax`, or a `TargetFrameworkVersion` of `v4.x` in a `*.csproj`) also loads `references/dotnet-framework.md`, whose `api-start.ps1` replaces the one in `references/dotnet.md`.' &&
    joined <"$SKILL" | grep -qF -- 'Ask the engineer where the local database runs. For LocalDB, also load `references/sqlserver-localdb.md`, whose `db-start.ps1` replaces the one in `references/sqlserver-docker.md`.' &&
    step_has "Write the helpers" 'references/dotnet-framework.md' 'references/sqlserver-localdb.md'
}

test_skill_loads_the_ios_reference_and_copies_its_report_section() {
  joined <"$SKILL" | grep -qF -- 'For an iOS app (the repository has a `*.xcodeproj` or `*.xcworkspace`) also load `references/ios.md`, whose `ui-start.ps1` replaces the one in `references/react.md`.' &&
    joined <"$SKILL" | grep -qF -- 'For an iOS app, also copy the section `Three-way match on iOS` of `references/ios.md` after the Order of results.' &&
    step_has "Write the feature map and data setup" 'references/ios.md' &&
    step_has "Write the verify skill" 'Three-way match on iOS'
}

test_sql_server_trigger_never_reads_a_connection_string() {
  ! joined <"$SKILL" | grep -qF -- 'a SQL Server connection string' &&
    joined <"$SKILL" | grep -qF -- 'never open a settings file or user secrets to look'
}

test_skill_loads_references_by_stack() {
  joined <"$SKILL" | grep -qF -- 'Load `references/feature-map.md` for the rules that pick the features.' &&
    joined <"$SKILL" | grep -qF -- 'For React web projects (a `package.json` that lists `react-dom` under `dependencies`, in any workspace) also load `references/react.md`.' &&
    joined <"$SKILL" | grep -qF -- 'For .NET projects (the repository has `*.sln` or `*.csproj` files) also load `references/dotnet.md`.' &&
    joined <"$SKILL" | grep -qF -- 'For a SQL Server database (a `dbup-sqlserver`, `Microsoft.EntityFrameworkCore.SqlServer`, `Microsoft.Data.SqlClient` or `System.Data.SqlClient` package, or a SQL Server image in the integration tests; never open a settings file or user secrets to look, and when no signal shows, ask the engineer) also load `references/sqlserver-docker.md`.' &&
    step_has "Pick the features" 'references/feature-map.md' &&
    step_has "Write the feature map and data setup" 'references/react.md' &&
    step_has "Write the helpers" 'references/dotnet.md' 'references/sqlserver-docker.md' 'index of where the other contracts live'
}

# Names are checked by test_no_customer_names, which covers the three reference files too.
test_stack_references_use_neutral_wording() {
  has_all "$REFS/dotnet.md" "role override list" "array index"
}

# ---------------------------------------------------------------- templates and update mode

VT="$TPLS/verify-skill.md"
RP="$TPLS/report.md"
FMT="$TPLS/feature-map.md"
HP="$TPLS/helpers.md"
UM="$REFS/update-mode.md"
DN="$REFS/dotnet.md"
RX="$REFS/react.md"
DBA="$REFS/sqlserver-docker.md"
DNF="$REFS/dotnet-framework.md"
LDB="$REFS/sqlserver-localdb.md"
IOS="$REFS/ios.md"
HPS="$REFS/host-powershell.md"
HSH="$REFS/host-shell.md"

# The twelve-line Verify block and the fifteen-line evidence report, copied from the design (PLAN.local.md, "Input to
# /verify-<app>" and "Output: the evidence report"). The templates must hold the same lines, so a paraphrase fails.
VERIFY_BLOCK=$(
  cat <<'EOF'
Verify:
Ticket: <number>
Base: <base branch> @ <merge-base sha>
Change: <the user-visible behaviour that changed, 1-2 sentences; navigation only>
Feature: <feature file(s)>; entry points: <which ones>
Neighbours: <features from blast-radius> | none
Data: empty | setup: <recipe names> | bacpac: <what the data must contain> | records: <specific rows to create>
Roles: default | <role list>
Steps: <numbered user actions>
Side effects: <tables or rows to check with a read-only SELECT> | none
Diagnose: <from the diagnose hand-off, verbatim: the Confidence line, the Root cause line, and the reproduction command from the Verification line (not its expected output)> | none
Reference anchors: <calculation reference anchors, as an index only> | none
EOF
)
REPORT_BLOCK=$(
  cat <<'EOF'
Verify result: pass | fail | disagree | blocked
Ticket and branch: <...>; HEAD <sha> plus working-tree changes: <n> staged, <n> unstaged, <n> untracked files; app-code fingerprint <short hash>
Environment: container <name>, image <tag>, data <empty | setup recipes | bacpac file name and date>, DbUp scripts applied <n>
Ticket reading vs Change line: agree | conflict: <how they differ>
Expectations (written before driving): <each expected result, with its source: ticket | diagnose | base code path:line>
Steps:
  1. <action> -> <what was seen> (evidence: <file>)
Three-way match: <value>: screen <x> | API <y> | database <z> -> match | mismatch
Recomputed figures: <figure>: recomputed <x> from <rows>, screen <y> | not a calculation ticket
Neighbours checked: <feature>: pass | fail | none
Edges tried: <case>: <result> | none, and why
Reference conflicts: <anchor>: reference says <x>, base code <path:line> says <y> | none
Side effects: <SELECT> -> <counts and IDs only>
Not verified: <what, and why>
Evidence folder: <path>
EOF
)

# fenced_from <file> <first line>: the fenced block whose first line equals the text, without the fence lines. A block
# in a list item may be indented: the indent of its opening fence is removed from each line.
fenced_from() {
  awk -v s="$2" '
    /^[ ]*(```|~~~)/ { if (on) exit; f = !f; if (f) { match($0, /^ */); ind = RLENGTH }; next }
    f { line = substr($0, ind + 1) }
    f && !on && line == s { on = 1 }
    on { print line }
  ' "$1"
}

# header_of <file>: the lines of the first frontmatter block.
header_of() {
  awk 'NR == 1 && $0 != "---" { exit } /^---[ \t]*$/ { c++; if (c == 2) exit; next } c == 1' "$1"
}

test_verify_skill_template_header() {
  local h
  [ -s "$VT" ] || return 1
  h=$(header_of "$VT")
  [ -n "$h" ] || return 1
  printf '%s\n' "$h" | grep -qx 'name: verify-<app>' &&
    printf '%s\n' "$h" | grep -qx 'metadata:' &&
    printf '%s\n' "$h" | grep -qx '  generated-by: agentd-verify-init' &&
    ! printf '%s\n' "$h" | grep -q 'disable-model-invocation'
}

test_verify_block_has_the_fields_in_order_and_no_expected_line() {
  local b
  [ -s "$VT" ] || return 1
  b=$(fenced_from "$VT" 'Verify:')
  [ "$b" = "$VERIFY_BLOCK" ] || return 1
  ! printf '%s\n' "$b" | grep -q '^Expected:'
}

test_base_unknown_asks_and_never_guesses() {
  has_all "$VT" "Base: unknown" "ask the engineer for the base branch" "git merge-base HEAD" "never guesses"
}

test_input_is_two_parts() {
  has_all "$VT" "raw ticket" "Verify block" "no block" "asks the engineer for the raw ticket"
}

test_expectations_come_before_driving_and_from_the_right_sources() {
  has_all "$VT" "before it drives" &&
    section_has "$VT" Expectations "ticket" "root cause" "confirmed" "git show" "not the expected output" \
      "index, never the oracle" "conflict:"
}

test_three_way_match_and_formatting_rule() {
  section_has "$VT" "Three-way match" "screen, the API response and the database" "stored row" "derived value" \
    "display rounding" "raw values"
}

test_recompute_is_for_calculation_tickets_only() {
  section_has "$VT" "Recompute the figures" "calculation tickets only" "raw input rows"
}

test_neighbours_and_edges_are_named() {
  section_has "$VT" "Neighbours and edges" "another role" "not a member" "locked period" "empty data" \
    "first and last period"
}

test_doctor_checks() {
  section_has "$VT" Doctor "checks the ports" "signed-in API user" "role set" "container" "database target" \
    "refuses" "did not start" "authorisation switch" "sign-in values are not placeholders"
}

test_report_matches_the_specification() {
  [ -s "$RP" ] || return 1
  [ "$(fenced_from "$RP" 'Verify result: pass | fail | disagree | blocked')" = "$REPORT_BLOCK" ]
}

test_results_table_and_order() {
  local order
  has_all "$RP" "Order of results" "never changes the result" \
    "outside the ticket; may be pre-existing, not checked on the base" || return 1
  order=$(awk '/Order of results/ { on = 1; next } on && /^[0-9]\. / { print }' "$RP" |
    sed -E 's/^[0-9]\. `([a-z]+)`.*/\1/' | tr '\n' ' ')
  [ "$order" = "fail disagree blocked pass " ] || return 1
  grep -q '^| `pass` |' "$RP" && grep -q '^| `fail` |' "$RP" && grep -q '^| `disagree` |' "$RP" &&
    grep -q '^| `blocked` |' "$RP"
}

test_failed_run_goes_back_to_dev_rev() {
  has_all "$RP" "/agentd-dev-rev" "new task"
}

test_feature_map_template_has_four_sections() {
  has_all "$FMT" "Sub-features" "How to get to it" "Driving it" "Gotchas" "data-setup.md" "no customer values" \
    "inferred:"
}

test_helpers_template_lists_the_eight_helpers_and_state_keys() {
  has_all "$HP" "common.ps1" "db-start.ps1" "db-restore.ps1" "dbup-run.ps1" "api-start.ps1" "ui-start.ps1" \
    "doctor.ps1" "cleanup.ps1" "containerId" "createdAt" "dataSource" "recipes" "branchScripts" \
    "appFingerprint" "SHA-256" "git ls-files --others --exclude-standard" "working tree" \
    "environment variable" "found on PATH" "references/sqlserver-docker.md" "references/dotnet.md" \
    "references/react.md"
}

test_helpers_never_edit_settings_files() {
  has_all "$HP" "never edit settings files" "user secrets"
}

test_update_mode_steps() {
  [ -s "$UM" ] || return 1
  [ "$(grep -cE '^[0-9]+\. ' "$UM")" -ge 5 ] || return 1
  has_all "$UM" "only the verify skill's folder" "re-check the map" "drive every feature once" \
    "product regressions" "commit through the normal PR" "not generated by this skill" \
    "stop and change nothing" "Scanned commit" "git diff --name-only"
}

test_evidence_is_never_committed_or_removed() {
  has_all "$VT" "outside every repository" "never committed" "cleanup never removes"
}

# test_every_referenced_file_exists: each references/*.md and templates/*.md path named in SKILL.md exists.
test_every_referenced_file_exists() {
  local p n=0
  [ -s "$SKILL" ] || return 1
  for p in $(grep -oE '(references|templates)/[A-Za-z0-9._-]+\.md' "$SKILL" | sort -u); do
    n=$((n + 1))
    [ -s "$SKILL_DIR/$p" ] || return 1
  done
  [ "$n" -ge 6 ]
}

test_skill_loads_templates() {
  step_has "Write the feature map and data setup" 'templates/feature-map.md' &&
    step_has "Write the helpers" 'templates/helpers.md' &&
    step_has "Write the verify skill" 'templates/verify-skill.md' 'templates/report.md'
}

test_cleanup_stops_processes_only() {
  has_all "$HP" "cleanup.ps1" "stops the API and UI processes" "never removes the container" "state.json" \
    "evidence folder" "asks the engineer before removing"
}

test_app_fingerprint_definition() {
  has_all "$HP" 'git diff <merge-base sha>' "untracked files" "outside the scripts folder" "SHA-256"
}

test_fingerprint_leaves_out_local_only_files() {
  has_all "$HP" "and the local-only files" "LocalOnlyFiles" "the agent never reads their content" "engineer approves each entry"
}

test_helpers_contract_names_the_local_only_list() {
  section_has "$HP" common.ps1 "local-only files" "LocalOnlyFiles"
}

test_gotchas_say_a_local_only_edit_never_forces_a_restore() {
  section_has "$VT" Gotchas "never forces a restore" "a branch script that changed or was removed" \
    "an app-code change outside the scripts folder, this skill's folder and the local-only files" \
    "a new branch script is applied by the migration runner without a restore" &&
    ! section_has "$VT" Gotchas "any other change in the working tree"
}

test_stored_procedures_need_no_hash() {
  has_all "$HP" "re-run on every" "need no hash"
}

test_unknown_journal_entries_are_listed() {
  has_all "$DBA" "neither the base nor the branch" "go under Environment and under Not verified"
}

test_role_mismatch_hint() {
  has_all "$HP" "another configuration source" "the engineer can give their count" \
    "must equal the wanted set exactly"
}

test_disagree_still_drives_and_reports_both_readings() {
  has_all "$RP" "still drives" "both readings"
}

test_db_restore_stops_on_a_journal_conflict() {
  has_all "$DBA" "db-restore.ps1" "already lists a branch script" "blocked" "before the upgrade"
}

test_update_mode_promotes_a_proven_draft() {
  has_all "$UM" "draft: not proven" "Not proven:" "proof run" "engineer present" \
    'remove the `draft: not proven` line'  
}

test_helpers_refuse_without_the_connection_variable() {
  has_all "$DN" "dbup-run.ps1" "api-start.ps1" "refuse to run" "names the container" \
    "never fall back to a settings file"
}

test_fresh_restore_rules() {
  has_all "$DBA" "drop and recreate" "per-ticket database" "never drops any other database" &&
    has_all "$HP" "the report says" &&
    section_has "$DBA" db-start.ps1 "In a terminal, the helper prompts the engineer" \
      "An agent without a terminal asks the engineer and runs the helper again with \`-ConfirmRestore\`" \
      "Without the switch and without a terminal, the helper refuses with \`blocked\` and never drops"
}

test_container_and_state_rules_are_pinned() {
  has_all "$DBA" "never azure-sql-edge" "host port other than 1433" "unique container name" "kept between runs" \
    "made by SQL, not through the app" &&
    has_all "$HP" "a hash is recorded only after" "a different container ID resets the recipe list" \
      "a removed script forces a fresh restore"
}

test_browser_and_session_rules_are_pinned() {
  has_all "$VT" "chrome-devtools-axi" "npx" "fresh session" \
    "only the feature map, the raw ticket and the Verify block" "not a task agent by default" || return 1
  has_all "$SKILL" "scripting language of the repository" || has_all "$HP" "scripting language of the repository"
}

test_neighbours_and_edges_not_tried_still_allow_pass() {
  has_all "$RP" "not tried" "Not verified" "still allow pass"
}

test_feature_map_template_records_the_scanned_commit() {
  has_all "$FMT" "Scanned commit:" "Scanned on:"
}

test_verify_template_marks_the_optional_draft_line() {
  has_all "$VT" "draft: not proven" "Not proven:" "only by the Create flow"
}

test_gotchas_say_why_the_flag_is_left_out() {
  section_has "$VT" Gotchas "Copilot cannot load a skill that has the flag" "may add it back"
}

# ---------------------------------------------------------------- agentd-dev-rev change

DEV="$REPO/skills/agentd-dev-rev/SKILL.md"

# dev_step <n>: the text of Workflow step n in agentd-dev-rev, as one line. It runs to the next numbered step or H2.
dev_step() {
  section_of "$DEV" Workflow 2>/dev/null | awk -v n="$1" '
    /^[0-9]+\. / { on = (index($0, n ". ") == 1) }
    on' | joined
}

# dev_step_has <n> <text>...: Workflow step n contains every text, ignoring case.
dev_step_has() {
  local body t
  body=$(dev_step "$1")
  [ -n "$body" ] || return 1
  shift
  for t in "$@"; do printf '%s\n' "$body" | grep -qiF -- "$t" || return 1; done
}

# in_order <body> <text>...: each text occurs in the body, and each after the one before it.
in_order() {
  local rest=$1 t
  shift
  for t in "$@"; do
    case "$rest" in *"$t"*) rest=${rest#*"$t"} ;; *) return 1 ;; esac
  done
}

test_dev_rev_has_verify_handoff_step() {
  [ -s "$DEV" ] || return 1
  [ "$(section_of "$DEV" Workflow | grep -E '^[0-9]+\. \*\*' | sed -E 's/^([0-9]+)\. \*\*([^*]*)\*\*.*/\1 \2/; s/\.$//' |
    tr '\n' '|')" = '1 Understand the task and repo|2 Implement with TDD and coverage|3 Validate locally|4 Stage only task changes|5 Review Round 1|6 Triage findings|7 Decide on Review Round 2|8 Handoff|9 Verify hand-off|' ] &&
    grep -qF '9. **Verify hand-off.**' "$DEV"
}

test_dev_rev_step_8_points_to_step_9() {
  local b
  b=$(dev_step 8)
  [ -n "$b" ] || return 1
  in_order "$b" 'Do not commit.' 'Then do step 9.' 'send this report first' 'in the next message' || return 1
  case "$b" in *'in the same message'*) return 1 ;; esac
}

test_dev_rev_verify_block_matches_the_template() {
  local d t
  [ -s "$DEV" ] && [ -s "$VT" ] || return 1
  d=$(fenced_from "$DEV" 'Verify:')
  t=$(fenced_from "$VT" 'Verify:')
  [ -n "$d" ] && [ "$d" = "$t" ] && [ "$d" = "$VERIFY_BLOCK" ] && ! printf '%s\n' "$d" | grep -q '^Expected:'
}

test_dev_rev_base_step() {
  dev_step_has 9 'git symbolic-ref refs/remotes/origin/HEAD' 'confirms it or names another' \
    'git merge-base HEAD' 'Base: unknown'
}

test_dev_rev_diagnose_field() {
  dev_step_has 9 'Confidence line' 'Root cause line' 'reproduction command' 'leave out the expected output' 'verbatim'
}

test_dev_rev_none_case() {
  dev_step_has 9 'Verify: none:' 'no user-visible effect'
}

test_dev_rev_finds_only_marked_skills() {
  dev_step_has 9 'verify-*/SKILL.md' '.github/skills/' '.claude/skills/' 'generated-by: agentd-verify-init' \
    'ignore' 'list them and ask'
}

test_dev_rev_closing_lines() {
  local b
  b=$(dev_step 9)
  [ -n "$b" ] || return 1
  printf '%s\n' "$b" | grep -qF 'Run `/verify-<app>` in a fresh session' &&
    printf '%s\n' "$b" | grep -qF 'paste the raw ticket and the Verify block' &&
    printf '%s\n' "$b" | grep -qF 'No project verify skill. Run `/agentd-verify-init` once, or verify by hand.'
}

test_dev_rev_no_block_without_a_verify_skill() {
  dev_step_has 9 'no Verify block'
}

test_dev_rev_failed_verify_is_a_new_task() {
  dev_step_has 9 'failed verification' 'new task'
}

test_dev_rev_marker_lookup_comes_first() {
  local b
  b=$(dev_step 9)
  [ -n "$b" ] || return 1
  in_order "$b" 'verify-*/SKILL.md' 'asks no base-branch question' 'git symbolic-ref' 'Verify:' || return 1
  dev_step_has 9 'asks no base-branch question' 'no Verify block'
}

test_dev_rev_nobody_to_answer_writes_base_unknown() {
  dev_step_has 9 'nobody to answer' 'Base: unknown'
}

test_dev_rev_never_launches_the_app() {
  dev_step_has 9 'never launches the app'
}

test_dev_rev_maps_blast_radius_paths_to_features() {
  dev_step_has 9 'Risks to cover' 'Neighbours:' 'features/README.md' 'none'
}

test_dev_rev_rules_not_weakened() {
  local r
  [ -s "$DEV" ] || return 1
  has_all "$DEV" 'Never commit.' 'Reviewer model floor is mandatory.' 'Two review rounds maximum.' &&
    [ "$(grep -c 'git commit' "$DEV")" -le 1 ] || return 1
  h2_list "$DEV" | grep -qx 'Common Mistakes' && h2_list "$DEV" | grep -qx 'Red Flags' || return 1
  for r in '| Committing after review passes | Keep changes staged and hand off. |' \
    '| Reviewing unstaged or narrative-only changes | Review the actual staged diff. |' \
    '| Silently accepting product/backcompat decisions | Ask the engineer. |' \
    '| Hiding disagreed claims | Report them with evidence. |' \
    '- "I'"'"'ll commit now and review later."' '- "A cheaper reviewer is better than nothing."' \
    '- "I reviewed it myself carefully."'; do
    grep -qxF -- "$r" "$DEV" || return 1
  done
}

# ---------------------------------------------------------------- run

check "frontmatter name matches the folder" test_frontmatter_name_matches_folder
check "description starts with Use when and covers the job" test_description_starts_with_use_when_and_covers_the_job
check "the skill is manual-only" test_skill_is_manual_only
check "SKILL.md is at most 120 lines" test_skill_is_at_most_120_lines
check "H2 sections in order" test_required_h2_sections_in_order
check "modes are Create and Update" test_modes_are_create_and_update
check "Flow has eight numbered steps in order" test_flow_has_eight_numbered_steps_in_order
check "it asks the allowed tool and whether files are committed" test_asks_tool_and_commit
check "committed-file rules" test_committed_file_rules
check "it never types credentials" test_never_types_credentials
check "it never reads secrets" test_never_reads_secrets
check "the proof run is required" test_proof_run_is_required
check "no sign-in marks the skill draft: not proven" test_no_sign_in_marks_draft_not_proven
check "the marker is written as nested YAML" test_marker_is_written_nested
check "the six independence mechanisms are named" test_six_independence_mechanisms_are_named
check "no reference marks the drive recipe inferred" test_no_reference_marks_inferred
check "it does not start another skill" test_does_not_start_another_skill
if [ -s "$NAMES" ]; then
  check "no customer or project names in tracked files" test_no_customer_names
else
  printf '  skip  no customer-names list\n'
fi
check "no absolute home paths" test_no_absolute_home_paths
check "no phrase is copied from the source skills" test_no_phrase_is_copied_from_pstack
check "dotnet.md has the five H2s in order" test_dotnet_reference_h2s_exact
check "dotnet.md names where to look" test_dotnet_reference_names_where_to_look
check "a bacpac whose journal lists a branch script is blocked" test_bacpac_journal_conflict_is_blocked
check "dotnet-framework.md has the seven H2s in order" test_dotnet_framework_reference_h2s_exact
check "dotnet-framework.md names where to look" test_dotnet_framework_reference_names_where_to_look
check "sqlserver-localdb.md has the three H2s in order" test_localdb_reference_h2s_exact
check "sqlserver-localdb.md names where to look" test_localdb_reference_names_where_to_look
check "SKILL.md loads the Framework and LocalDB references" test_skill_loads_the_framework_and_localdb_references
check "host-powershell.md has the two H2s in order" test_host_powershell_reference_h2s_exact
check "host-powershell.md names where to look" test_host_powershell_reference_names_where_to_look
check "host-shell.md has the two H2s in order" test_host_shell_reference_h2s_exact
check "host-shell.md names where to look" test_host_shell_reference_names_where_to_look
check "SKILL.md loads the host references" test_skill_loads_the_host_references
check "the helpers index names the host references" test_helpers_index_names_the_host_references
check "the generated Gotchas name no single stack" test_generated_gotchas_name_no_single_stack
check "the generator notes cover an iOS driver" test_generator_notes_cover_an_ios_driver
check "ios.md has the seven H2s in order" test_ios_reference_h2s_exact
check "ios.md names where to look" test_ios_reference_names_where_to_look
check "SKILL.md loads the iOS reference and copies its report section" test_skill_loads_the_ios_reference_and_copies_its_report_section
check "the iOS Doctor replaces the generic Doctor" test_ios_doctor_replaces_the_generic_doctor
check "LocalDB covers Doctor and cleanup" test_localdb_reference_covers_doctor_and_cleanup
check "a Framework runner that reads a settings file asks for the confirmation" test_framework_reference_covers_a_runner_that_reads_a_settings_file
check "the PowerShell 5.1 encoding rule is complete" test_powershell_encoding_rule_is_complete
check "iOS privacy filter and a missing xcodegen" test_ios_privacy_filter_and_missing_xcodegen
check "dotnet.md puts the port rule in the Gotchas" test_dotnet_api_start_puts_the_port_rule_in_the_gotchas
check "host-shell.md warns about the empty array under set -u" test_host_shell_warns_about_the_empty_array_under_set_u
check "the PowerShell query rule covers LocalDB" test_powershell_query_rule_covers_localdb
check "SKILL.md picks the helper language first" test_skill_picks_the_helper_language_first
check "a recreated LocalDB database changes the containerId value" test_localdb_container_id_changes_when_the_database_is_recreated
check "the Parallels user fact lives in the LocalDB reference" test_localdb_reference_holds_the_parallels_user_fact
check "the settings-file confirmation is recorded per database" test_the_settings_file_confirmation_is_recorded_per_database
check "Framework roles are the engineer's step" test_framework_roles_are_the_engineers_step
check "Framework Doctor matches the process ID" test_framework_doctor_matches_the_process_id
check "iOS Doctor checks the installed build, one log filter" test_ios_doctor_checks_the_installed_build_and_uses_one_log_filter
check "iOS builds the app with build" test_ios_builds_the_app_with_build_not_build_for_testing
check "SKILL.md asks which UI the ticket drives" test_skill_asks_which_ui_the_ticket_drives
check "sqlserver-docker.md has the four H2s in order" test_sqlserver_docker_reference_h2s_exact
check "sqlserver-docker.md names where to look" test_sqlserver_docker_reference_names_where_to_look
check "react.md has the six H2s in order" test_react_reference_h2s_exact
check "helpers.md covers a stack without a reference" test_helpers_template_covers_a_stack_without_a_reference
check "sqlserver-docker.md states its dependency on the migration runner" test_database_reference_states_its_dependency_on_the_migration_runner
check "dotnet.md says the helper contracts follow the database reference" test_dotnet_reference_says_the_helper_contracts_follow_the_database_reference
check "every helper has one contract, in the file the index names" test_every_helper_has_one_contract_in_the_indexed_file
check "react.md names where to look" test_react_reference_names_where_to_look
check "feature-map.md has the three H2s in order" test_feature_map_reference_h2s_exact
check "feature-map.md picks about five features" test_feature_map_reference_picks_about_five
check "SKILL.md loads the references by stack" test_skill_loads_references_by_stack
check "the SQL Server trigger never reads a connection string" test_sql_server_trigger_never_reads_a_connection_string
check "stack references use neutral wording" test_stack_references_use_neutral_wording

check "verify-skill.md header has the name and the nested marker, no flag" test_verify_skill_template_header
check "the Verify block has the twelve fields in order and no Expected line" test_verify_block_has_the_fields_in_order_and_no_expected_line
check "Base: unknown asks the engineer and never guesses" test_base_unknown_asks_and_never_guesses
check "the input is the raw ticket and the Verify block" test_input_is_two_parts
check "expectations come before driving, from the right sources" test_expectations_come_before_driving_and_from_the_right_sources
check "three-way match and the formatting rule" test_three_way_match_and_formatting_rule
check "recompute is for calculation tickets only" test_recompute_is_for_calculation_tickets_only
check "neighbours and edges are named" test_neighbours_and_edges_are_named
check "Doctor checks" test_doctor_checks
check "report.md matches the specification" test_report_matches_the_specification
check "results table and order of results" test_results_table_and_order
check "a failed run goes back to agentd-dev-rev" test_failed_run_goes_back_to_dev_rev
check "feature-map template has the four sections" test_feature_map_template_has_four_sections
check "helpers template lists the eight helpers and the state keys" test_helpers_template_lists_the_eight_helpers_and_state_keys
check "helpers never edit settings files" test_helpers_never_edit_settings_files
check "update-mode.md has the numbered steps" test_update_mode_steps
check "evidence is never committed or removed" test_evidence_is_never_committed_or_removed
check "every referenced file exists" test_every_referenced_file_exists
check "SKILL.md Flow loads the templates" test_skill_loads_templates
check "cleanup stops the processes only" test_cleanup_stops_processes_only
check "app fingerprint definition" test_app_fingerprint_definition
check "fingerprint leaves out local-only files" test_fingerprint_leaves_out_local_only_files
check "helpers contract names the local-only list" test_helpers_contract_names_the_local_only_list
check "Gotchas: a local-only edit never forces a restore" test_gotchas_say_a_local_only_edit_never_forces_a_restore
check "stored procedures need no hash" test_stored_procedures_need_no_hash
check "unknown journal entries are listed" test_unknown_journal_entries_are_listed
check "role mismatch hint" test_role_mismatch_hint
check "disagree still drives and reports both readings" test_disagree_still_drives_and_reports_both_readings
check "db-restore stops on a journal conflict" test_db_restore_stops_on_a_journal_conflict
check "update mode promotes a proven draft" test_update_mode_promotes_a_proven_draft
check "helpers refuse to run without the connection variable" test_helpers_refuse_without_the_connection_variable
check "fresh restore rules" test_fresh_restore_rules
check "container and state rules are pinned" test_container_and_state_rules_are_pinned
check "browser and session rules are pinned" test_browser_and_session_rules_are_pinned
check "neighbours and edges not tried still allow pass" test_neighbours_and_edges_not_tried_still_allow_pass
check "feature-map template records the scanned commit" test_feature_map_template_records_the_scanned_commit
check "verify-skill.md marks the optional draft line" test_verify_template_marks_the_optional_draft_line
check "Gotchas say why the flag is left out" test_gotchas_say_why_the_flag_is_left_out
check "dev-rev has step 9 Verify hand-off after step 8" test_dev_rev_has_verify_handoff_step
check "dev-rev step 8 points to step 9 and sends its report first" test_dev_rev_step_8_points_to_step_9
check "dev-rev Verify block equals the template block" test_dev_rev_verify_block_matches_the_template
check "dev-rev finds the base branch with a merge-base" test_dev_rev_base_step
check "dev-rev copies the diagnose lines and leaves out the expected output" test_dev_rev_diagnose_field
check "dev-rev writes Verify: none: for a change with no user-visible effect" test_dev_rev_none_case
check "dev-rev finds only marked verify skills" test_dev_rev_finds_only_marked_skills
check "dev-rev closing lines" test_dev_rev_closing_lines
check "dev-rev writes no Verify block without a verify skill" test_dev_rev_no_block_without_a_verify_skill
check "dev-rev: a failed verification is a new task" test_dev_rev_failed_verify_is_a_new_task
check "dev-rev marker lookup comes before the Base: sub-steps" test_dev_rev_marker_lookup_comes_first
check "dev-rev writes Base: unknown with nobody to answer" test_dev_rev_nobody_to_answer_writes_base_unknown
check "dev-rev never launches the app" test_dev_rev_never_launches_the_app
check "dev-rev maps blast-radius paths to features" test_dev_rev_maps_blast_radius_paths_to_features
check "dev-rev rules are not weakened" test_dev_rev_rules_not_weakened
# ---------------------------------------------------------------- agentd-pr-prep change

PRP="$REPO/skills/agentd-pr-prep/SKILL.md"

test_pr_prep_testing_may_quote_a_pasted_verify_report() {
  has_all "$PRP" "the Testing section" "verify report" "the engineer pastes" "result line" "environment line" \
    "Not verified" "verbatim"
}
test_pr_prep_summary_and_changes_stay_diff_only() {
  has_all "$PRP" "Base the content only on the actual diff" "Summary and Changes still come only from the diff"
}
test_pr_prep_non_pass_asks_first() {
  has_all "$PRP" "not pass" "before the draft" "whether to quote it"
}
test_pr_prep_never_runs_verify_or_reads_evidence() {
  has_all "$PRP" "never runs the verify skill" "never reads the evidence folder"
}
test_pr_prep_without_a_report_testing_is_unchanged() {
  has_all "$PRP" "Without a pasted report"
}

check "pr-prep Testing may quote a pasted verify report" test_pr_prep_testing_may_quote_a_pasted_verify_report
check "pr-prep Summary and Changes stay diff-only" test_pr_prep_summary_and_changes_stay_diff_only
check "pr-prep asks first when the result is not pass" test_pr_prep_non_pass_asks_first
check "pr-prep never runs verify or reads the evidence folder" test_pr_prep_never_runs_verify_or_reads_evidence
check "pr-prep Testing is unchanged without a report" test_pr_prep_without_a_report_testing_is_unchanged
# ---------------------------------------------------------------- helper run-time defects

test_helpers_brace_a_variable_before_a_question_mark() {
  section_has "$HPS" Rules '${name}?' "variable is followed by" "only fails at run time"
}

test_state_reader_defaults_launch_keys_to_null() {
  section_has "$HP" "common.ps1" "default every launch key to null" "missing" &&
    section_has "$HPS" Rules "test that the key exists first" "strict mode"
}

test_api_start_does_not_need_the_plain_http_port() {
  section_has "$DN" "api-start.ps1" "must not require the plain-HTTP port" "--urls" "secure port only" \
    "names the process that holds"
}

test_gotchas_name_the_launch_profile_ports() {
  section_has "$VT" Gotchas "a fixed port" "<port>" "AirPlay Receiver" "the stack reference says how to change the port"
}

test_dbup_count_is_the_journal_row_count() {
  section_has "$DN" "dbup-run.ps1" "journal row count" "SELECT COUNT(*)" "not a count of lines"
}

test_helpers_get_a_run_time_smoke_check() {
  section_has "$HP" "Rules for every helper" "prerequisites missing" "its own \`blocked:\` message" \
    "instead of a shell error" &&
    step_has "Write the helpers" "prerequisites missing" "blocked:"
}

test_usage_examples_show_the_ticket_placeholder() {
  section_has "$HP" "Rules for every helper" "usage example" "<ticket>" "real work item number"
}

check "helpers brace a variable before a question mark" test_helpers_brace_a_variable_before_a_question_mark
check "the state reader defaults launch keys to null" test_state_reader_defaults_launch_keys_to_null
check "api-start does not need the plain-HTTP port" test_api_start_does_not_need_the_plain_http_port
check "Gotchas name the launch profile ports" test_gotchas_name_the_launch_profile_ports
check "the DbUp count is the journal row count" test_dbup_count_is_the_journal_row_count
check "helpers get a run-time smoke check" test_helpers_get_a_run_time_smoke_check
check "usage examples show the ticket placeholder" test_usage_examples_show_the_ticket_placeholder
# ---------------------------------------------------------------- helper and browser defects from the end-to-end evaluation

test_query_results_are_wrapped_in_an_array() {
  section_has "$HPS" Rules 'wrap query results in `@()`' "before indexing or counting" \
    "one-row result" "plain string"
}

test_browser_runs_headed_with_a_named_session() {
  section_has "$VT" "Browser and session" "headed" "named session per ticket" "environment variables" \
    "on every call" "headless by default"
}

test_browser_background_process_starts_at_the_repository_root() {
  section_has "$VT" "Browser and session" "from the repository root" "uploads files only from under"
}

test_sign_in_wait_is_a_poll_that_prints_booleans() {
  section_has "$VT" "Browser and session" "every 5 seconds" "600 seconds" "identity provider" \
    "known app element" "only true or false" "never the URL" "only asked to sign in"
}

test_browser_double_click_and_stale_references() {
  section_has "$VT" "Browser and session" "no double-click command" "mousedown, mouseup, click twice, dblclick" \
    "evaluate call" "stale after every action" "new snapshot before each click"
}

test_saved_responses_get_a_network_response_suffix() {
  section_has "$VT" "Browser and session" ".network-response" "whatever name is given" "copy it to the name"
}

test_react_grid_dropdown_commits_on_option_click() {
  section_has "$REFS/react.md" Grids "drop-down cell" "commits only when the option is clicked" "not with Enter"
}

test_browser_output_privacy_rules() {
  section_has "$VT" "Browser and session" "authorize URL" "Authorization header" "person's name" \
    "filter these from tool output" "never paste a response body" "evidence files are the only place" &&
    section_has "$HP" "Rules for every helper" "authorize URL" "Authorization header" "person's name" \
      "filter these from tool output" "outside every repository"
}

test_state_json_records_the_evidence_folder() {
  section_has "$HP" "state.json" "evidenceFolder" "evidence folder of the current run" "newest timestamp" &&
    [ "$(section_of "$HP" "state.json" | grep -c '^| `')" -eq 7 ]
}

test_gotchas_intro_is_refreshed_by_the_proof_run() {
  section_has "$VT" Gotchas "unknown:" "inferred:" "replace each" "after a passing proof run" &&
    ! section_has "$VT" Gotchas "nothing is confirmed"
}

test_update_mode_step_8_refreshes_gotchas() {
  has_all "$UM" 'replace each `unknown:` and `inferred:` gotcha' "confirmed or refuted" \
    "remove the fixed-port text for any port the run found unused"
}

test_doctor_wrong_role_message_names_the_cause_first() {
  section_has "$HP" "doctor.ps1" "likely cause first" "the API was started with other roles; run the API start helper again" \
    "set difference"
}

test_merge_base_without_a_local_branch() {
  dev_step_has 9 'no local branch' 'git merge-base HEAD origin/<branch>' &&
    section_has "$VT" Input 'no local branch' 'git merge-base HEAD origin/<branch>'
}

test_smoke_check_skips_the_sourced_file() {
  step_has "Write the helpers" "except the shared file that is only sourced" &&
    section_has "$HP" "Rules for every helper" "except the shared file that is only sourced"
}

check "helpers wrap query results in an array" test_query_results_are_wrapped_in_an_array
check "browser runs headed with a named session per ticket" test_browser_runs_headed_with_a_named_session
check "browser background process starts at the repository root" test_browser_background_process_starts_at_the_repository_root
check "sign-in wait is a poll that prints booleans only" test_sign_in_wait_is_a_poll_that_prints_booleans
check "browser double-click and stale references" test_browser_double_click_and_stale_references
check "saved responses get a .network-response suffix" test_saved_responses_get_a_network_response_suffix
check "react.md: a grid drop-down commits on option click" test_react_grid_dropdown_commits_on_option_click
check "browser output privacy rules" test_browser_output_privacy_rules
check "state.json records the evidence folder" test_state_json_records_the_evidence_folder
check "Gotchas intro is refreshed by the proof run" test_gotchas_intro_is_refreshed_by_the_proof_run
check "update mode step 8 refreshes the Gotchas" test_update_mode_step_8_refreshes_gotchas
check "Doctor wrong-role message names the cause first" test_doctor_wrong_role_message_names_the_cause_first
check "merge base without a local branch" test_merge_base_without_a_local_branch
check "smoke check skips the sourced file" test_smoke_check_skips_the_sourced_file
# ---------------------------------------------------------------- review round 1 fixes

# vt_step_has <step name> <text>...: the Flow step of the generated-skill template with this name contains every text.
vt_step_has() {
  local name=$1 body t
  shift
  body=$(section_of "$VT" Flow 2>/dev/null | awk -v n="**$name" '
    /^[0-9]+\. / { on = (index($0, ". " n) > 0) }
    on' | joined)
  [ -n "$body" ] || return 1
  for t in "$@"; do printf '%s\n' "$body" | grep -qiF -- "$t" || return 1; done
}

test_generated_flow_orders_start_sign_in_then_doctor() {
  [ -s "$VT" ] || return 1
  [ "$(section_of "$VT" Flow | grep -E '^[0-9]+\. \*\*' | sed -E 's/^([0-9]+)\. \*\*([^*]*)\*\*.*/\1 \2/; s/\.$//' |
    tr '\n' '|')" = '1 Read the input|2 Write the expectations|3 Start the data and the app|4 Make the evidence folder|5 Sign in|6 Run Doctor|7 Set up the data|8 Drive|9 Check|10 Report and clean up|' ]
}

test_generated_flow_start_sequence_has_one_owner_per_job() {
  local b
  b=$(section_of "$VT" Flow | awk '/^[0-9]+\. / { on = (index($0, ". **Start the data and the app") > 0) } on' | joined)
  [ -n "$b" ] || return 1
  in_order "$b" '`db-start.ps1`' '`db-restore.ps1`' '`dbup-run.ps1`' '`api-start.ps1`' '`ui-start.ps1`' || return 1
  vt_step_has "Start the data and the app" \
    "\`db-restore.ps1\`: only when the data is a bacpac and \`db-start.ps1\` printed \`database: new\` or \`database: dropped\`." \
    "\`dbup-run.ps1\`: on every run, after \`db-start.ps1\` and after \`db-restore.ps1\` when that ran." \
    "fresh restore needed" &&
    ! has_all "$VT" "always after any restore or import"
}

test_generated_flow_evidence_folder_and_doctor_inputs() {
  vt_step_has "Make the evidence folder" "New-EvidenceFolder" "evidenceFolder" "state.json" &&
    vt_step_has "Run Doctor" "doctor.ps1" "saved response" "<current-user route>" "evidence folder" \
      "The token is never printed or saved" &&
    vt_step_has "Set up the data" "setup recipes" "as admin" "record each one in" "state.json" \
      "restart the API with the roles of the \`Roles:\` line" "reload the page" \
      "save a new current-user response to a new file in the evidence folder" \
      "run \`doctor.ps1\` with that file and the roles of the \`Roles:\` line" &&
    vt_step_has "Run Doctor" "<current-user route>" &&
    ! has_all "$VT" "api/users/me"
}

test_generated_flow_stops_in_a_session_that_made_the_change() {
  vt_step_has "Read the input" "If this session made, reviewed or staged the change" \
    "stop and ask the engineer to start a fresh session"
}

test_doctor_helper_reads_the_saved_user_response() {
  section_has "$HP" doctor.ps1 "saved response file" "evidence folder" "never printed or saved" "after sign-in" \
    "After an API restart, pass the path of a new saved response file" "never the file from before the restart"
}

test_one_owner_per_job_in_the_data_helpers() {
  section_has "$DBA" db-start.ps1 "scripts folder" "state check" "fresh restore needed" "It never imports a bacpac" &&
    ! section_has "$DBA" db-start.ps1 "import the bacpac" &&
    section_has "$DBA" db-restore.ps1 "Imports the bacpac" "the upgrade always follows in" &&
    section_has "$DN" dbup-run.ps1 "It runs on every run, after \`db-start.ps1\`, and after \`db-restore.ps1\` when that ran." &&
    ! has_all "$HP" "always runs after any restore or import" "always after any restore or import"
}

test_generator_copies_everything_under_report_and_results() {
  local p='Copy everything under `## Report` and `## Results` of `templates/report.md`'
  step_has "Write the verify skill" "$p" "Order of results" &&
    has_all "$VT" "$p" "Order of results" &&
    has_all "$RP" 'Copy everything under `## Report` and `## Results` of this file' "Order of results"
}

test_independence_rules_are_pinned_as_whole_sentences() {
  section_has "$VT" Expectations "Expectations never come from the diff or from the branch's new code." \
    "Never use the expected output from the diagnose hand-off: it was written by the fixing side, so it is not the expected output you may trust." &&
    section_has "$VT" "Recompute the figures" "It does not come from the calculation reference." &&
    section_has "$VT" Flow "Never type credentials." &&
    section_has "$VT" "Browser and session" "Never type credentials." &&
    section_has "$SKILL" Rules "Expectations never come from the diff." &&
    section_has "$RP" Results 'It wins over `disagree` and `blocked`.'
}

test_report_wording_follows_the_specification() {
  section_has "$RP" Results 'when any check failed that does not depend on the contested reading (a three-way mismatch, a recomputed figure, a neighbour or an edge, or an expectation both readings share).' \
    "Only three core checks make the result \`blocked\` when not done: an expectation, a three-way leg for a ticket value, and a recomputed figure on a calculation ticket." &&
    ! has_all "$RP" "Every other core check"
}

test_skill_flow_step_1_does_not_load_the_stack_reference() {
  step_has "Read the project" "Note the stack." &&
    ! step_has "Read the project" "load its reference"
}

test_unmarked_verify_skill_is_never_overwritten() {
  section_has "$SKILL" Modes "Lookup ignores an unmarked" "Update mode stops and changes nothing" \
    "Create mode stops and asks for another name when its target folder exists without the marker" &&
    has_all "$UM" "is not generated by this skill"
}

test_update_mode_updates_the_scan_lines_in_the_body() {
  has_all "$UM" 'update the two scan lines at the top of `features/README.md`' &&
    ! has_all "$UM" "update the header"
}

test_no_fence_at_column_0_splits_a_numbered_list() {
  [ -s "$SKILL" ] && [ -s "$DEV" ] || return 1
  [ "$(awk '/^## Flow/ { on = 1; next } /^## / { on = 0 } on && /^(```|~~~)/ { n++ } END { print n + 0 }' "$SKILL")" -eq 0 ] &&
    [ "$(awk '/^## Workflow/ { on = 1; next } /^## / { on = 0 } on && /^(```|~~~)/ { n++ } END { print n + 0 }' "$DEV")" -eq 0 ]
}

test_dev_rev_step_9_orders_none_and_base_and_never_writes_an_unconfirmed_base() {
  local b
  b=$(dev_step 9)
  [ -n "$b" ] || return 1
  in_order "$b" '**Marker lookup first.**' '**No user-visible effect.**' '**Base.**' '**The block.**' || return 1
  dev_step_has 9 'before the base-branch question' 'Never write a `Base:` the engineer did not confirm' \
    'write the block after the answer' 'If `git merge-base` prints nothing, write `Base: unknown`'
}

test_restore_and_dbup_helpers_know_the_branch_scripts() {
  section_has "$DBA" db-restore.ps1 "merge-base sha" "scripts folder" "Get-BranchScripts" &&
    section_has "$DN" dbup-run.ps1 "merge-base sha" "scripts folder" "Get-BranchScripts"
}

test_every_state_key_has_a_writer() {
  section_has "$DBA" db-start.ps1 "writes \`containerId\` and \`createdAt\` when it creates the container" \
    "clears \`branchScripts\` and \`recipes\`" &&
    section_has "$DN" dbup-run.ps1 "writes \`appFingerprint\` after a successful run" \
      "drops the entries of removed scripts" &&
    section_has "$DBA" db-start.ps1 "-ConfirmRestore"
}

test_fresh_restore_has_one_rule() {
  vt_step_has "Start the data and the app" "it prints \`fresh restore needed: <reason>\` and, without a terminal, stops" \
    "run it again with \`-ConfirmRestore\`" &&
    section_has "$DBA" db-start.ps1 "print \`fresh restore needed: <reason>\`" \
      "ends with \`blocked: fresh restore needed: <reason>\`"
}

test_doctor_and_copy_sentences_are_pinned_whole() {
  step_has "Write the verify skill" "including the notes and the Order of results." &&
    section_has "$VT" Doctor 'Run `doctor.ps1` after sign-in, and again after any API restart, before every drive.' \
      "It never asks for, prints or saves the token." &&
    [ "$(section_of "$VT" Flow | awk '/^[0-9]+\. / { on = (index($0, "1. **Read the input.**") == 1) } on' | joined |
      grep -c 'stop and ask the engineer to start a fresh session\. $')" -eq 1 ]
}

test_update_mode_ignores_an_unmarked_skill_until_no_marked_one_is_left() {
  has_all "$UM" "is not generated by this skill. Ignore it. If no marked skill is left, stop and change nothing."
}

test_eval_says_the_round_1_changes_were_not_run() {
  section_has "$EVAL" "Not run or not verified" "round 1 and round 2 review changes" "the later rulings" \
    "structure test only"
}

test_a_changed_data_source_forces_a_fresh_restore() {
  section_has "$HP" state.json "A changed data source (for example \`empty\` to \`bacpac\`) also forces a fresh restore" &&
    section_has "$DBA" db-start.ps1 "the data source"
}

test_feature_map_has_a_code_folders_column() {
  has_all "$FMT" '| Feature | File | Code folders | Why it is here |' "Code folders are repository paths relative to the repository root, not customer values" &&
    section_has "$REFS/feature-map.md" Rank "Code folders column" &&
    dev_step_has 9 "\`Code folders\` column" "Risks to cover" "Neighbours:"
}

test_update_mode_does_not_drive_when_no_code_changed() {
  section_has "$SKILL" Modes "drive every feature once, unless no code changed since the scan and the skill is not a draft" \
    "stop and change nothing"
}

test_ui_start_runs_the_named_fix_command() {
  section_has "$RX" ui-start.ps1 "prints the fix command" "It never runs the command itself" \
    "The fix command must not change tracked files (for npm, \`npm ci\`, never \`npm install\`)" &&
    vt_step_has "Start the data and the app" "it prints a fix command" \
      "Show it to the engineer, run it once, then run \`ui-start.ps1\` again" "git status --porcelain" \
      "a changed tracked file is \`blocked\`" "A second \`blocked\` ends the run."
}

check "a changed data source forces a fresh restore" test_a_changed_data_source_forces_a_fresh_restore
check "feature map has a Code folders column that dev-rev reads" test_feature_map_has_a_code_folders_column
check "update mode does not drive when no code changed" test_update_mode_does_not_drive_when_no_code_changed
check "ui-start runs the named fix command after showing it" test_ui_start_runs_the_named_fix_command
test_db_start_sees_the_bacpac_and_writes_the_data_source_late() {
  section_has "$DBA" db-start.ps1 "data source (\`empty\`, or the bacpac file name and its date)" \
    "writes \`dataSource\` only after the state check passes or after a confirmed drop, never on a \`blocked\` exit" \
    "With \`-ConfirmRestore\` and no forced reason, the helper drops and recreates the database on request." \
    "\`database: new\`, \`database: reused\` or \`database: dropped\`" &&
    section_has "$HP" state.json "a different container ID resets the recipe list, clears \`branchScripts\`, \`appFingerprint\` and \`dataSource\`, and skips the restore check" \
      "A missing stored value is no reason to restore." &&
    vt_step_has "Start the data and the app" "asks for fresh data" "\`-ConfirmRestore\`"
}

test_ui_start_saves_its_process_id() {
  section_has "$RX" ui-start.ps1 "saves the process ID in \`state.json\`" &&
    section_has "$DN" api-start.ps1 "saves the process ID in \`state.json\`"
}

test_doctor_roles_follow_the_api_start() {
  vt_step_has "Run Doctor" "with that file and the roles \`api-start.ps1\` started the API with" &&
    vt_step_has "Start the data and the app" "<admin roles>" &&
    has_all "$VT" "Fill \`<admin roles>\` from the API code." &&
    vt_step_has "Set up the data" "Then restart the API with the roles of the \`Roles:\` line when they differ from the roles it runs with."
}

test_update_mode_draft_and_local_only_rules() {
  has_all "$UM" "When the skill does carry the draft line, go to step 8." \
    'Leave out the paths in the `LocalOnlyFiles` list of `common.ps1`' "never the file content"
}

test_code_folders_stay_current_and_dev_rev_has_a_fallback() {
  has_all "$UM" 'Re-check the `Code folders` column of `features/README.md`' "add the column when the file has none" \
    "or a Code folder, and that no longer exists counts as changed" &&
    dev_step_has 9 'With no `Code folders` column' 'say that the map has no `Code folders` column' \
      'ask the engineer which feature to drive' 'write the answer as `Feature:`' \
      'in the same message as the base-branch question'
}

test_a_blocked_helper_ends_the_run() {
  vt_step_has "Start the data and the app" 'When a helper ends with `blocked:`, stop and report `blocked`, except the two named retries: `-ConfirmRestore` and the `ui-start.ps1` fix command.'
}

test_doctor_prints_no_personal_data() {
  section_has "$HP" doctor.ps1 "It prints only that a user is signed in, and the role set. It never prints a name or an email." &&
    section_has "$HP" "Rules for every helper" "Doctor output" &&
    section_has "$VT" Doctor "It never prints a name or an email."
}

test_bacpac_journal_check_maps_paths_to_journal_names() {
  section_has "$DBA" Bacpac "Read the journal's name format from the runner code" \
    "map each branch script path to that name before the compare" "git ls-tree -r --name-only <merge-base sha> <scripts folder>"
}

check "db-start sees the bacpac and writes the data source late" test_db_start_sees_the_bacpac_and_writes_the_data_source_late
check "ui-start saves its process ID" test_ui_start_saves_its_process_id
check "Doctor roles follow the API start" test_doctor_roles_follow_the_api_start
check "update mode: draft and local-only rules" test_update_mode_draft_and_local_only_rules
check "Code folders stay current and dev-rev has a fallback" test_code_folders_stay_current_and_dev_rev_has_a_fallback
check "a blocked helper ends the run" test_a_blocked_helper_ends_the_run
check "Doctor prints no personal data" test_doctor_prints_no_personal_data
check "the bacpac journal check maps paths to journal names" test_bacpac_journal_check_maps_paths_to_journal_names
check "helpers: restore and DbUp know the branch scripts" test_restore_and_dbup_helpers_know_the_branch_scripts
check "helpers: every state key has a writer" test_every_state_key_has_a_writer
check "fresh restore has one rule in Flow and helper" test_fresh_restore_has_one_rule
check "Doctor and copy sentences are pinned whole" test_doctor_and_copy_sentences_are_pinned_whole
check "update mode ignores an unmarked skill until no marked one is left" test_update_mode_ignores_an_unmarked_skill_until_no_marked_one_is_left
check "EVAL.md says the round 1 changes were not run" test_eval_says_the_round_1_changes_were_not_run
check "generated Flow orders start, sign-in, then Doctor" test_generated_flow_orders_start_sign_in_then_doctor
check "generated Flow start sequence has one owner per job" test_generated_flow_start_sequence_has_one_owner_per_job
check "generated Flow: evidence folder, Doctor inputs and setup recipes" test_generated_flow_evidence_folder_and_doctor_inputs
check "generated Flow stops in a session that made the change" test_generated_flow_stops_in_a_session_that_made_the_change
check "Doctor reads the saved user response, never the token" test_doctor_helper_reads_the_saved_user_response
check "one owner per job in the data helpers" test_one_owner_per_job_in_the_data_helpers
check "the generator copies everything under Report and Results" test_generator_copies_everything_under_report_and_results
check "independence rules are pinned as whole sentences" test_independence_rules_are_pinned_as_whole_sentences
check "report wording follows the specification" test_report_wording_follows_the_specification
check "Flow step 1 does not load the stack reference" test_skill_flow_step_1_does_not_load_the_stack_reference
check "an unmarked verify skill is never overwritten" test_unmarked_verify_skill_is_never_overwritten
check "update mode updates the scan lines in the body" test_update_mode_updates_the_scan_lines_in_the_body
check "no fence at column 0 splits a numbered list" test_no_fence_at_column_0_splits_a_numbered_list
check "dev-rev step 9 orders none before Base and never writes an unconfirmed Base" test_dev_rev_step_9_orders_none_and_base_and_never_writes_an_unconfirmed_base
# ---------------------------------------------------------------- README

README="$REPO/README.md"

test_readme_lists_the_skill() {
  local rows
  rows=$(grep -c '^| `agentd-verify-init` |' "$README")
  [ "$rows" -eq 1 ] || return 1
  section_of "$README" "Skills" | grep -q '^| `agentd-verify-init` |'
}
test_readme_has_the_tests_paragraph() {
  has_all "$README" "The \`agentd-verify-init\` skill has" "tests/verify-init/test-skill-structure.sh" \
    "tests/verify-init/EVAL.md"
}
test_readme_flag_paragraph_matches_the_recorded_result() {
  has_all "$README" "Copilot CLI 1.0.102" "2026-10-26" "does not load a skill with the field" \
    "task agent also cannot run a flagged skill" "Claude Code runs a flagged skill" \
    "do not load in Copilot CLI 1.0.102" "use them in Claude Code" "written without the field" || return 1
  ! has_all "$README" "has not been tested"
}
test_readme_planned_wording_is_updated() {
  ! grep -qx '## Planned' "$README" || return 1
  ! grep -qF 'These are designs, not files yet.' "$README" || return 1
  ! grep -qF 'Planned flow:' "$README" || return 1
  grep -qx '## Project contract' "$README" || return 1
  grep -qx '### Project contract' "$README" && return 1
  grep -qF 'dev-rev -> verify -> pr-prep' "$README" || return 1
  has_all "$README" '`verify` means the project skill `/verify-<app>`'
}
test_readme_row_names_the_stacks_and_what_was_run() {
  local row
  row=$(grep '^| `agentd-verify-init` |' "$README")
  [ -n "$row" ] || return 1
  for t in ".NET Core" ".NET Framework" "IIS Express" "LocalDB" "React" "iOS" "PowerShell or bash" "run end to end" \
    "general knowledge"; do
    printf '%s\n' "$row" | grep -qF -- "$t" || return 1
  done
}
test_eval_says_the_later_adapters_were_not_run() {
  section_has "$EVAL" "Not run or not verified" "adapters added after this check" "structure test only" \
    ".NET Framework on IIS Express" "LocalDB" "standalone XCUITest" "bash or zsh" "Windows PowerShell 5.1"
}
check "README lists the skill in the Skills table only" test_readme_lists_the_skill
check "README has the verify-init tests paragraph" test_readme_has_the_tests_paragraph
check "README flag paragraph matches the recorded result" test_readme_flag_paragraph_matches_the_recorded_result
check "README Planned wording is updated" test_readme_planned_wording_is_updated
check "README row names the stacks and what was run" test_readme_row_names_the_stacks_and_what_was_run
check "EVAL.md says the later adapters were not run" test_eval_says_the_later_adapters_were_not_run
echo
echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
