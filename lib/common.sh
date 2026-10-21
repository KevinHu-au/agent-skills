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

# Move $1 into the backup folder, keeping its path relative to $HOME.
move_aside() {
  local dst=$1 rel dest
  rel=${dst#"$HOME"/}
  dest="$(backup_dir)/$rel"
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
    N_ADOPT=$((N_ADOPT + 1))
    if is_apply; then
      move_aside "$dst"
      say "  adopted   $dst ($kind; old copy moved to $(backup_dir))"
      return 0
    fi
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
  local src=$1 dst=$2 target=${3:-$1}
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
  fi
  N_LINK=$((N_LINK + 1))
  if is_apply; then
    mkdir -p "$(dirname "$dst")"
    ln -s "$target" "$dst"
    say "  linked    $dst -> $target"
  else
    say "  link      $dst -> $target"
  fi
}

# render_item TEMPLATE DST: write TEMPLATE to DST with @HOME@ replaced by $HOME.
# Used for files that need an absolute path, so they cannot be symlinks.
render_item() {
  local tmpl=$1 dst=$2 tmp esc
  # Escape for JSON (\ and "), then for the sed replacement (\ & and the # delimiter).
  esc=$(printf '%s' "$HOME" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | sed -e 's/[\\&#]/\\&/g')
  case "$HOME" in
    *[[:space:]]*) warn "HOME contains whitespace: Copilot may split the hook command on it" ;;
  esac
  tmp=$(mktemp)
  sed "s#@HOME@#$esc#g" "$tmpl" >"$tmp"
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    if [ ! -L "$dst" ] && cmp -s "$tmp" "$dst"; then
      say "  ok        $dst"
      N_OK=$((N_OK + 1))
      rm -f "$tmp"
      return 0
    fi
    if ! handle_conflict "$dst" "$tmp" "write it"; then
      rm -f "$tmp"
      return 0
    fi
  fi
  N_LINK=$((N_LINK + 1))
  if is_apply; then
    mkdir -p "$(dirname "$dst")"
    cp "$tmp" "$dst"
    say "  wrote     $dst"
  else
    say "  write     $dst (rendered from $(basename "$tmpl"))"
  fi
  rm -f "$tmp"
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
