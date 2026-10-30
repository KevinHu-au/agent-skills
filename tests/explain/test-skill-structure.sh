#!/usr/bin/env bash
# Structure and wording tests for the agentd-explain skill files. Reads the skill files and writes nothing.
# The check that every skill sets disable-model-invocation lives in tests/onboard/test-skill-structure.sh.
# Customer and project names are read from the git-ignored list .git/info/customer-names, never spelt out here.
# Usage: tests/explain/test-skill-structure.sh
set -u

HERE=$(cd "$(dirname "$0")" && pwd -P)
REPO=$(cd "$HERE/../.." && pwd -P)
SKILL_DIR=${SKILL_DIR:-$REPO/skills/agentd-explain}
SKILL="$SKILL_DIR/SKILL.md"
REFS="$SKILL_DIR/references"
TPL="$REFS/answer-template.md"
EVAL="$REPO/tests/explain/EVAL.md"
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

# has_all <file> <text>...: the file contains every text, ignoring case.
has_all() {
  local f=$1 t body
  shift
  [ -s "$f" ] || return 1
  body=$(joined <"$f")
  for t in "$@"; do printf '%s\n' "$body" | grep -qiF -- "$t" || return 1; done
}

# joined: stdin as one line, runs of spaces squeezed, so a phrase that wraps across lines still matches.
joined() { tr '\n' ' ' | tr -s ' '; }

# has_all_cs <file> <text>...: the file contains every text, case-sensitive.
has_all_cs() {
  local f=$1 t
  shift
  [ -s "$f" ] || return 1
  for t in "$@"; do grep -qF -- "$t" "$f" || return 1; done
}

# strip_fences <file>: the file without fenced code blocks, so a "## " line inside one is not read as a heading.
strip_fences() { awk '/^(```|~~~)/ { f = !f; next } !f' "$1"; }

# h2_list <file>: the H2 headings of a markdown file, in order, one per line. Fenced blocks are skipped.
h2_list() { strip_fences "$1" | grep -E '^## ' | sed 's/^## //; s/[[:space:]]*$//'; }

