#!/usr/bin/env bash
# Shared helpers for install.sh and harness/*.sh. Sourced, never run directly.
# Needs bash 3.2 (macOS default): no associative arrays, no mapfile.
#
# Safety rules:
#   - Nothing is changed unless MODE=apply.
#   - Nothing is ever deleted. An existing file that is not ours is only moved
#     aside to a backup folder, and only when ADOPT=1.

MODE=plan      # plan | apply
ADOPT=0        # 1 = move conflicting items to the backup folder, then link
# Fixed once at load. Computing it lazily inside $(...) would lose the value
# and could split one run's backups across two folders.
BACKUP_DIR="$HOME/.agent-skills-backup/$(date +%Y%m%d-%H%M%S)"

N_OK=0
N_LINK=0
N_ADOPT=0
N_CONFLICT=0
N_WARN=0
N_FAIL=0

say() { printf '%s\n' "$*"; }

is_apply() { [ "$MODE" = apply ]; }

warn() {
  say "  WARN      $*"
  N_WARN=$((N_WARN + 1))
}

resolve() {
  realpath "$1" 2>/dev/null || true
}

backup_dir() { printf '%s' "$BACKUP_DIR"; }

# aside_path DST: where move_aside puts DST, keeping its path relative to $HOME.
aside_path() { printf '%s/%s' "$(backup_dir)" "${1#"$HOME"/}"; }

# Move $1 into the backup folder, keeping its path relative to $HOME.
move_aside() {
  local dst=$1 dest
  dest=$(aside_path "$dst")
  mkdir -p "$(dirname "$dest")"
  mv "$dst" "$dest"
}

describe_existing() {
  local dst=$1 src=$2
  if [ -L "$dst" ]; then
    printf 'symlink to %s' "$(readlink "$dst")"
  elif [ -d "$dst" ] && diff -rq "$dst" "$src" >/dev/null 2>&1; then
    printf 'identical copy'
  elif [ -f "$dst" ] && cmp -s "$dst" "$src"; then
    printf 'identical copy'
  else
    printf 'differs from the repo'
  fi
}

# Shared handling when $dst exists but is not what we want.
# $3 = what to say about the planned replacement.
# Returns 0 when the caller may now create the replacement, 1 when it must not.
handle_conflict() {
  local dst=$1 src=$2 action=$3 kind
  kind=$(describe_existing "$dst" "$src")
  if [ "$ADOPT" = 1 ]; then
    if is_apply; then
      # A failed move leaves the old file in place. The caller must not replace it then, or it would be lost.
      if ! move_aside "$dst"; then
        N_FAIL=$((N_FAIL + 1))
        warn "could not move $dst to $(backup_dir). It was not replaced. Check that it is intact."
        return 1
      fi
      N_ADOPT=$((N_ADOPT + 1))
      say "  adopted   $dst ($kind; old copy moved to $(backup_dir))"
      return 0
    fi
    N_ADOPT=$((N_ADOPT + 1))
    say "  would adopt $dst ($kind; old copy would move to a backup folder)"
    return 1
  fi
  N_CONFLICT=$((N_CONFLICT + 1))
  say "  CONFLICT  $dst ($kind). Re-run with --adopt to move it aside and $action."
  return 1
}

# link_item SRC DST [TARGET]: make DST a symlink that resolves to SRC.
# TARGET is what the new link points at (default SRC). Use it to keep the
# ~/.claude -> ~/.agents -> repo chain while still checking against the repo.
link_item() {
  local src=$1 dst=$2 target=${3:-$1} adopted=0
  if [ ! -e "$src" ]; then
    warn "source missing, skipped: $src"
    return 0
  fi
  if [ "$target" != "$src" ] && { [ -L "$target" ] || [ -e "$target" ]; } \
    && [ "$(resolve "$target")" != "$(resolve "$src")" ]; then
    warn "skipped $dst: $target does not point at the repo yet. Resolve that conflict first."
    return 0
  fi
  if [ -L "$dst" ] || [ -e "$dst" ]; then
    if [ "$(resolve "$dst")" = "$(resolve "$src")" ]; then
      say "  ok        $dst"
      N_OK=$((N_OK + 1))
      return 0
    fi
    handle_conflict "$dst" "$src" "link it" || return 0
    adopted=1
  fi
  if is_apply; then
    mkdir -p "$(dirname "$dst")"
    # Git Bash without native symlinks makes a copy, and a copy goes stale after git pull. So check for a real link.
    if ln -s "$target" "$dst" && [ -L "$dst" ]; then
      N_LINK=$((N_LINK + 1))
      say "  linked    $dst -> $target"
    else
      N_FAIL=$((N_FAIL + 1))
      # --adopt moved the old item aside. Put it back, unless ln left something at DST.
      if [ "$adopted" = 1 ] && [ ! -e "$dst" ] && [ ! -L "$dst" ] && mv "$(aside_path "$dst")" "$dst"; then
        warn "could not create a symlink at $dst. The old item is back in place."
      else
        warn "could not create a symlink at $dst"
      fi
    fi
  else
    N_LINK=$((N_LINK + 1))
    say "  link      $dst -> $target"
  fi
}

