#!/usr/bin/env bash
# Tests for global/bin/onboarding-pack: the registry key, find and set.
# Everything happens in one throwaway folder under /tmp, with HOME pointed at a folder inside it, so the real
# ~/.agents/onboarding-packs.tsv is never read or written. A trap cleans up with plain rm -r.
# Usage: tests/test-onboarding-pack.sh
set -u

HERE=$(cd "$(dirname "$0")" && pwd -P)
TOOL="$HERE/../global/bin/onboarding-pack"
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

T=$(mktemp -d /tmp/onboarding-pack-test.XXXXXX)
T=$(cd -P "$T" && pwd -P)
cleanup() { rm -r "$T" 2>/dev/null; }
trap cleanup EXIT

export HOME="$T/home"
mkdir -p "$HOME"
REG="$HOME/.agents/onboarding-packs.tsv"

tool() { "$TOOL" "$@"; }
# key_is <repo> <expected key>
key_is() { [ "$(tool key "$1")" = "$2" ]; }
# exits_with <code> <args...>
exits_with() {
  local want=$1
  shift
  tool "$@" >/dev/null 2>&1
  [ $? -eq "$want" ]
}

mkrepo() {
  mkdir -p "$1"
  git -C "$1" init -q
  git -C "$1" -c user.email=t@example.invalid -c user.name=t commit -q --allow-empty -m init
}

# Keys
mkrepo "$T/https"
git -C "$T/https" remote add origin "https://Some.User@Dev.Azure.com/Org/Proj/_git/Api.git"
mkrepo "$T/https2"
git -C "$T/https2" remote add origin "https://dev.azure.com/org/proj/_git/api/"
mkrepo "$T/ssh"
git -C "$T/ssh" remote add origin "git@github.com:Org/Repo.git"
mkrepo "$T/https3"
git -C "$T/https3" remote add origin "https://user:secret@github.com/org/repo"
mkrepo "$T/noremote"

check "an HTTPS URL loses the scheme, the user, the case and .git" key_is "$T/https" "dev.azure.com/org/proj/_git/api"
check "the same repository without a user or with a trailing slash gets the same key" key_is "$T/https2" "dev.azure.com/org/proj/_git/api"
check "an SSH URL and an HTTPS URL of one repository share a key" key_is "$T/ssh" "github.com/org/repo"
check "a password in the URL is dropped" key_is "$T/https3" "github.com/org/repo"
check "a password never shows in the key" bash -c '! "$1" key "$2" | grep -q secret' _ "$TOOL" "$T/https3"
check "a repository with no origin uses its root path" key_is "$T/noremote" "$T/noremote"
mkdir -p "$T/noremote/sub"
check "a subfolder gets the key of its repository" key_is "$T/noremote/sub" "$T/noremote"
git -C "$T/noremote" worktree add -q --detach "$T/wt" 2>/dev/null
check "a linked worktree gets the key of its main checkout" key_is "$T/wt" "$T/noremote"
mkdir -p "$T/plain"
check "a folder that is not a repository is refused with exit 4" exits_with 4 key "$T/plain"
check "find in a folder that is not a repository exits 4, not 1" exits_with 4 find "$T/plain"
mkrepo "$T/port"
git -C "$T/port" remote add origin "ssh://git@GitHub.com:22/Org/Repo.git"
check "an ssh:// URL with a port gets the same key as the scp form" key_is "$T/port" "github.com/org/repo"
mkrepo "$T/port2"
git -C "$T/port2" remote add origin "https://git.example.com:8443/team/app"
check "an HTTPS URL with a port loses the port" key_is "$T/port2" "git.example.com/team/app"
h=$(printf '%s' "github.com/org/repo" | git hash-object --stdin | cut -c1-8)
check "suggest makes one folder name from the key and its hash" bash -c '[ "$("$1" suggest "$2")" = "$3" ]' _ "$TOOL" \
  "$T/ssh" "$HOME/.agents/projects/github.com-org-repo-$h/onboarding"
mkrepo "$T/alike1"
git -C "$T/alike1" remote add origin "https://github.com/org/my-repo"
mkrepo "$T/alike2"
git -C "$T/alike2" remote add origin "https://github.com/org-my/repo"
check "two keys that read alike get two suggested folders" bash -c \
  '[ "$("$1" suggest "$2")" != "$("$1" suggest "$3")" ]' _ "$TOOL" "$T/alike1" "$T/alike2"
mkrepo "$T/pw1"
git -C "$T/pw1" remote add origin "https://user:p@ss@github.com/org/repo"
check "a password with an @ is dropped from the key" key_is "$T/pw1" "github.com/org/repo"
mkrepo "$T/pw2"
git -C "$T/pw2" remote add origin "https://user:pa/ss@github.com/org/repo"
check "a password with a / is dropped from the key" key_is "$T/pw2" "github.com/org/repo"
check "no part of such a password shows in the key or the suggestion" bash -c \
  '! { "$1" key "$2"; "$1" key "$3"; "$1" suggest "$2"; "$1" suggest "$3"; } | grep -qE "p@|ss@|pa/|pass|user"' _ "$TOOL" \
  "$T/pw1" "$T/pw2"
