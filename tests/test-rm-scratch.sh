#!/usr/bin/env bash
# Tests for global/bin/rm-scratch: it removes a scratch path under a system temporary folder, and refuses everything else.
# Decoys live in a throwaway folder under /tmp and in one under $HOME. Risky targets (the temporary folders themselves)
# are only tried with --dry-run, so a bug in the tool cannot remove them. A trap cleans up with plain rm -r.
# Usage: tests/test-rm-scratch.sh
set -u

HERE=$(cd "$(dirname "$0")" && pwd -P)
TOOL="$HERE/../global/bin/rm-scratch"
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

# refuses <message> <args...>: the tool exits 1 and its error output contains <message>.
refuses() {
  local msg=$1 out rc
  shift
  out=$("$TOOL" "$@" 2>&1)
  rc=$?
  [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -qF -- "$msg"
}

SCRATCH=$(mktemp -d /tmp/rm-scratch-test.XXXXXX)
OUTSIDE=$(mktemp -d "$HOME/rm-scratch-test.XXXXXX")
cleanup() { rm -r "$SCRATCH" "$OUTSIDE" 2>/dev/null; }
trap cleanup EXIT

# Removal
mkdir -p "$SCRATCH/dir/sub" "$SCRATCH/dir2/sub"
touch "$SCRATCH/dir/sub/file" "$SCRATCH/lone"
check "removes a folder with contents" "$TOOL" "$SCRATCH/dir"
check "the folder is gone" [ ! -e "$SCRATCH/dir" ]
check "removes a single file" "$TOOL" "$SCRATCH/lone"
check "the file is gone" [ ! -e "$SCRATCH/lone" ]
check "removes a folder given with a trailing slash" "$TOOL" "$SCRATCH/dir2/"
check "the trailing-slash folder is gone" [ ! -e "$SCRATCH/dir2" ]
mkdir -p "$SCRATCH/cwd-test" && touch "$SCRATCH/cwd-test/f"
check "removes a relative path" bash -c 'cd "$1" && "$2" cwd-test' _ "$SCRATCH" "$TOOL"
check "the relative-path folder is gone" [ ! -e "$SCRATCH/cwd-test" ]
mkdir -p "$SCRATCH/dry" && touch "$SCRATCH/dry/f"
check "--dry-run names the path" bash -c 'out=$("$1" --dry-run "$2"); printf "%s" "$out" | grep -qF "would remove"' _ "$TOOL" "$SCRATCH/dry"
check "--dry-run removes nothing" [ -e "$SCRATCH/dry/f" ]

# Location
mkdir -p "$OUTSIDE/keep"
touch "$OUTSIDE/keep-file"
check "refuses a folder outside the temporary folders" refuses "not under a system temporary folder" "$OUTSIDE/keep"
check "refuses a file outside the temporary folders" refuses "not under a system temporary folder" "$OUTSIDE/keep-file"
check "the outside folder and file are still there" [ -d "$OUTSIDE/keep" ] && [ -e "$OUTSIDE/keep-file" ]
check "a poisoned TMPDIR does not widen the roots" env TMPDIR="$OUTSIDE" bash -c '! "$1" "$2/keep" 2>/dev/null' _ "$TOOL" "$OUTSIDE"
check "the poisoned-TMPDIR target is still there" [ -d "$OUTSIDE/keep" ]
check "refuses TMPDIR=. with a relative path" bash -c 'cd "$1" && ! TMPDIR=. "$2" keep 2>/dev/null' _ "$OUTSIDE" "$TOOL"
check "refuses /tmp itself (dry run)" refuses "refused" --dry-run /tmp
check "refuses /private/tmp itself (dry run)" refuses "refused" --dry-run /private/tmp
check "refuses /var/tmp itself (dry run)" refuses "refused" --dry-run /var/tmp
if user_tmp=$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null) && [ -n "$user_tmp" ]; then
  check "refuses the per-user temporary folder (dry run)" refuses "system temporary folder" --dry-run "${user_tmp%/}"
  check "refuses a parent of the per-user temporary folder (dry run)" refuses "contains, a system temporary folder" --dry-run "$(dirname "${user_tmp%/}")"
fi

# Path shape
mkdir -p "$SCRATCH/real/child" "$SCRATCH/a"
ln -s "$SCRATCH/real" "$SCRATCH/link"
check "refuses a symlink" refuses "is a symlink" "$SCRATCH/link"
check "refuses a symlink with a trailing slash" refuses "is a symlink" "$SCRATCH/link/"
check "the symlink target is still there" [ -d "$SCRATCH/real/child" ]
ln -s "$OUTSIDE/keep" "$SCRATCH/outlink"
touch "$OUTSIDE/keep/inner"
check "refuses a path through a symlinked parent that leads outside" refuses "not under a system temporary folder" "$SCRATCH/outlink/inner"
check "the file behind the symlinked parent is still there" [ -e "$OUTSIDE/keep/inner" ]
check "refuses a path with .." refuses "contains '..'" "$SCRATCH/a/../real"
check "refuses a path that climbs out with .." refuses "contains '..'" "$SCRATCH/a/../../etc"
check "refuses a path ending in '.'" refuses "ends in '.'" "$SCRATCH/real/."
check "the '.' target is still there" [ -d "$SCRATCH/real/child" ]
mkdir -p "$SCRATCH/nl"
NLDIR="$SCRATCH/nl/n"$'\n'
mkdir "$NLDIR" "$SCRATCH/nl/n" && touch "$SCRATCH/nl/n/file"
check "refuses a path with a newline" refuses "newline" "$NLDIR"
check "the sibling without the newline is still there" [ -e "$SCRATCH/nl/n/file" ]
check "refuses an option" refuses "looks like an option" -rf
check "refuses no arguments" refuses "usage"
check "refuses two paths" refuses "usage" "$SCRATCH/a" "$SCRATCH/real"
check "refuses an empty path" refuses "empty path" ""
check "refuses a path that does not exist" refuses "does not exist" "$SCRATCH/missing"

# Contents
if command -v python3 >/dev/null 2>&1; then
  mkdir -p "$SCRATCH/sock"
  python3 -c 'import socket,sys; s=socket.socket(socket.AF_UNIX); s.bind(sys.argv[1])' "$SCRATCH/sock/s"
  check "refuses a folder that holds a socket" refuses "socket or is not owned" "$SCRATCH/sock"
  check "the socket folder is still there" [ -S "$SCRATCH/sock/s" ]
fi

check "the tool is executable" [ -x "$TOOL" ]

printf '\npassed=%d failed=%d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