# section_of <file> <heading>: the lines under one H2 heading. Fenced blocks are skipped when finding headings.
section_of() {
  awk -v h="## $2" '
    /^(```|~~~)/ { f = !f }
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

# in_order <file> <text>...: every text appears in the file, each on a later line than the one before.
in_order() {
  local f=$1 t n last=0
  shift
  [ -s "$f" ] || return 1
  for t in "$@"; do
    n=$(grep -niF -- "$t" "$f" | awk -F: -v last="$last" '$1 > last { print $1; exit }')
    [ -n "$n" ] || return 1
    last=$n
  done
}

# section_in_order <file> <heading> <text>...: like in_order, inside one H2 section.
section_in_order() {
  local f=$1 h=$2 body t n last=0
  shift 2
  body=$(section_of "$f" "$h" 2>/dev/null)
  [ -n "$body" ] || return 1
  for t in "$@"; do
    n=$(printf '%s\n' "$body" | grep -niF -- "$t" | awk -F: -v last="$last" '$1 > last { print $1; exit }')
    [ -n "$n" ] || return 1
    last=$n
  done
}

# none_contains <grep option> <text>: no markdown file in the skill folder matches. Fails when there is none.
none_contains() {
  local opt=$1 text=$2 f found=0
  for f in "$SKILL_DIR"/*.md "$REFS"/*.md; do
    [ -f "$f" ] || continue
    found=1
    grep -q "$opt" -- "$text" "$f" && return 1
  done
  [ "$found" -eq 1 ]
}

# ---------------------------------------------------------------- SKILL.md

test_frontmatter_name_matches_folder() {
  [ "$(frontmatter_value name)" = "agentd-explain" ] && [ "$(basename "$SKILL_DIR")" = "agentd-explain" ]
}

test_description_starts_with_use_when_and_covers_the_job() {
  local d t
  d=$(frontmatter_value description)
  case "$d" in "Use when"*) ;; *) return 1 ;; esac
  for t in "business" "code path" "frontend" "database" "Edits no code"; do
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
  [ "$(h2_list "$SKILL" | tr '\n' '|')" = "Prerequisite|Flow|Shapes|Export|Rules|" ]
}

test_flow_has_five_numbered_steps_in_order() {
  local body
  body=$(section_of "$SKILL" Flow 2>/dev/null)
  [ -n "$body" ] || return 1
  [ "$(printf '%s\n' "$body" | grep -E '^[0-9]+\. \*\*' | sed -E 's/^([0-9]+)\. \*\*([^*]*)\*\*.*/\1 \2/' |
    tr '\n' '|')" = '1 Read the question.|2 Read the sources.|3 Find the core code.|4 Trace the flow.|5 Answer.|' ]
}

test_question_kinds_are_listed() {
  has_all_cs "$SKILL" '`figure or term`, `status`, `code`, `domain`' && has_all "$SKILL" "domain overview"
}

test_answers_the_engineer_not_the_customer() {
  has_all "$SKILL" "the engineer" "never the customer"
}

test_vague_question_lists_matches_and_never_guesses() {
  has_all "$SKILL" "list the matches" "Which one?" "never guess" "nobody to answer"
}

test_empty_input_asks_once() {
  has_all "$SKILL" "ask for the question once"
}

test_sources_and_code_wins() {
  has_all "$SKILL" "docs/onboarding/README.md" "glossary" 'the pack'"'"'s `explain/` folder' "user guide" "AGENTS.md" \
    "External systems" "code wins" "conflict:"
}

test_earlier_export_is_checked_against_the_code() {
  has_all "$SKILL" "earlier export" "checked against the code"
}

test_missing_pack_says_so_once() {
  has_all "$SKILL" "say so once"
}

test_read_and_search_only() {
  section_has "$SKILL" Rules "read and search only" "no build" "no tests" "no app" "database" "git log" "git blame" \
    "git rev-parse HEAD"
}

test_why_is_business_reason_not_history() {
  has_all "$SKILL" "business reason" "not who changed it"
}

test_status_lists_conditions_and_stops() {
  has_all "$SKILL" "every code path" "what moves it out" "stop there"
}

test_flow_ends_at_the_data_source() {
  has_all "$SKILL" "stored procedure" "external system" "unknown: ask the"
}

test_other_repository_needs_a_path() {
  has_all "$SKILL" "another repository" "Give its path to follow it" "repository name"
}

test_generic_layer_order() {
  [ -s "$SKILL" ] && joined <"$SKILL" |
    grep -qiE 'screen → client state → client service → API boundary → application logic → data access → storage'
}

test_unknown_stack_uses_the_generic_order() {
  has_all "$SKILL" "no reference" "generic order" 'a layer the stack does not have is `none`'
}

test_inferred_for_indirect_links() {
  has_all "$SKILL" "dependency injection" "event" "queue" "missing hop" "inferred:"
}

test_flow_can_start_at_a_job() {
  has_all "$SKILL" "background job" "entry point"
}

test_always_english() {
  has_all "$SKILL" "always English" "another language"
}

test_brief_first() {
  has_all "$SKILL" "one screen" "follow-up" "Ask next"
}

test_markers_and_no_tiers() {
  has_all "$SKILL" "unknown:" "inferred:" "conflict:" "general knowledge" "path:line" &&
    none_contains -F "Tier:" && none_contains -wi "supported"
}

test_next_names_only_diagnose() {
  local name
  has_all "$SKILL" "/agentd-diagnose" "live problem" || return 1
  for name in $(grep -ohE 'agentd-[a-z-]*' "$SKILL_DIR"/*.md "$REFS"/*.md 2>/dev/null | sort -u); do
    case "$name" in agentd-diagnose | agentd-explain) ;; *) return 1 ;; esac
  done
}

test_no_sub_agents() {
  section_has "$SKILL" Rules "no sub-agents"
}

test_export_rules() {
  section_has "$SKILL" Export "only when the engineer asks" '`explain/<topic>.md` in the pack folder' "one file per topic" \
    "ask before replacing" ".git/info/exclude" "only write"
}

test_export_creates_the_folder() {
  section_has "$SKILL" Export 'If the `explain/` folder is missing, create it' "say so" \
    "With no pack folder, ask the engineer where to write the file" "Never write into the repository without a pack there"
}

test_export_never_edits_exclude() {
  section_has "$SKILL" Export "exact line" "never edits"
}

test_topic_name_is_lowercase_with_hyphens() {
  section_has "$SKILL" Export "lowercase" "hyphens"
}

test_replace_yes_rewrites_no_skips() {
  section_has "$SKILL" Export "rewrites the whole file" "skips the export"
}

test_privacy() {
  has_all "$SKILL" "never its value" "personal data"
}

test_no_customer_names() {
  local f
  [ -s "$SKILL" ] && [ -s "$NAMES" ] || return 1
  for f in "$SKILL_DIR"/*.md "$REFS"/*.md "$REPO/README.md" "$EVAL" "$HERE/test-skill-structure.sh"; do
    [ -f "$f" ] || continue
    # Entries of 3 letters or fewer match whole words only, so a short name inside a longer word is fine.
    # Longer entries match anywhere, so a name inside a CamelCase type name is caught.
    grep -qiwF -f <(awk 'length($0) <= 3' "$NAMES") "$f" && return 1
    grep -qiF -f <(awk 'length($0) > 3' "$NAMES") "$f" && return 1
  done
  return 0
}

test_no_absolute_home_paths() {
  local tmp="/var/""folders"
  none_contains -F "/Users/" && none_contains -F "~/" && none_contains -F "$tmp" || return 1
  [ -f "$EVAL" ] || return 0
  ! grep -qF -e "/Users/" -e "~/" -e "$tmp" "$EVAL"
}

# ---------------------------------------------------------------- rules from the real check and review round 1

test_line_limits() { has_all "$SKILL" "60 lines" "70 lines" "120 characters"; }

test_vague_rule_one_calculation() {
  has_all "$SKILL" "worked out differently" "one calculation" "the screen or tab" "set by several code paths"
}

test_vague_list_is_capped() { has_all "$SKILL" "at most five"; }

test_flow_one_layer_per_line() { section_has "$TPL" Answer "one layer per line" 'at most one `path:line`'; }

test_flow_inferred_hop_line() { section_has "$TPL" Answer "on its own flow line" "inferred:"; }

test_first_trap_says_what_it_is_not() { section_has "$TPL" Answer "says what it is not" "actual spend"; }

test_gaps_not_a_code_review() { section_has "$TPL" Answer "not a code review"; }

test_overview_line_budget() { section_has "$TPL" "Domain overview" "Line budget" "labels and blank lines"; }

test_answer_line_budget() { section_has "$TPL" Answer "Line budget, 60 lines" "name the screen once"; }

# ---------------------------------------------------------------- review round 2

test_vague_rule_says_where_it_shows() { has_all "$SKILL" "says where the figure shows" "how many more"; }

test_length_rules_hold_the_cap() {
  has_all "$SKILL" "Wrap prose at 120 characters" "one Gaps line" "shared prefix" "move the conditions to Ask next"
}

test_limits_apply_to_chat_only() { section_has "$SKILL" Export "chat only" "nobody to answer" "skip the export"; }

test_second_repository_gets_its_stack_reference() { has_all "$SKILL" "second repository" "its reference"; }

test_event_or_queue_needs_its_subscriber() { has_all "$SKILL" "an event or a queue" "subscriber"; }

test_template_inferred_example_and_plain_next() {
  section_has "$TPL" Answer "reflection" "plain line" && strip_fences_off "$TPL" | grep -qF '→ inferred:'
}

test_export_question_in_english() { section_has "$TPL" "Export file" "in English"; }

# strip_fences_off <file>: only the lines inside fenced blocks.
strip_fences_off() { awk '/^(```|~~~)/ { f = !f; next } f' "$1"; }

test_template_example_flow_lines_keep_the_rules() {
  local line n
  [ -s "$TPL" ] || return 1
  while IFS= read -r line; do
    case "$line" in "→ "*) ;; *) continue ;; esac
    [ "$(printf '%s' "$line" | perl -CSD -ne 'print length')" -le 120 ] || return 1
    n=$(printf '%s\n' "$line" | grep -oE ':[0-9]+' | wc -l | tr -d ' ')
    [ "$n" -le 1 ] || return 1
  done <<EOF
