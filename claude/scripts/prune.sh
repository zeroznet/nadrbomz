#!/usr/bin/env sh
# scripted/written by Robert Bopko (github.com/zeroznet) with Boba Bott (Claude Fable 5)
# Clear Claude Code ephemera: chat transcripts, prompt history, plan/session caches,
# shell snapshots, telemetry, and daemon/agent-view state. Preserves credentials, settings,
# plugins, skills, commands, agents, hooks, statusline, backups, downloads, and per-project memory/.
set -eu

log()  { printf '%s\n' "$*"; }
warn() { printf 'warn: %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: prune.sh [--apply|-a] [--help|-h]

Default is dry-run: lists targets and sizes without deleting.
--apply    actually delete.
--apply also runs "claude daemon stop --any" first so the supervisor cannot hold
stale agent-view state in memory.

Targets:
  ~/.claude/file-history/
  ~/.claude/session-env/
  ~/.claude/sessions/
  ~/.claude/plans/
  ~/.claude/paste-cache/
  ~/.claude/shell-snapshots/
  ~/.claude/cache/
  ~/.claude/telemetry/
  ~/.claude/tasks/
  ~/.claude/daemon/
  ~/.claude/jobs/
  ~/.claude/history.jsonl
  ~/.claude/stats-cache.json
  ~/.claude/projects/*/* (preserves */memory/)
  /tmp/claude-* and ~/tmp/claude-*
  /tmp/cc-daemon-*

Preserved (never touched):
  ~/.claude/.credentials.json
  ~/.claude/settings.json, settings.local.json
  ~/.claude/statusline-command.sh
  ~/.claude/keybindings.json
  ~/.claude/plugins/
  ~/.claude/skills/
  ~/.claude/commands/
  ~/.claude/agents/
  ~/.claude/hooks/
  ~/.claude/scripts/
  ~/.claude/backups/
  ~/.claude/downloads/
  ~/.claude/projects/*/memory/
EOF
}

apply=0
case "${1-}" in
  --apply|-a) apply=1 ;;
  --help|-h)  usage; exit 0 ;;
  '') ;;
  *) die "Unknown arg: $1 (try --help)" ;;
esac

C="$HOME/.claude"
[ -d "$C" ] || die "Missing required directory: $C"

simple_targets="
$C/file-history
$C/session-env
$C/sessions
$C/plans
$C/paste-cache
$C/shell-snapshots
$C/cache
$C/telemetry
$C/tasks
$C/daemon
$C/jobs
$C/history.jsonl
$C/stats-cache.json
"

# Detect the active Claude session by inspecting where this script's stdout
# is redirected. The harness pipes stdout to a file inside the session's
# tasks/ directory, e.g.:
#   $HOME/tmp/claude-<uid>/<project>/<session-uuid>/tasks/<id>.output
# We extract <session-uuid>'s directory so the cleanup can preserve it.
active_session=""
out_link=$(readlink /proc/$$/fd/1 2>/dev/null || readlink /proc/self/fd/1 2>/dev/null || true)
case "$out_link" in
  "$HOME/tmp/claude-"*"/tasks/"*) active_session="${out_link%/tasks/*}" ;;
  "/tmp/claude-"*"/tasks/"*)      active_session="${out_link%/tasks/*}" ;;
esac

# Delete every entry inside $tmp except $active, its descendants, and the
# ancestor directories leading to it. Args are built into $@ (no eval, no
# globbing of the literal "*" we hand to find).
clean_tmp_preserving_active() {
  tmp="$1"; active="$2"
  set -- -mindepth 1 -depth "!" "(" -path "$active" -o -path "$active/*"
  p="${active%/*}"
  while [ "$p" != "${tmp%/}" ] && [ -n "$p" ] && [ "$p" != "/" ]; do
    set -- "$@" -o -path "$p"
    p="${p%/*}"
  done
  set -- "$@" ")" -exec rm -rf -- "{}" "+"
  find "$tmp" "$@" 2>/dev/null || true
}

# Size of a tmp tree minus the active session subtree (for dry-run reporting).
tmp_size_excluding_active() {
  tmp="$1"; active="$2"
  if [ -n "$active" ] && [ "${active#$tmp/}" != "$active" ]; then
    find "$tmp" -mindepth 1 \
      ! -path "$active" ! -path "$active/*" \
      -print0 2>/dev/null \
      | du -shc --files0-from=- 2>/dev/null | tail -1 | awk '{print $1}'
  else
    du -sh "$tmp" 2>/dev/null | awk '{print $1}'
  fi
}

# Same, in KB (for the apply-mode cleared total).
tmp_kb_excluding_active() {
  tmp="$1"; active="$2"
  if [ -n "$active" ] && [ "${active#$tmp/}" != "$active" ]; then
    k=$(find "$tmp" -mindepth 1 \
      ! -path "$active" ! -path "$active/*" \
      -print0 2>/dev/null \
      | du -skc --files0-from=- 2>/dev/null | tail -1 | awk '{print $1}')
  else
    k=$(du -sk "$tmp" 2>/dev/null | awk '{print $1}')
  fi
  echo "${k:-0}"
}

path_kb() {
  [ -e "$1" ] || { echo 0; return 0; }
  k=$(du -sk "$1" 2>/dev/null | awk '{print $1}')
  echo "${k:-0}"
}

human_kb() {
  if [ "$1" -ge 1048576 ]; then awk -v k="$1" 'BEGIN{printf "%.1f GB", k/1048576}'
  elif [ "$1" -ge 1024 ]; then awk -v k="$1" 'BEGIN{printf "%.1f MB", k/1024}'
  else printf '%s KB' "$1"; fi
}

print_size() {
  path="$1"
  [ -e "$path" ] || return 0
  sz=$(du -sh "$path" 2>/dev/null | awk '{print $1}')
  printf '  %-8s  %s\n' "$sz" "$path"
}

proj_root="$C/projects"

if [ "$apply" -eq 0 ]; then
  log "Targets:"
  for p in $simple_targets; do print_size "$p"; done

  # /tmp/claude-* and ~/tmp/claude-* (skipping the active session subtree)
  for glob in "/tmp/claude-"* "$HOME/tmp/claude-"*; do
    [ -e "$glob" ] || continue
    sz=$(tmp_size_excluding_active "$glob" "$active_session")
    if [ -n "$active_session" ] && [ "${active_session#$glob/}" != "$active_session" ]; then
      printf '  %-8s  %s (active session preserved)\n' "${sz:-0}" "$glob"
    else
      printf '  %-8s  %s\n' "${sz:-0}" "$glob"
    fi
  done

  for glob in "/tmp/cc-daemon-"*; do
    [ -e "$glob" ] || continue
    print_size "$glob"
  done

  # projects: count non-memory entries per project
  if [ -d "$proj_root" ]; then
    for proj in "$proj_root"/*/; do
      [ -d "$proj" ] || continue
      count=$(find "$proj" -mindepth 1 -maxdepth 1 ! -name memory 2>/dev/null | wc -l | tr -d ' ')
      if [ "$count" -gt 0 ]; then
        sz=$(find "$proj" -mindepth 1 ! -path "$proj/memory" ! -path "$proj/memory/*" -print0 2>/dev/null \
             | du -shc --files0-from=- 2>/dev/null | tail -1 | awk '{print $1}')
        printf '  %-8s  %s (%s entries, memory/ preserved)\n' "${sz:-?}" "$proj" "$count"
      fi
    done
  fi

  log ""
  if command -v claude >/dev/null 2>&1; then
    log '  note: --apply will run "claude daemon stop --any" first (flushes agent-view state)'
  fi
  log "Dry-run. Re-run with --apply to delete."
  exit 0