mkrepo "$T/other/api"
git -C "$T/other/api" remote add origin "https://dev.azure.com/other/proj/_git/api"
check "two repositories in folders of the same name get different suggestions" bash -c \
  '[ "$("$1" suggest "$2")" != "$("$1" suggest "$3")" ]' _ "$TOOL" "$T/https" "$T/other/api"

# find before anything is recorded
check "find with no registry file exits 1" exits_with 1 find "$T/ssh"

# set and find
mkdir -p "$T/packs/repo" "$T/packs/repo2" "$T/packs/api"
check "set records a folder outside the repository" tool set "$T/packs/repo" "$T/ssh"
check "the registry file exists" [ -f "$REG" ]
check "the registry starts with a comment line" bash -c 'head -1 "$1" | grep -q "^# onboarding-pack registry"' _ "$REG"
check "find prints the recorded folder" bash -c '[ "$("$1" find "$2")" = "$3" ]' _ "$TOOL" "$T/ssh" "$T/packs/repo"
check "a second clone of the same repository finds the same pack" bash -c '[ "$("$1" find "$2")" = "$3" ]' _ "$TOOL" "$T/https3" "$T/packs/repo"
check "set for another repository adds a line" tool set "$T/packs/api" "$T/https"
check "set again for the first repository replaces its line" tool set "$T/packs/repo2" "$T/ssh"
check "find prints the new folder" bash -c '[ "$("$1" find "$2")" = "$3" ]' _ "$TOOL" "$T/ssh" "$T/packs/repo2"
check "the registry holds one line per repository" bash -c '[ "$(grep -vc "^#" "$1")" -eq 2 ]' _ "$REG"
check "the other repository keeps its line" bash -c '[ "$("$1" find "$2")" = "$3" ]' _ "$TOOL" "$T/https" "$T/packs/api"
check "find for a repository with no line exits 1" exits_with 1 find "$T/noremote"
check "no temporary copy is left next to the registry" bash -c '! ls -a "$1" | grep -q "^\.onboarding-packs\."' _ "$HOME/.agents"

# Refusals
check "set refuses a relative path" exits_with 4 set "packs/repo" "$T/ssh"
check "set refuses a folder that does not exist" exits_with 4 set "$T/packs/missing" "$T/ssh"
mkdir -p "$T/ssh/docs/onboarding"
check "set refuses a folder inside the repository" exits_with 4 set "$T/ssh/docs/onboarding" "$T/ssh"
# On a file system that ignores letter case (the macOS default), the same folder in other letters is still inside.
if [ "$T/SSH" -ef "$T/ssh" ]; then
  check "set refuses a folder inside the repository written in other letter case" exits_with 4 \
    set "$T/SSH/docs/onboarding" "$T/ssh"
else
  printf '  skip  the letter-case check: this file system tells letter case apart\n'
fi
mkdir -p "$T/noremote/inside"
check "set from a worktree refuses a folder inside the main checkout" exits_with 4 set "$T/noremote/inside" "$T/wt"
mkdir -p "$T/wt/notes"
check "set from the main checkout refuses a folder inside a linked worktree" exits_with 4 set "$T/wt/notes" "$T/noremote"
mkdir -p "$T/packs/tab	name"
check "set refuses a folder name with a tab" exits_with 4 set "$T/packs/tab	name" "$T/https"
check "set refuses a folder already recorded for another repository" exits_with 4 set "$T/packs/api" "$T/ssh"
check "a refused set leaves the registry unchanged" bash -c '[ "$(grep -vc "^#" "$1")" -eq 2 ]' _ "$REG"
check "the first repository keeps its folder after the refused set" bash -c '[ "$("$1" find "$2")" = "$3" ]' _ "$TOOL" "$T/ssh" "$T/packs/repo2"

# A key with a backslash (a repository with no origin, in a folder whose name has one)
mkrepo "$T/back\\tslash"
mkdir -p "$T/packs/back"
check "set records a key with a backslash" tool set "$T/packs/back" "$T/back\\tslash"
check "find finds a key with a backslash" bash -c '[ "$("$1" find "$2")" = "$3" ]' _ "$TOOL" "$T/back\\tslash" "$T/packs/back"
tool set "$T/packs/back" "$T/back\\tslash" >/dev/null 2>&1
check "a second set for a key with a backslash replaces its line" bash -c \
  '[ "$(grep -cF "back\\tslash" "$1")" -eq 1 ]' _ "$REG"
check "no arguments is bad usage" exits_with 2
check "an unknown command is bad usage" exits_with 2 list

# A recorded folder that has gone
mkdir -p "$T/packs/gone"
tool set "$T/packs/gone" "$T/noremote" >/dev/null 2>&1
rmdir "$T/packs/gone"
check "find exits 3 when the recorded folder is missing" exits_with 3 find "$T/noremote"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
