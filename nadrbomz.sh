#!/usr/bin/env sh
# scripted/written by Robert Bopko (github.com/zeroznet) with Boba Bott (Claude Opus 4.8)

set -eu
set -o pipefail

BASE_URL="https://raw.githubusercontent.com/zeroznet/nadrbomz/main"

ZSHRC_URL="${BASE_URL}/zshrc_zero"
BASHRC_URL="${BASE_URL}/bashrc_zero"
SHELL_ALIASES_URL="${BASE_URL}/shell_aliases_zero"
SCREENRC_URL="${BASE_URL}/screenrc_zero"
TMUXRC_URL="${BASE_URL}/tmuxrc_zero"
NVIM_INIT_URL="${BASE_URL}/init.vim_zero"
FASTFETCH_CONFIG_URL="${BASE_URL}/fastfetch_zero"
SSH_CONFIG_URL="${BASE_URL}/ssh_config_zero"
ZSHENV_URL="${BASE_URL}/zshenv_zero"
SSH_KEY_ENSURE_URL="${BASE_URL}/ssh-key-ensure_zero"
WT_CONNECT_URL="${BASE_URL}/wt-connect_zero"

NADRBOMZ_CLONE_URL="${NADRBOMZ_CLONE_URL:-https://github.com/zeroznet/nadrbomz.git}"
CLAUDE_DIR="${HOME}/.claude"
DEV_DIR="${HOME}/dev"

OHMYZSH_DIR="${HOME}/.oh-my-zsh"
ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-${OHMYZSH_DIR}/custom}"
AUTOSUGGEST_DIR="${ZSH_CUSTOM_DIR}/plugins/zsh-autosuggestions"
AUTOSUGGEST_REPO="https://github.com/zsh-users/zsh-autosuggestions.git"

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != "dumb" ]; then
  ESC="$(printf '\033')"
else
  ESC=""
fi

sgr() {
  if [ -n "${ESC}" ]; then
    printf '%s[%sm' "${ESC}" "$1"
  fi
}

pause() {
  if [ -n "${ESC}" ]; then
    sleep "$1" 2>/dev/null || true
  fi
}

SECTION_TOTAL=6
SECTION_INDEX=0
OK_COUNT=0
SKIP_COUNT=0
WARN_COUNT=0

# A step_begin placeholder may still sit on the line; wipe it before printing.
clear_line() {
  if [ -n "${ESC}" ]; then
    printf '\r%s[K' "${ESC}"
  fi
}