fi

if command -v claude >/dev/null 2>&1; then
  claude daemon stop --any >/dev/null 2>&1 || warn "claude daemon stop failed"
else
  warn "claude CLI not found; skipping daemon stop (agent view may show stale entries until restart)"
fi

total_kb=0

for p in $simple_targets; do
  [ -e "$p" ] || continue
  total_kb=$((total_kb + $(path_kb "$p")))
  rm -rf -- "$p"
done

for glob in "/tmp/claude-"* "$HOME/tmp/claude-"*; do
  [ -e "$glob" ] || continue
  if [ -n "$active_session" ] && [ "${active_session#$glob/}" != "$active_session" ]; then
    total_kb=$((total_kb + $(tmp_kb_excluding_active "$glob" "$active_session")))
    clean_tmp_preserving_active "$glob" "$active_session"
  else
    total_kb=$((total_kb + $(path_kb "$glob")))
    rm -rf -- "$glob"
  fi
done

for glob in "/tmp/cc-daemon-"*; do
  [ -e "$glob" ] || continue
  total_kb=$((total_kb + $(path_kb "$glob")))
  rm -rf -- "$glob"
done

if [ -d "$proj_root" ]; then
  proj_kb=$(find "$proj_root" -mindepth 2 \
    ! -path '*/memory' ! -path '*/memory/*' -print0 2>/dev/null \
    | du -skc --files0-from=- 2>/dev/null | tail -1 | awk '{print $1}')
  total_kb=$((total_kb + ${proj_kb:-0}))
  find "$proj_root" -mindepth 2 \
    ! -path '*/memory' \
    ! -path '*/memory/*' \
    -delete 2>/dev/null || true
fi

if [ -t 1 ]; then
  printf '\033[1;32mcleared %s\033[0m\n' "$(human_kb "$total_kb")"
else
  printf 'cleared %s\n' "$(human_kb "$total_kb")"
fi

exit 0