# write_marker DST: create the empty file DST when it is missing. Used for the opt-in always-on guard.
write_marker() {
  local dst=$1
  if [ -e "$dst" ]; then
    say "  ok        $dst"
    N_OK=$((N_OK + 1))
    return 0
  fi
  if is_apply; then
    if { mkdir -p "$(dirname "$dst")" && : >"$dst"; } 2>/dev/null && [ -f "$dst" ]; then
      N_LINK=$((N_LINK + 1))
      say "  wrote     $dst"
    else
      N_FAIL=$((N_FAIL + 1))
      warn "could not write $dst"
    fi
  else
    N_LINK=$((N_LINK + 1))
    say "  write     $dst (empty marker)"
  fi
}

# links_work: 0 when ln -s makes a real symlink here, 1 when it does not (Git Bash on Windows needs Developer Mode
# for that), 2 when no temp folder could be made or written for the check.
links_work() {
  local d rc=1
  d=$(mktemp -d) || return 2
  { : >"$d/f"; } 2>/dev/null || {
    rm -rf "$d"
    return 2
  }
  ln -s "$d/f" "$d/l" 2>/dev/null && [ -L "$d/l" ] && rc=0
  rm -rf "$d"
  return $rc
}

# render_item TEMPLATE DST: write TEMPLATE to DST with @HOME@ replaced by $HOME.
# Used for files that need an absolute path, so they cannot be symlinks.
render_item() {
  local tmpl=$1 dst=$2 tmp esc new exists=0
  # Escape for JSON (\ and "), then for the sed replacement (\ & and the # delimiter).
  esc=$(printf '%s' "$HOME" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | sed -e 's/[\\&#]/\\&/g')
  # The hook command quotes the path in double quotes, which cannot hold " $ ` or \ safely.
  case "$HOME" in
    *[\"\$\`\\]*)
      warn "HOME holds a \", \$, \` or \\, which the hook command cannot quote. Not written: $dst"
      return 0
      ;;
  esac
  if [ ! -f "$tmpl" ]; then
    warn "source missing, skipped: $tmpl"
    return 0
  fi
  # Render and stage the new file before any conflict handling, so --adopt does not move a file aside that it then
  # cannot replace.
  tmp=$(mktemp) || {
    N_FAIL=$((N_FAIL + 1))
    warn "could not make a temp file to render $dst. Check that TMPDIR (or /tmp) is writable."
    return 0
  }
  if ! sed "s#@HOME@#$esc#g" "$tmpl" >"$tmp"; then
    rm -f "$tmp"
    N_FAIL=$((N_FAIL + 1))
    warn "could not render $dst from $tmpl"
    return 0
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    exists=1
    if [ ! -L "$dst" ] && cmp -s "$tmp" "$dst"; then
      say "  ok        $dst"
      N_OK=$((N_OK + 1))
      rm -f "$tmp"
      return 0
    fi
  fi
  # Nothing is replaced in a dry run, or when DST is a conflict without --adopt: report it and stop.
  if ! is_apply || { [ "$exists" = 1 ] && [ "$ADOPT" != 1 ]; }; then
    if [ "$exists" = 1 ]; then
      handle_conflict "$dst" "$tmp" "write it"
    else
      N_LINK=$((N_LINK + 1))
      say "  write     $dst (rendered from $(basename "$tmpl"))"
    fi
    rm -f "$tmp"
    return 0
  fi
  # Copy the new file next to DST first. A copy that fails, or stops partway, never touches DST.
  new="$dst.agentd-new.$$"
  if ! { mkdir -p "$(dirname "$dst")" && cp "$tmp" "$new"; }; then
    rm -f "$tmp" "$new"
    N_FAIL=$((N_FAIL + 1))
    warn "could not write $dst"
    return 0
  fi
  rm -f "$tmp"
  if [ "$exists" = 1 ] && ! handle_conflict "$dst" "$new" "write it"; then
    rm -f "$new"
    return 0
  fi
  # Same folder, so mv is a rename. If it fails after --adopt moved DST aside, put the old file back.
  if mv -f "$new" "$dst"; then
    N_LINK=$((N_LINK + 1))
    say "  wrote     $dst"
    return 0
  fi
  rm -f "$new"
  N_FAIL=$((N_FAIL + 1))
  if [ "$exists" = 1 ] && mv "$(aside_path "$dst")" "$dst"; then
    warn "could not write $dst. The old file is back in place."
  else
    warn "could not write $dst"
  fi
}

version_ge() {
  [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n 1)" = "$2" ]
}

# print_manifest HARNESS: remind the user of plugins; the script never installs them.
print_manifest() {
  local harness=$1 h kind name detail found=0
  if [ ! -f "$REPO_ROOT/setup.manifest" ]; then
    warn "setup.manifest not found: no plugin reminders"
    return 0
  fi
  # The "|| [ -n ... ]" keeps a last line that has no trailing newline.
  while read -r h kind name detail || [ -n "$h" ]; do
    case "$h" in ''|'#'*) continue ;; esac
    [ "$h" = "$harness" ] || continue
    if [ "$found" = 0 ]; then
      say "  manual    install these yourself (plugin commands change between versions):"
      found=1
    fi
    say "              - $kind $name ($detail)"
  done <"$REPO_ROOT/setup.manifest"
}
