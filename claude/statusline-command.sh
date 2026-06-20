#!/usr/bin/env bash
# scripted/written by Robert Bopko (github.com/zeroznet) with Boba Bott (Claude Haiku 4.5)
# Claude Code status line — model, effort, context/rate bars, working directory, git state

input=$(cat)

# Colors
R="\033[0m" B="\033[1m" D="\033[2m"
M="\033[35m" C="\033[36m" Y="\033[33m" G="\033[32m" X="\033[31m" Z="\033[34m"
BM="\033[95m" BG="\033[92m"

# Extract fields
model=$(echo "$input" | jq -r '.model.display_name // "Unknown"')
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
effort=$(jq -r '.effortLevel // empty' /home/zero/.claude/settings.json 2>/dev/null)
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')

# Progress bar
bar() {
  local pct=$1 label=$2 w=8 fill=$(( $1 * 8 / 100 )) empty=$(( 8 - fill ))
  [ $fill -gt 8 ] && fill=8 && empty=0
  local bar="" col="$G"
  for ((i=0; i<fill; i++)); do bar+="▰"; done
  for ((i=0; i<empty; i++)); do bar+="▱"; done
  [ $pct -ge 80 ] && col="$X" || [ $pct -ge 50 ] && col="$Y"
  printf "${D}${label}${R} ${col}${bar}${R} ${D}${pct}%${R}"
}

# Line 1: model, effort, bars
line1="${B}${BM}${model}${R}  ${C}${effort}${R}"
[ -n "$used_pct" ] && line1+="  $(bar $(printf "%.0f" "$used_pct") ctx)"
[ -n "$five_pct" ] && line1+="  $(bar $(printf "%.0f" "$five_pct") rate)"

# Line 2: user@host ~ path
user=$(whoami) host=$(hostname -s) home="$HOME"
display_cwd="${cwd/#$home/\~}"
line2="${B}${M}${user}@${host}${R} · ${B}${Z}${display_cwd}${R}"

# Line 3: git state
git_line=""
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --is-inside-work-tree --no-optional-locks >/dev/null 2>&1; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  added=$(git -C "$cwd" diff --numstat --cached --no-optional-locks 2>/dev/null | awk '{s+=$1} END {print s+0}')
  removed=$(git -C "$cwd" diff --numstat --cached --no-optional-locks 2>/dev/null | awk '{s+=$2} END {print s+0}')
  added=$(( added + $(git -C "$cwd" diff --numstat --no-optional-locks 2>/dev/null | awk '{s+=$1} END {print s+0}') ))
  removed=$(( removed + $(git -C "$cwd" diff --numstat --no-optional-locks 2>/dev/null | awk '{s+=$2} END {print s+0}') ))
  untracked=$(git -C "$cwd" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')

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
