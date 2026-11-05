#!/usr/bin/env bash
# Claude Code: reads personal skills from ~/.claude/skills (not ~/.agents/skills),
# and the global guide from ~/.claude/CLAUDE.md. Sourced by install.sh.
# One run links every Claude Code config folder it is told about (see claude_config_dirs).

# claude_config_dirs: print one config folder per line, without duplicates.
# Folders come from three places, and all of them count:
#   $CLAUDE_CONFIG_DIR           one folder (the folder this shell's Claude Code uses)
#   $CLAUDE_CONFIG_DIRS          folders separated by colons
#   ~/.agents/claude-config-dirs one folder per line; blank lines and lines starting with # are skipped
# With none of the three set, the folder is ~/.claude.
claude_config_dirs() {
  local list="" item line file="$HOME/.agents/claude-config-dirs"
  [ -z "${CLAUDE_CONFIG_DIR:-}" ] || list=$CLAUDE_CONFIG_DIR
  if [ -n "${CLAUDE_CONFIG_DIRS:-}" ]; then
    list=$list$'\n'$(printf '%s' "$CLAUDE_CONFIG_DIRS" | tr ':' '\n')
  fi
  if [ -f "$file" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in "" | "#"*) continue ;; esac
      list=$list$'\n'$line
    done <"$file"
  fi
  [ -n "$list" ] || list=$HOME/.claude
  printf '%s\n' "$list" | while IFS= read -r item; do
    [ -n "$item" ] || continue
    # A quoted ~ reaches us unexpanded. A relative path would depend on where the installer runs.
    case "$item" in
      "~") item=$HOME ;;
      "~/"*) item=$HOME/${item#"~/"} ;;
    esac
    printf '%s\n' "$item"
  done | awk '!seen[$0]++'
}

harness_claude_code() {
  say "claude-code"
  local cdir dir name
  while IFS= read -r cdir; do
    case "$cdir" in
      /*) ;;
      *)
        warn "Claude Code config folder must be an absolute path, got '$cdir'. Skipped."
        continue
        ;;
    esac
    if [ ! -d "$cdir" ]; then
      warn "$cdir not found: install and start Claude Code once, then re-run. Skipped."
      continue
    fi
    for dir in "$REPO_ROOT"/skills/*/; do
      name=$(basename "$dir")
      # Same pattern as today: $cdir/skills/x -> ~/.agents/skills/x -> repo.
      # Checked against the repo, so a dry run does not depend on core having run.
      link_item "$REPO_ROOT/skills/$name" "$cdir/skills/$name" "$HOME/.agents/skills/$name"
    done
    link_item "$REPO_ROOT/global/claude/CLAUDE.md" "$cdir/CLAUDE.md"
  done < <(claude_config_dirs)
  warn_unlisted_claude_dirs
  print_manifest claude-code
}

# warn_unlisted_claude_dirs: a ~/.claude* folder that holds skills or a CLAUDE.md, and is not one of the folders
# above, gets none of our links. Say so. Link nothing: only a folder the engineer listed is touched.
warn_unlisted_claude_dirs() {
  local known="" cdir other real
  while IFS= read -r cdir; do
    known="$known
$(resolve "$cdir")"
  done < <(claude_config_dirs)
  for other in "$HOME"/.claude*/; do
    other=${other%/}
    [ -d "$other" ] || continue
    [ -d "$other/skills" ] || [ -e "$other/CLAUDE.md" ] || continue
    real=$(resolve "$other")
    case "
$known
" in *"
$real
"*) continue ;; esac
    warn "$other holds skills or a CLAUDE.md but is not linked. Add it to ~/.agents/claude-config-dirs to link it."
  done
}