$(strip_fences_off "$TPL")
EOF
}

test_skill_files_keep_120_characters() {
  local f
  for f in "$SKILL_DIR"/references/*.md; do
    [ -f "$f" ] || return 1
    perl -CSD -ne 'chomp; exit 1 if length > 120 && !/^\|/' "$f" || return 1
  done
}

test_di_hop_is_plain_when_registration_cited() { has_all "$SKILL" "registration" "single implementation"; }

test_dotnet_server_rendered_views() { has_all "$REFS/dotnet.md" "cshtml" "Razor" "Blazor"; }

test_job_flow_marks_screen_none() { has_all "$SKILL" "none (no screen)" "code that writes it"; }

test_rules_allow_the_export() { section_has "$SKILL" Rules "except the export"; }

test_root_found_with_show_toplevel() { has_all "$SKILL" "git rev-parse --show-toplevel"; }

test_no_phrase_is_copied_from_pstack() {
  local t
  for t in "annotated source code" "working mental model" "abstractions-about-abstractions" \
    "clarify, not decorate" "Where Things Live" "document the null" "careful, cautious, and precise" \
    "Recency bias" "pstack" "poteto"; do
    none_contains -iF "$t" || return 1
  done
}

# ---------------------------------------------------------------- references/answer-template.md

ANSWER_LABELS="Short answer|Domain|Core code|Flow|Traps|Gaps|Ask next|Next"
OVERVIEW_LABELS="Short answer|Entity map|Statuses|When created|Key formulas|Traps|Gaps|Ask next"

# labels_in_order <file> <heading> <labels joined by |>: each bold label appears in the section, in order.
labels_in_order() {
  local f=$1 h=$2 IFS='|' l set=()
  for l in $3; do set+=("**$l**"); done
  section_in_order "$f" "$h" "${set[@]}"
}

test_every_referenced_file_exists() {
  local r
  for r in references/answer-template.md references/dotnet.md references/react.md references/ios.md; do
    has_all_cs "$SKILL" "$r" && [ -s "$SKILL_DIR/$r" ] || return 1
  done
}

# ---------------------------------------------------------------- references/<stack>.md

test_stack_references_have_three_sections() {
  local f
  for f in dotnet react ios; do
    [ -s "$REFS/$f.md" ] && [ "$(h2_list "$REFS/$f.md" | tr '\n' '|')" = "Detect|Layers|Where to look|" ] || return 1
  done
}

test_dotnet_layers_keep_intake_order() {
  section_in_order "$REFS/dotnet.md" Layers "endpoint" "dispatcher" "command or query" "handler" "repository" \
    "stored procedure"
}

test_dotnet_covers_framework_projects() {
  has_all "$REFS/dotnet.md" ".NET Framework" "ApiController" "RouteConfig" "WebApiConfig" "Global.asax" "web.config" "WCF"
}

test_react_layers_in_order() {
  section_in_order "$REFS/react.md" Layers "page" "context" "hook" "service" "generated" &&
    has_all "$REFS/react.md" "NSwag" "OpenAPI" "router"
}

test_ios_layers_in_order() {
  section_in_order "$REFS/ios.md" Layers "View" "view model" "service" "request handler" &&
    has_all "$REFS/ios.md" "SwiftData" "enum" "URLSession"
}

test_each_reference_marks_rows_as_a_first_place_to_look() {
  local f
  for f in dotnet react ios; do has_all "$REFS/$f.md" "place to look first" || return 1; done
}

test_template_h2s_exact() {
  [ -s "$TPL" ] && [ "$(h2_list "$TPL" | tr '\n' '|')" = "Answer|Domain overview|Vague question|Export file|" ]
}

test_answer_labels_in_order() { labels_in_order "$TPL" Answer "$ANSWER_LABELS"; }

test_domain_part_separates_general_knowledge() {
  section_has "$TPL" Answer "general knowledge" "this project"
}

test_core_code_has_model_calculation_schema() {
  section_has "$TPL" Answer "data model" "calculation" "schema" "migration"
}

test_calculation_may_live_in_the_frontend() {
  section_has "$TPL" Answer "computed in the frontend" "data source of its inputs"
}

test_flow_rules() {
  section_has "$TPL" Answer "path:line" "formula" "what moves it out" "unknown:" "plain text arrow" &&
    section_of "$TPL" Answer | grep -qF "Conditions:"
}

test_ask_next_and_next() {
  section_has "$TPL" Answer "two to four" "/agentd-diagnose" "live problem"
}

test_overview_labels_in_order() {
  labels_in_order "$TPL" "Domain overview" "$OVERVIEW_LABELS" &&
    section_has "$TPL" "Domain overview" "no layer-by-layer flow"
}

test_vague_question_shape() {
  section_has "$TPL" "Vague question" "Which one?" "nobody to answer" "stop"
}

test_export_file_header() {
  section_has "$TPL" "Export file" "Question:" "Commit:" "Date:" "git rev-parse HEAD" "follow-ups" "Mermaid"
}

test_one_screen_target() { has_all "$TPL" "one screen"; }

check "frontmatter name matches the folder" test_frontmatter_name_matches_folder
check "description starts with Use when and covers the job" test_description_starts_with_use_when_and_covers_the_job
check "the skill is manual-only" test_skill_is_manual_only
check "SKILL.md is at most 120 lines" test_skill_is_at_most_120_lines
check "H2 sections in order" test_required_h2_sections_in_order
check "Flow has five numbered steps in order" test_flow_has_five_numbered_steps_in_order
check "the four question kinds are listed" test_question_kinds_are_listed
check "it answers the engineer, never the customer" test_answers_the_engineer_not_the_customer
check "a vague question lists the matches and never guesses" test_vague_question_lists_matches_and_never_guesses
check "empty input asks once" test_empty_input_asks_once
check "sources are listed and the code wins" test_sources_and_code_wins
check "an earlier export is checked against the code" test_earlier_export_is_checked_against_the_code
check "a missing pack: say so once" test_missing_pack_says_so_once
check "read and search only" test_read_and_search_only
check "why means the business reason, not history" test_why_is_business_reason_not_history
check "a status lists every path that sets it, then stops" test_status_lists_conditions_and_stops
check "the flow ends at the data source" test_flow_ends_at_the_data_source
check "another repository needs a path" test_other_repository_needs_a_path
check "the generic layer order" test_generic_layer_order
check "a stack with no reference uses the generic order" test_unknown_stack_uses_the_generic_order
check "indirect links are inferred:" test_inferred_for_indirect_links
check "the flow can start at a background job" test_flow_can_start_at_a_job
check "always English" test_always_english
check "brief first, one screen, Ask next" test_brief_first
check "markers, and no evidence tiers" test_markers_and_no_tiers
check "Next names only agentd-diagnose" test_next_names_only_diagnose
check "no sub-agents" test_no_sub_agents
check "export rules" test_export_rules
check "the export creates its folder and says so" test_export_creates_the_folder
check "the export never edits .git/info/exclude" test_export_never_edits_exclude
check "the topic name is lowercase with hyphens" test_topic_name_is_lowercase_with_hyphens
check "replace: yes rewrites, no skips" test_replace_yes_rewrites_no_skips
check "privacy" test_privacy
if [ -s "$NAMES" ]; then
  check "no customer or project names in tracked files" test_no_customer_names
else
  printf '  skip  no customer-names list\n'
fi
check "no absolute home paths" test_no_absolute_home_paths
check "no phrase is copied from the source skills" test_no_phrase_is_copied_from_pstack
check "every referenced file exists" test_every_referenced_file_exists
check "the template has exactly four H2s" test_template_h2s_exact
check "answer labels in order" test_answer_labels_in_order
check "the answer separates general knowledge from this project" test_domain_part_separates_general_knowledge
check "Core code: data model, calculation, schema" test_core_code_has_model_calculation_schema
check "a figure computed in the frontend still traces its inputs" test_calculation_may_live_in_the_frontend
check "flow rules" test_flow_rules
check "Ask next and Next" test_ask_next_and_next
check "overview labels in order, no layer-by-layer flow" test_overview_labels_in_order
check "the vague-question shape" test_vague_question_shape
check "the export file header" test_export_file_header
check "the template keeps to one screen" test_one_screen_target
check "stack references have Detect, Layers, Where to look" test_stack_references_have_three_sections
check ".NET layers keep the intake order" test_dotnet_layers_keep_intake_order
check ".NET covers .NET Framework projects" test_dotnet_covers_framework_projects
check "React layers in order" test_react_layers_in_order
check "iOS layers in order" test_ios_layers_in_order
check "each reference row is a place to look first" test_each_reference_marks_rows_as_a_first_place_to_look
check "line limits: 60, 70, 120 characters" test_line_limits
check "vague only when worked out differently" test_vague_rule_one_calculation
check "the vague list is capped" test_vague_list_is_capped
check "flow: one layer per line, one path:line" test_flow_one_layer_per_line
check "flow: an untraced hop is inferred: on its own line" test_flow_inferred_hop_line
check "the first trap says what a figure is not" test_first_trap_says_what_it_is_not
check "Gaps are not a code review" test_gaps_not_a_code_review
check "the overview line budget" test_overview_line_budget
check "the answer line budget" test_answer_line_budget
check "vague rule: says where the figure shows; how many more" test_vague_rule_says_where_it_shows
check "length rules that hold the cap" test_length_rules_hold_the_cap
check "line limits are for chat; headless skips the export" test_limits_apply_to_chat_only
check "a second repository gets its stack reference" test_second_repository_gets_its_stack_reference
check "an event or a queue needs its subscriber cited" test_event_or_queue_needs_its_subscriber
check "template: inferred example line, plain Next line" test_template_inferred_example_and_plain_next
check "the export question is in English" test_export_question_in_english
check "the template's example flow keeps its own rules" test_template_example_flow_lines_keep_the_rules
check "reference prose lines are at most 120 characters" test_skill_files_keep_120_characters
check "a DI hop is plain when its registration is cited" test_di_hop_is_plain_when_registration_cited
check ".NET covers server-rendered views" test_dotnet_server_rendered_views
check "a job-started flow marks the screen none" test_job_flow_marks_screen_none
check "Rules allow the export" test_rules_allow_the_export
check "the root is found with show-toplevel" test_root_found_with_show_toplevel

echo
echo "passed=$PASS failed=$FAIL"
[ "$FAIL" -eq 0 ]
