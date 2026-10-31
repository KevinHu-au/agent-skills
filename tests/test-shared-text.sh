#!/usr/bin/env bash
# Checks that text shared between skills stays word for word the same, so one copy cannot drift from the others.
# Today it checks the "Find the project facts" paragraph: how a skill finds the onboarding pack and the project
# contract. Line breaks and indents may differ between skills; the words may not. Reads files and writes nothing.
# Usage: tests/test-shared-text.sh
set -u

HERE=$(cd "$(dirname "$0")" && pwd -P)
SKILLS="$HERE/../skills"
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

# The skills that read the onboarding pack or the project contract.
READERS="agentd-diagnose agentd-blast-radius agentd-pr-review agentd-data-fix agentd-intake agentd-explain agentd-verify-init agentd-dev-rev"

# paragraph <file>: the "Find the project facts" paragraph on one line, with any list mark and indent removed. It ends
# at a blank line, the next list item or a heading.
paragraph() {
  awk '
    !on && index($0, "**Find the project facts.**") { on = 1; l = $0; sub(/^- /, "", l); out = l; next }
    on && ($0 ~ /^[[:space:]]*$/ || $0 ~ /^- / || $0 ~ /^#/) { exit }
    on { l = $0; sub(/^[[:space:]]+/, "", l); out = out " " l }
    END { if (on) print out }
  ' "$1" | tr -s ' '
}

REF=$(paragraph "$SKILLS/agentd-diagnose/SKILL.md")
check "agentd-diagnose has the paragraph" [ -n "$REF" ]

for s in $READERS; do
  f="$SKILLS/$s/SKILL.md"
  check "$s has the paragraph once" [ "$(grep -c 'Find the project facts' "$f")" -eq 1 ]
  check "$s has the same words as agentd-diagnose" [ "$(paragraph "$f")" = "$REF" ]
done

# The paragraph names the tool by its home path, never by a ~ path, and the tool exists.
check "the paragraph runs onboarding-pack find and set" bash -c \
  'printf "%s" "$1" | grep -qF "\"\$HOME/.agents/bin/onboarding-pack\" find" &&
   printf "%s" "$1" | grep -qF "\"\$HOME/.agents/bin/onboarding-pack\" set <folder>"' _ "$REF"
check "the tool is in global/bin" [ -x "$HERE/../global/bin/onboarding-pack" ]
check "the paragraph treats an unsourced access rule as no access" bash -c \
  'printf "%s" "$1" | grep -qF "as no access"' _ "$REF"

# The .NET notes of blast-radius, diagnose and onboard tell .NET Framework from .NET Core with the same bullets.
# kind_bullets <file>: the lines of the "Which kind of project" part of a dotnet.md that are the shared rule.
kind_bullets() {
  awk '/^## Which kind of project/ { on = 1; next } /^## / { on = 0 } on && (/^- / || /^Read the target/)' "$1"
}

KREF=$(kind_bullets "$SKILLS/agentd-blast-radius/references/dotnet.md")
# blast-radius holds the reference copy. Change the bullets in all three files together. The sentence after the list
# differs on purpose in each file.
check "blast-radius dotnet.md has the kind bullets (the reference copy)" [ "$(printf '%s\n' "$KREF" | grep -c '^- ')" -ge 5 ]
for s in agentd-diagnose agentd-onboard; do
  check "$s dotnet.md has the same kind bullets as blast-radius" \
    [ "$(kind_bullets "$SKILLS/$s/references/dotnet.md")" = "$KREF" ]
done

# The stack signals are one sentence group in every skill that has stack references, so a stack is detected the same way
# everywhere. The reference files point to it instead of repeating their own rule.
STACK_SIGNALS='A .NET project has `*.sln`, `*.csproj` or `*.vbproj` files, or is a Web Site project (a `web.config` with `*.aspx` or `*.cshtml` pages and no project file). An iOS (SwiftUI) project has a `*.xcodeproj` or `*.xcworkspace`, or a `Package.swift` whose sources import SwiftUI. A React web project has a `package.json`, in the repository or in any workspace folder, that lists `react-dom` under `dependencies`, or under `devDependencies` when the same file lists a bundler or dev server (`vite`, `webpack`, `next`, `react-scripts` or `parcel`) and has no `main`, `module` or `exports` field. A file that also lists `react-native`, a peer-only entry, or a dev entry that fails those conditions is a mobile app or a library, not a web project. A project, or a part of one, that matches none of these is a stack with no reference.'
STACK_SKILLS="agentd-diagnose agentd-blast-radius agentd-explain agentd-onboard agentd-verify-init"
for s in $STACK_SKILLS; do
  check "$s has the stack signals word for word" bash -c \
    'tr "\n" " " <"$1" | tr -s " " | grep -qF -- "$2"' _ "$SKILLS/$s/SKILL.md" "$STACK_SIGNALS"
done
for f in blast-radius diagnose explain onboard verify-init; do
  check "agentd-$f react.md points to the stack signals, not its own rule" bash -c \
    '! grep -q "under \`dependencies\`" "$1" && tr "\n" " " <"$1" | grep -qi "stack signals"' _ "$SKILLS/agentd-$f/references/react.md"
done
for f in explain onboard verify-init; do
  check "agentd-$f dotnet.md points to the stack signals" bash -c \
    'tr "\n" " " <"$1" | grep -qi "stack signals"' _ "$SKILLS/agentd-$f/references/dotnet.md"
done
for f in explain onboard verify-init; do
  check "agentd-$f ios.md points to the stack signals" bash -c \
    'tr "\n" " " <"$1" | grep -qi "stack signals"' _ "$SKILLS/agentd-$f/references/ios.md"
done
check "agentd-onboard SKILL.md says what to do for a stack with no reference" bash -c \
  'tr "\n" " " <"$1" | tr -s " " | grep -qF "For a stack with no reference, the explorers work from the code alone, mark every fact \`inferred:\`"' _ "$SKILLS/agentd-onboard/SKILL.md"
for f in react ios dotnet; do
  check "agentd-explain $f.md says the stack signals decide when to load it" bash -c \
    'tr "\n" " " <"$1" | tr -s " " | grep -qF "The stack signals in \`SKILL.md\` decide when to load this file"' _ "$SKILLS/agentd-explain/references/$f.md"
done
check "README names the supported stacks and the fallback" bash -c \
  'b=$(tr "\n" " " <"$1" | tr -s " "); for t in "not for every stack" ".NET (Framework and Core)" "SQL Server" "React web" "SwiftUI" "generic.md" "inferred:" "agentd-onboard" "a part of a project"; do printf "%s" "$b" | grep -qF -- "$t" || exit 1; done; ! printf "%s" "$b" | grep -qF "They work for any client and any stack"' _ "$HERE/../README.md"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
