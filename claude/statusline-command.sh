#!/usr/bin/env bash
# scripted/written by Robert Bopko (github.com/zeroznet) with Boba Bott (Claude Haiku 4.5)
# Claude Code status line — model, effort, context/rate bars, working directory, git state

input=$(cat)

# Colors
R="\033[0m" B="\033[1m" D="\033[2m"
C="\033[36m" Y="\033[33m" G="\033[32m" X="\033[31m" Z="\033[34m"
BM="\033[95m" BG="\033[92m" O="\033[38;5;214m"

# Extract fields
model=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
effort=$(echo "$input" | jq -r '.effort.level // empty')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty | strflocaltime("%H:%M")')
week_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# Progress bar
bar() {
  local pct=$1 label=$2 fill empty bar="" col="$G"
  fill=$(( pct * 8 / 100 ))
  [ "$fill" -gt 8 ] && fill=8
  empty=$(( 8 - fill ))
  for ((i=0; i<fill; i++)); do bar+="▰"; done
  for ((i=0; i<empty; i++)); do bar+="▱"; done
  if [ "$pct" -ge 80 ]; then col="$X"; elif [ "$pct" -ge 50 ]; then col="$Y"; fi
  printf '%s' "${D}${label}${R} ${col}${bar}${R} ${D}${pct}%${R}"
}

# Line 1: model, effort, bars
line1="${B}${BM}${model}${R}"
[ -n "$effort" ] && line1+="  ${C}${effort}${R}"
[ -n "$used_pct" ] && line1+="  $(bar "$(printf "%.0f" "$used_pct")" ctx)"
[ -n "$five_pct" ] && line1+="  $(bar "$(printf "%.0f" "$five_pct")" 5h)"
[ -n "$five_pct" ] && [ -n "$five_reset" ] && line1+=" ${D}↻${five_reset}${R}"
[ -n "$week_pct" ] && line1+="  $(bar "$(printf "%.0f" "$week_pct")" 7d)"

# Line 2: user@host ~ path
user=$(whoami) host=$(hostname -s) home="$HOME"
display_cwd="${cwd/#$home/\~}"
line2="${B}${O}${user}@${host}${R} · ${B}${Z}${display_cwd}${R}"

# Line 3: git state
git_q() { git --no-optional-locks -C "$cwd" "$@" 2>/dev/null; }
git_line=""
if [ -n "$cwd" ] && git_q rev-parse --is-inside-work-tree >/dev/null; then
  branch=$(git_q symbolic-ref --short HEAD || git_q rev-parse --short HEAD)
  read -r added removed < <(git_q diff HEAD --numstat | awk '{a+=$1; r+=$2} END {print a+0, r+0}')
  untracked=$(git_q ls-files --others --exclude-standard | wc -l | tr -d ' ')

  git_line="${B}${Z}${branch}${R}"
  [ "$added" -gt 0 ] && git_line+="  ${BG}+${added}${R}"
  [ "$removed" -gt 0 ] && git_line+="  ${X}-${removed}${R}"
  [ "$untracked" -gt 0 ] && git_line+="  ${D}${C}?${untracked}${R}"
  [ "$added" -eq 0 ] && [ "$removed" -eq 0 ] && [ "$untracked" -eq 0 ] && git_line+="  ${D}${G}✓${R}"
fi

# Output
printf "%b\n" "$line1"
printf "%b\n" "$line2"
[ -n "$git_line" ] && printf "%b\n" "$git_line"
exit 0