tilde() {
  case "$1" in
    "${HOME}"/*) printf '~%s' "${1#"${HOME}"}" ;;
    *)           printf '%s' "$1" ;;
  esac
}

print_status() {
  clear_line
  printf '   %s[%s]%s  %-22s %s%s%s\n' "$(sgr "1;38;5;$2")" "$1" "$(sgr 0)" "$3" "$(sgr '38;5;244')" "$4" "$(sgr 0)"
}

step_begin() {
  if [ -n "${ESC}" ]; then
    printf '   %s[....]%s  %s' "$(sgr '38;5;240')" "$(sgr 0)" "$1"
  fi
}

report_ok() {
  OK_COUNT=$((OK_COUNT + 1))
  print_status ' OK ' 46 "$1" "$2"
}

report_skip() {
  SKIP_COUNT=$((SKIP_COUNT + 1))
  print_status 'SKIP' 244 "$1" "$2"
}

print_section() {
  SECTION_INDEX=$((SECTION_INDEX + 1))
  spaced="$(printf '%s' "$1" | sed 's/./& /g; s/ $//')"
  printf '\n  %s▓▒░%s %02d/%02d %s░▒▓%s  %s%s%s\n' \
    "$(sgr '38;5;57')" "$(sgr '1;38;5;213')" "${SECTION_INDEX}" "${SECTION_TOTAL}" "$(sgr '38;5;57')" "$(sgr 0)" \
    "$(sgr '1;38;5;51')" "${spaced}" "$(sgr 0)"
}

warn() {
  WARN_COUNT=$((WARN_COUNT + 1))
  clear_line
  printf '   %s[WARN]%s  %s\n' "$(sgr '1;38;5;214')" "$(sgr 0)" "$*" >&2
}

die() {
  clear_line
  printf '   %s[FAIL]%s  %s\n' "$(sgr '1;38;5;196')" "$(sgr 0)" "$*" >&2
  exit 1
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

detect_os() {
  uname_s="$(uname -s 2>/dev/null || echo unknown)"
  case "${uname_s}" in
    Linux)
      if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        printf '%s\n' "${ID:-linux}"
      else
        printf 'linux\n'
      fi
      ;;
    FreeBSD) printf 'freebsd\n' ;;
    Darwin)  printf 'macos\n' ;;
    *)       printf '%s\n' "${uname_s}" ;;
  esac
}

check_prereqs() {
  missing=""
  for tool in git zsh curl; do
    has_cmd "${tool}" || missing="${missing} ${tool}"
  done

  [ -z "${missing}" ] && return 0

  os="$(detect_os)"
  printf 'ERROR: Missing required commands:%s\n' "${missing}" >&2
  printf '\n' >&2
  case "${os}" in
    debian|ubuntu)
      printf 'Install with:\n  sudo apt update && sudo apt install -y%s\n' "${missing}" >&2
      ;;
    freebsd)
      printf 'Install with:\n  sudo pkg install -y%s\n' "${missing}" >&2
      ;;
    fedora|rhel|centos|rocky|almalinux)
      printf 'Install with:\n  sudo dnf install -y%s\n' "${missing}" >&2
      ;;
    arch)
      printf 'Install with:\n  sudo pacman -S --needed%s\n' "${missing}" >&2
      ;;
    alpine)
      printf 'Install with:\n  sudo apk add%s\n' "${missing}" >&2
      ;;
    macos)
      printf 'Install with:\n  brew install%s\n' "${missing}" >&2
      ;;
    *)
      printf 'Install the listed packages with your system package manager.\n' >&2
      ;;
  esac
  exit 1
}

download_file() {
  url="$1"
  out="$2"
  curl -fsSL "$url" -o "$out"
}

install_ohmyzsh() {
  install_url="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"

  if [ -d "${OHMYZSH_DIR}" ]; then
    report_skip "oh-my-zsh" "already installed"
    return 0
  fi

  step_begin "oh-my-zsh"
  # The installer reports its own failures on stdout, so keep its output and
  # replay it only when it fails.
  if ! omz_output="$(CHSH=no RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL "${install_url}")" "" --unattended 2>&1)"; then
    clear_line
    printf '%s\n' "${omz_output}" >&2
    die "Oh My Zsh install failed"
  fi
  report_ok "oh-my-zsh" "installed"
}

sync_git_repo() {
  repo_url="$1"
  repo_dir="$2"
  repo_name="$3"

  step_begin "${repo_name}"
  if [ -d "${repo_dir}/.git" ]; then
    rev_before="$(git -C "${repo_dir}" rev-parse --short HEAD)"
    git -C "${repo_dir}" pull -q --ff-only
    rev_after="$(git -C "${repo_dir}" rev-parse --short HEAD)"
    if [ "${rev_before}" = "${rev_after}" ]; then
      report_skip "${repo_name}" "up to date @ ${rev_after}"
    else
      report_ok "${repo_name}" "updated ${rev_before} -> ${rev_after}"
    fi
  else
    rm -rf "${repo_dir}"
    git clone -q --depth 1 "${repo_url}" "${repo_dir}"
    report_ok "${repo_name}" "cloned @ $(git -C "${repo_dir}" rev-parse --short HEAD)"
  fi
}

deploy_file() {
  url="$1"
  target="$2"
  label="$3"

  tmp_file="$(mktemp "${TMPDIR:-/tmp}/dotfile.XXXXXX")"
  trap 'rm -f "${tmp_file}"' EXIT HUP INT TERM

  step_begin "${label}"
  download_file "${url}" "${tmp_file}"

  target_dir="$(dirname "${target}")"
  mkdir -p "${target_dir}"

  backup_note=""
  if [ -f "${target}" ] || [ -L "${target}" ]; then
    backup="${target}.bak"
    cp -p "${target}" "${backup}"
    backup_note=" +bak"
  fi

  mv "${tmp_file}" "${target}"
  trap - EXIT HUP INT TERM

  report_ok "${label}" "$(tilde "${target}")${backup_note}"
}

deploy_dotfiles() {
  deploy_file "${SHELL_ALIASES_URL}" "${HOME}/.shell_aliases" ".shell_aliases"
  deploy_file "${ZSHRC_URL}" "${HOME}/.zshrc" ".zshrc"
  deploy_file "${ZSHENV_URL}" "${HOME}/.zshenv" ".zshenv"
  deploy_file "${BASHRC_URL}" "${HOME}/.bashrc" ".bashrc"
  deploy_file "${SCREENRC_URL}" "${HOME}/.screenrc" ".screenrc"
  deploy_file "${TMUXRC_URL}" "${HOME}/.tmux.conf" ".tmux.conf"
  deploy_file "${NVIM_INIT_URL}" "${HOME}/.config/nvim/init.vim" "init.vim"
  deploy_file "${FASTFETCH_CONFIG_URL}" "${HOME}/.config/fastfetch/config.jsonc" "fastfetch config"
  deploy_file "${SSH_CONFIG_URL}" "${HOME}/.ssh/config" "ssh config"
}

is_wsl() {
  # Kernel string, not WSL_DISTRO_NAME: sshd does not pass that variable, and
  # the deploy decision is about the machine, not the session.
  grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null
}

deploy_wsl_scripts() {
  if ! is_wsl; then
    report_skip "ssh-key-ensure" "not WSL"
    report_skip "wt-connect" "not WSL"
    return 0
  fi

  deploy_file "${SSH_KEY_ENSURE_URL}" "${HOME}/.local/bin/ssh-key-ensure" "ssh-key-ensure"
  deploy_file "${WT_CONNECT_URL}" "${HOME}/.local/bin/wt-connect" "wt-connect"
  chmod +x "${HOME}/.local/bin/ssh-key-ensure" "${HOME}/.local/bin/wt-connect"
}

fix_terminfo_setaf() {
  # FreeBSD base ships only termcap (/etc/termcap), whose xterm-256color uses an
  # unconditional setaf (\E[38;5;%p1%dm) that encodes the 8 ANSI colours as
  # indexed. Bold + an indexed colour can't be brightened, so Windows Terminal
  # renders it as heavier font weight. Compile a corrected entry (conditional
  # setaf: legacy \E[3Nm for colours 0-7) into ~/.terminfo, which tinfo reads
  # before /etc/termcap. No-op where setaf is already correct (e.g. Linux).
  if ! has_cmd infocmp || ! has_cmd tic; then
    report_skip "xterm-256color" "infocmp/tic missing"
    return 0
  fi

  if ! infocmp xterm-256color 2>/dev/null | grep -q 'setaf=\\E\[38;5;%p1%dm'; then
    report_skip "xterm-256color" "terminfo already correct"
    return 0
  fi

  step_begin "xterm-256color"
  ti_src="$(mktemp "${TMPDIR:-/tmp}/terminfo.XXXXXX")"
  trap 'rm -f "${ti_src}"' EXIT HUP INT TERM
  infocmp -x xterm-256color | sed \
    -e 's#setaf=\\E\[38;5;%p1%dm#setaf=\\E[%?%p1%{8}%<%t3%p1%d%e%p1%{16}%<%t9%p1%{8}%-%d%e38;5;%p1%d%;m#' \
    -e 's#setab=\\E\[48;5;%p1%dm#setab=\\E[%?%p1%{8}%<%t4%p1%d%e%p1%{16}%<%t10%p1%{8}%-%d%e48;5;%p1%d%;m#' \
    > "${ti_src}"
  tic -x "${ti_src}"
  rm -f "${ti_src}"
  trap - EXIT HUP INT TERM
  report_ok "xterm-256color" "conditional setaf patched into ~/.terminfo"
}

print_rule() {
  printf '  %s%s%s\n' "$(sgr "38;5;$1")" "$2" "$(sgr 0)"
}

print_info_row() {
  printf '     %s%s%s%s%s%s\n' "$(sgr '38;5;141')" "$1" "$(sgr 0)" "$(sgr '1;38;5;231')" "$2" "$(sgr 0)"
}

# The cracktro is a 74x24 cell canvas rendered by awk, the one scripting tool
# every base system ships (mawk and busybox included). Rows 0-17 hold the
# copper bars, logo, credits and release info; rows 18-23 are the scroller
# band, which only exists while animating. The final frame is the same in
# every mode.
INTRO_WIDTH=74
INTRO_HEIGHT=24

intro_awk_program() {
  cat <<'AWK'
function code(p) {
  if (esc == "") return ""
  return (p == "") ? esc "[0m" : esc "[0;" p "m"
}

function wrap(i, n) {
  i = int(i) % n
  return (i < 0) ? i + n : i
}

function wipe(   y, x) {
  for (y = 0; y < H; y++)
    for (x = 0; x < W; x++) {
      C[y, x] = " "
      S[y, x] = ""
    }
}

function cell(y, x, g, p) {
  if (x < 0 || x >= W) return
  C[y, x] = g
  S[y, x] = p
}

function text(y, x, s, p,   i) {
  for (i = 1; i <= length(s); i++) cell(y, x + i - 1, substr(s, i, 1), p)
}

function row(y,   x, out, cur) {
  out = ""
  cur = ""
  for (x = 0; x < W; x++) {
    if (S[y, x] != cur) {
      cur = S[y, x]
      out = out code(cur)
    }
    out = out C[y, x]
  }
  if (cur != "") out = out code("")
  if (esc == "") sub(/ +$/, "", out)
  return out
}

function stars_init(   i) {
  for (i = 1; i <= NSTARS; i++) {
    SX[i] = rand() * W
    SY[i] = 8 + int(rand() * (H - 8))
    SL[i] = 1 + int(rand() * 3)
  }
}

function stars_move(   i) {
  for (i = 1; i <= NSTARS; i++) {
    SX[i] -= SPEED[SL[i]]
    if (SX[i] < 0) {
      SX[i] += W
      SY[i] = 8 + int(rand() * (H - 8))
    }
  }
}

function stars_draw(   i) {
  for (i = 1; i <= NSTARS; i++) cell(SY[i], int(SX[i]), STAR[SL[i]], STARC[SL[i]])
}

function bars_draw(t, done,   half, mid, x) {
  half = done ? 35 : t * 2.5
  mid = LX + 35
  for (x = LX; x < LX + 70; x++) {
    if (x < mid - half || x >= mid + half) continue
    cell(0, x, "▄", "38;5;" COPPER[wrap(x - t, NCOPPER) + 1])
    cell(7, x, "▀", "38;5;" COPPER[wrap(x + t, NCOPPER) + 1])
  }
}

# Each logo cell hides until its reveal frame, flickers as noise for the ten
# frames before it, flashes white for two, then joins the chrome gradient.
function logo_draw(t, done,   y, x, ch, r, p, d, shine) {
  shine = wrap(t * 3, 240) - 40
  for (y = 0; y < 6; y++)
    for (x = 0; x < 70; x++) {
      ch = substr(LOGO[y], x + 1, 1)
      if (ch == " ") continue
      if (!done) {
        r = REVEAL[y, x]
        if (t < r - 10) continue
        if (t < r) {
          cell(1 + y, LX + x, NOISE[1 + int(rand() * 3)], "38;5;" (236 + int(rand() * 8)))
          continue
        }
        if (t < r + 2) {
          cell(1 + y, LX + x, GLYPH[ch], "1;38;5;231")
          continue
        }
      }
      if (ch == "#") {
        p = "1;38;5;" CHROME[wrap(x * 0.5 + y - t * 0.6, NCHROME) + 1]
        d = x + 2 * y - shine
        if (!done && d >= 0 && d < 3) p = "1;38;5;231"
      } else {
        p = "38;5;60"
      }
      cell(1 + y, LX + x, GLYPH[ch], p)
    }
}

function credits_draw(t, done,   s, n, i, c, p, x0) {
  s = "-=[ z e r o z n e t   p r e s e n t s ]=-"
  x0 = LX + int((70 - length(s)) / 2)
  n = done ? length(s) : int((t - 40) * 2)
  if (n > length(s)) n = length(s)
  for (i = 1; i <= n; i++) {
    c = substr(s, i, 1)
    if (i == n && n < length(s)) p = "1;38;5;231"
    else if (c ~ /[a-z]/) p = "1;38;5;51"
    else p = "38;5;240"
    cell(8, x0 + i - 1, c, p)
  }
}

function info_draw(t, done,   i, start, n, v, p) {
  if (!done && t < 55) return
  p = (!done && t < 59) ? "1;38;5;231" : "1;38;5;213"
  cell(10, 5, "░", p); cell(10, 6, "▒", p); cell(10, 7, "▓", p); cell(10, 8, "█", p)
  text(10, 9, " RELEASE INFO ", p)
  cell(10, 23, "█", p); cell(10, 24, "▓", p); cell(10, 25, "▒", p); cell(10, 26, "░", p)
  for (i = 0; i < NINFO; i++) {
    start = 62 + i * 5
    if (!done && t < start) continue
    text(11 + i, 5, LABEL[i], "38;5;141")
    v = VALUE[i]
    n = done ? length(v) : int((t - start) * 3)
    if (n > length(v)) n = length(v)
    text(11 + i, 21, substr(v, 1, n), "1;38;5;231")
    if (n < length(v)) cell(11 + i, 21 + n, "█", "38;5;51")
  }
}

function scroller_draw(t,   s, x, i, c, y, p) {
  s = t - 30
  for (x = 0; x < W; x++) {
    i = x + s - W
    if (i < 0 || i >= length(SCROLL)) continue
    c = substr(SCROLL, i + 1, 1)
    if (c == " ") continue
    y = H - 5 + WAVE[wrap(x + t * 4 / 3, NWAVE) + 1]
    p = (x < 3 || x >= W - 3) ? "38;5;240" : "1;38;5;" RAINBOW[wrap(x + t * 1.5, NRAINBOW) + 1]
    cell(y, x, c, p)
  }
}

function compose(t, done) {
  wipe()
  if (!done) stars_draw()
  bars_draw(t, done)
  logo_draw(t, done)
  credits_draw(t, done)
  info_draw(t, done)
  if (!done) {
    scroller_draw(t)
    if (skippable) text(18, W - 17, "any key = skip", "38;5;238")
  }
}

# Synchronized output (DEC 2026) makes supporting terminals swap whole frames;
# the rest ignore the unknown mode. Every frame ends on the canvas bottom row,
# so the next one climbs back to the origin relative to it.
function show(rows, tail,   y, out) {
  out = esc "[?2026h" (drawn ? "\r" esc "[" (H - 1) "A" : "")
  drawn = 1
  for (y = 0; y < rows; y++) out = out row(y) esc "[K" ((y < rows - 1) ? "\n" : "")
  printf "%s%s%s", out, tail, esc "[?2026l"
  fflush()
}

BEGIN {
  LX = 2
  LOGO[0] = "###7   ##7 #####7 ######7 ######7 ######7  ######7 ###7   ###7#######7"
  LOGO[1] = "####7  ##I##F==##7##F==##7##F==##7##F==##7##F===##7####7 ####IL==###FJ"
  LOGO[2] = "##F##7 ##I#######I##I  ##I######FJ######FJ##I   ##I##F####F##I  ###FJ "
  LOGO[3] = "##IL##7##I##F==##I##I  ##I##F==##7##F==##7##I   ##I##IL##FJ##I ###FJ  "
  LOGO[4] = "##I L####I##I  ##I######FJ##I  ##I######FJL######FJ##I L=J ##I#######7"
  LOGO[5] = "L=J  L===JL=J  L=JL=====J L=J  L=JL=====J  L=====J L=J     L=JL======J"
  GLYPH["#"] = "█"; GLYPH["7"] = "╗"; GLYPH["F"] = "╔"; GLYPH["J"] = "╝"
  GLYPH["L"] = "╚"; GLYPH["="] = "═"; GLYPH["I"] = "║"
  NOISE[1] = "░"; NOISE[2] = "▒"; NOISE[3] = "▓"
  NCHROME = split("93 129 165 201 207 213 219 225 231 195 159 123 87 51 45 39 33 27 57", CHROME, " ")
  NCOPPER = split("53 54 55 56 57 93 129 165 201 165 129 93 57 56 55 54", COPPER, " ")
  NRAINBOW = split("196 202 208 214 220 226 190 154 118 82 46 47 48 49 50 51 45 39 33 27 21 57 93 129 165 201 200 199 198 197", RAINBOW, " ")
  # One period of int(2.5 + 2 * sin) in 42 steps; busybox awk is often built
  # without math support, so the scroller wave comes from a table.
  NWAVE = split("2 2 3 3 3 3 4 4 4 4 4 4 4 4 4 4 3 3 3 3 2 2 2 1 1 1 1 0 0 0 0 0 0 0 0 0 0 1 1 1 1 2", WAVE, " ")
  NSTARS = 46
  STAR[1] = "."; STAR[2] = "·"; STAR[3] = "*"
  STARC[1] = "38;5;237"; STARC[2] = "38;5;244"; STARC[3] = "38;5;252"
  SPEED[1] = 0.25; SPEED[2] = 0.5; SPEED[3] = 1
  NINFO = 7
  LABEL[0] = "RELEASE ....... "; VALUE[0] = "nadrbomz shell + claude environment"
  LABEL[1] = "TARGET ........ "; VALUE[1] = target
  LABEL[2] = "OPERATOR ...... "; VALUE[2] = operator
  LABEL[3] = "RELEASE DATE .. "; VALUE[3] = rdate
  LABEL[4] = "SUPPLIED BY ... "; VALUE[4] = "zeroznet"
  LABEL[5] = "CRACKED BY .... "; VALUE[5] = "Boba Bott"
  LABEL[6] = "PROTECTION .... "; VALUE[6] = "none, we checked"
  for (i = 0; i < NINFO; i++) VALUE[i] = substr(VALUE[i], 1, W - 21)
  SCROLL = "*** NADRBOMZ ***     ZEROZNET PRESENTS ANOTHER FLAWLESS DOTFILES RELEASE ...     ZSH, TMUX, NEOVIM, SSH AND CLAUDE CONFIG IN ONE CURL ...     CRACKED, TRAINED AND PACKED BY BOBA BOTT ...     NO .BASHRC WAS HARMED (OK, ONE. IT HAS A .BAK) ...     GREETZ TO OHMYZSH CREW * ZSH-USERS * TMUX POSSE * NEOVIM MAFIA * RAZOR 1911 * FAIRLIGHT * FUTURE CREW * THE BLACK LOTUS ...     ZEROZNET SIGNING OFF ...     "

  srand(seed)
  for (y = 0; y < 6; y++)
    for (x = 0; x < 70; x++) REVEAL[y, x] = 6 + int(x * 0.45) + int(rand() * 14)

  if (mode == "static") {
    compose(0, 1)
    for (y = 0; y < 18; y++) print row(y)
    exit
  }
  for (y = 1; y < H; y++) printf "\n"
  printf "%s[%dA", esc, H - 1
  stars_init()
  last = 30 + length(SCROLL) + W
  for (t = 0; t < last; t++) {
    if (skipfile != "") {
      skip = (getline flag < skipfile)
      close(skipfile)
      if (skip > 0) break
    }
    stars_move()
    compose(t, 0)
    show(H, "")
    system("sleep " delay)
  }
  compose(t, 1)
  show(18, "\n" esc "[J")
}
AWK
}

intro_terminal_fits() {
  size="$(stty size </dev/tty 2>/dev/null)" || return 1
  rows="${size% *}"
  cols="${size#* }"
  case "${rows}${cols}" in
    ''|*[!0-9]*) return 1 ;;
  esac
  [ "${rows}" -gt "${INTRO_HEIGHT}" ] && [ "${cols}" -gt "${INTRO_WIDTH}" ]
}

restore_intro_terminal() {
  if [ -n "${INTRO_SKIP_FILE}" ]; then
    rm -f "${INTRO_SKIP_FILE}"
  fi
  if [ -n "${INTRO_TTY_STATE}" ]; then
    stty "${INTRO_TTY_STATE}" </dev/tty 2>/dev/null || true
  fi
  printf '%s[?2026l%s[0m%s[?25h' "${ESC}" "${ESC}" "${ESC}"
}

abort_intro() {
  if [ -n "${INTRO_PID}" ]; then
    kill "${INTRO_PID}" 2>/dev/null || true
  fi
  restore_intro_terminal
  printf '\n'
  exit 130
}

# The renderer runs in the background while the tty sits in non-canonical mode
# with a 0.1s read timeout, so polling it for a skip key never blocks for long.
# A key press writes the skip file, which awk checks between frames, so the
# intro always ends on a whole final frame. Background jobs of a
# non-interactive shell ignore SIGINT, hence the trap that takes awk down on
# Ctrl-C.
play_intro_demo() {
  INTRO_PID=""
  INTRO_SKIP_FILE=""
  INTRO_TTY_STATE="$(stty -g </dev/tty 2>/dev/null)" || INTRO_TTY_STATE=""
  if [ -n "${INTRO_TTY_STATE}" ] && ! stty -icanon -echo min 0 time 1 </dev/tty 2>/dev/null; then
    INTRO_TTY_STATE=""
  fi
  trap restore_intro_terminal EXIT
  trap abort_intro INT TERM HUP
  printf '%s[?25l' "${ESC}"

  if [ -n "${INTRO_TTY_STATE}" ]; then
    INTRO_SKIP_FILE="$(mktemp "${TMPDIR:-/tmp}/nadrbomz-skip.XXXXXX")"
    awk "$@" -v skippable=1 -v skipfile="${INTRO_SKIP_FILE}" "${INTRO_PROGRAM}" </dev/null &
    INTRO_PID=$!
    while kill -0 "${INTRO_PID}" 2>/dev/null; do
      key_bytes="$(dd bs=1 count=1 </dev/tty 2>/dev/null | wc -c | tr -d ' ')" || key_bytes=0
      if [ "${key_bytes:-0}" -gt 0 ]; then
        printf 'skip\n' >"${INTRO_SKIP_FILE}"
      fi
    done
    wait "${INTRO_PID}" 2>/dev/null || true
  else
    awk "$@" -v skippable=0 -v skipfile="" "${INTRO_PROGRAM}" </dev/null
  fi

  INTRO_PID=""
  trap - EXIT INT TERM HUP
  restore_intro_terminal
}

print_intro() {
  printf '\n'
  if ! has_cmd awk; then
    return 0
  fi
  INTRO_PROGRAM="$(intro_awk_program)"
  set -- -v esc="${ESC}" -v W="${INTRO_WIDTH}" -v H="${INTRO_HEIGHT}" -v delay=0.02 -v seed="$$" \
    -v target="$(detect_os) @ $(uname -n)" -v operator="${USER:-$(id -un)}" -v rdate="$(date +%Y-%m-%d)"
  if [ -n "${ESC}" ] && intro_terminal_fits; then
    play_intro_demo "$@"
  else
    awk "$@" -v mode=static "${INTRO_PROGRAM}" </dev/null
    pause 3
  fi
}

print_outro() {
  os="$(detect_os)"
  zsh_path="$(command -v zsh)"
  case "${os}" in
    freebsd) chsh_cmd="sudo chsh -s ${zsh_path} ${USER:-\$USER}" ;;
    *)       chsh_cmd="chsh -s ${zsh_path}" ;;
  esac

  printf '\n'
  print_rule 57 '▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄'
  printf '           %s░▒▓█%s  I N S T A L L A T I O N   C O M P L E T E  %s█▓▒░%s\n' \
    "$(sgr '38;5;213')" "$(sgr '1;38;5;231')" "$(sgr '38;5;39')" "$(sgr 0)"
  print_rule 57 '▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀'
  printf '\n'
  printf '     %sSCOREBOARD%s\n' "$(sgr '1;38;5;213')" "$(sgr 0)"
  print_info_row 'DEPLOYED ...... ' "${OK_COUNT}"
  print_info_row 'SKIPPED ....... ' "${SKIP_COUNT}"
  print_info_row 'WARNINGS ...... ' "${WARN_COUNT}"
  print_info_row 'RUNTIME ....... ' "${1}s"
  printf '\n'
  printf '     %sNEXT MOVES%s\n' "$(sgr '1;38;5;213')" "$(sgr 0)"
  print_info_row 'START ZSH ..... ' 'exec zsh'
  print_info_row 'LOGIN SHELL ... ' "${chsh_cmd}"
  printf '\n'
  printf '     %sgreetz fly out to%s ohmyzsh crew * zsh-users * tmux posse * razor 1911\n' \
    "$(sgr '1;38;5;141')" "$(sgr 0)"
  printf '     fairlight * future crew * tbl * every sysop still running screen\n\n'
  printf '     %szero fear. zero bloat. zeroznet.%s\n\n' "$(sgr '3;38;5;240')" "$(sgr 0)"
}

deploy_tree_from_clone() {
  src="$1"
  target="$2"
  label="$3"

  backup_note=""
  if [ -d "${target}" ]; then
    backup="${target}.bak"
    rm -rf "${backup}"
    cp -rp "${target}" "${backup}"
    backup_note=" +bak"
  fi

  mkdir -p "${target}"
  cp -r "${src}/." "${target}/"
  report_ok "${label}" "$(tilde "${target}")/${backup_note}"
}

deploy_file_from_clone() {
  src="$1"
  target="$2"
  label="$3"

  mkdir -p "$(dirname "${target}")"

  backup_note=""
  if [ -f "${target}" ] || [ -L "${target}" ]; then
    backup="${target}.bak"
    cp -p "${target}" "${backup}"
    backup_note=" +bak"
  fi

  cp "${src}" "${target}"
  report_ok "${label}" "$(tilde "${target}")${backup_note}"
}

deploy_claude_config() {
  clone_dir="$(mktemp -d "${TMPDIR:-/tmp}/nadrbomz-clone.XXXXXX")"
  trap 'rm -rf "${clone_dir}"' EXIT HUP INT TERM

  step_begin "nadrbomz repo"
  git clone -q --depth 1 "${NADRBOMZ_CLONE_URL}" "${clone_dir}"
  report_ok "nadrbomz repo" "cloned @ $(git -C "${clone_dir}" rev-parse --short HEAD)"

  deploy_tree_from_clone "${clone_dir}/claude/skills"   "${CLAUDE_DIR}/skills"   "skills"
  deploy_tree_from_clone "${clone_dir}/claude/commands" "${CLAUDE_DIR}/commands" "commands"
  deploy_tree_from_clone "${clone_dir}/claude/scripts"  "${CLAUDE_DIR}/scripts"  "scripts"
  deploy_file_from_clone "${clone_dir}/claude/statusline-command.sh" "${CLAUDE_DIR}/statusline-command.sh" "statusline"
  deploy_file_from_clone "${clone_dir}/claude/settings.json" "${CLAUDE_DIR}/settings.json" "settings.json"

  deploy_file_from_clone "${clone_dir}/dev/CLAUDE.md" "${DEV_DIR}/CLAUDE.md" "workspace CLAUDE.md"
  deploy_file_from_clone "${clone_dir}/dev/HOWTO.md"  "${DEV_DIR}/HOWTO.md"  "workspace HOWTO.md"

  chmod +x "${CLAUDE_DIR}/scripts/prune.sh" "${CLAUDE_DIR}/statusline-command.sh" 2>/dev/null || true

  rm -rf "${clone_dir}"
  trap - EXIT HUP INT TERM
}

bootstrap_claude_plugins() {
  if ! has_cmd claude; then
    report_skip "plugins" "claude CLI not found"
    return 0
  fi
  if ! has_cmd jq; then
    warn "jq not found, skipping plugin bootstrap (install jq to enable). settings.json already deployed."
    return 0
  fi

  settings="${CLAUDE_DIR}/settings.json"
  if [ ! -f "${settings}" ]; then
    report_skip "plugins" "no settings.json"
    return 0
  fi

  # A jq failure inside the here-docs below would silently read as "no entries",
  # so a malformed settings.json is caught up front and reported instead.
  if ! jq empty "${settings}" 2>/dev/null; then
    warn "settings.json is not valid JSON, skipping plugin bootstrap."
    return 0
  fi

  # Loops read here-docs instead of pipes so they run in this shell and the
  # report counters survive for the outro stats.
  known="${CLAUDE_DIR}/plugins/known_marketplaces.json"
  present=0
  while read -r name repo; do
    [ -n "${repo}" ] || continue
    if [ -f "${known}" ] && jq -e --arg n "${name}" 'has($n)' "${known}" >/dev/null 2>&1; then
      present=$((present + 1))
      continue
    fi
    step_begin "${name}"
    if claude plugin marketplace add "${repo}" >/dev/null 2>&1; then
      report_ok "${name}" "marketplace added"
    else
      warn "marketplace add ${repo} failed"
    fi
  done <<EOF
$(jq -r '.extraKnownMarketplaces // {} | to_entries[] | "\(.key) \(.value.source.repo // "")"' "${settings}")
EOF
  if [ "${present}" -gt 0 ]; then
    report_skip "marketplaces" "${present} already registered"
  fi

  installed="${CLAUDE_DIR}/plugins/installed_plugins.json"
  present=0
  while IFS= read -r plugin; do
    [ -n "${plugin}" ] || continue
    if [ -f "${installed}" ] && jq -e --arg p "${plugin}" '.plugins | has($p)' "${installed}" >/dev/null 2>&1; then
      present=$((present + 1))
      continue
    fi
    step_begin "${plugin%@*}"
    if claude plugin install "${plugin}" >/dev/null 2>&1; then
      report_ok "${plugin%@*}" "installed from ${plugin#*@}"
    else
      warn "install ${plugin} failed"
    fi
  done <<EOF
$(jq -r '.enabledPlugins // {} | to_entries[] | select(.value == true) | .key' "${settings}")
EOF
  if [ "${present}" -gt 0 ]; then
    report_skip "plugins" "${present} already installed"
  fi
}

main() {
  started_at="$(date +%s)"
  print_intro
  check_prereqs

  print_section "SHELL CORE"
  install_ohmyzsh
  mkdir -p "${ZSH_CUSTOM_DIR}/plugins"
  sync_git_repo "${AUTOSUGGEST_REPO}" "${AUTOSUGGEST_DIR}" "zsh-autosuggestions"

  print_section "DOTFILES"
  deploy_dotfiles

  print_section "WSL TOOLS"
  deploy_wsl_scripts

  print_section "CLAUDE CONFIG"
  deploy_claude_config

  print_section "CLAUDE PLUGINS"
  bootstrap_claude_plugins

  print_section "TERMINAL"
  fix_terminfo_setaf

  print_outro "$(($(date +%s) - started_at))"
}

main "$@"
