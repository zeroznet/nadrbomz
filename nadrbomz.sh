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

print_logo() {
  set -- 213 177 141 105 69 39
  while IFS= read -r line; do
    printf '  %s%s%s\n' "$(sgr "1;38;5;$1")" "${line}" "$(sgr 0)"
    shift
    pause 0.06
  done <<'EOF'
███╗   ██╗ █████╗ ██████╗ ██████╗ ██████╗  ██████╗ ███╗   ███╗███████╗
████╗  ██║██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔═══██╗████╗ ████║╚══███╔╝
██╔██╗ ██║███████║██║  ██║██████╔╝██████╔╝██║   ██║██╔████╔██║  ███╔╝
██║╚██╗██║██╔══██║██║  ██║██╔══██╗██╔══██╗██║   ██║██║╚██╔╝██║ ███╔╝
██║ ╚████║██║  ██║██████╔╝██║  ██║██████╔╝╚██████╔╝██║ ╚═╝ ██║███████╗
╚═╝  ╚═══╝╚═╝  ╚═╝╚═════╝ ╚═╝  ╚═╝╚═════╝  ╚═════╝ ╚═╝     ╚═╝╚══════╝
EOF
}

print_info_row() {
  printf '     %s%s%s%s%s%s\n' "$(sgr '38;5;141')" "$1" "$(sgr 0)" "$(sgr '1;38;5;231')" "$2" "$(sgr 0)"
}

print_intro() {
  printf '\n'
  print_rule 57 '▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄'
  print_logo
  print_rule 57 '▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀'
  printf '              %s-=[%s z e r o z n e t   p r e s e n t s %s]=-%s\n\n' \
    "$(sgr '38;5;240')" "$(sgr '1;38;5;51')" "$(sgr '38;5;240')" "$(sgr 0)"
  pause 0.2
  printf '     %s░▒▓█ RELEASE INFO █▓▒░%s\n' "$(sgr '1;38;5;213')" "$(sgr 0)"
  print_info_row 'RELEASE ....... ' 'nadrbomz shell + claude environment'
  print_info_row 'TARGET ........ ' "$(detect_os) @ $(uname -n)"
  print_info_row 'OPERATOR ...... ' "${USER:-$(id -un)}"
  print_info_row 'RELEASE DATE .. ' "$(date +%Y-%m-%d)"
  print_info_row 'SUPPLIED BY ... ' 'zeroznet'
  print_info_row 'CRACKED BY .... ' 'Boba Bott'
  print_info_row 'PROTECTION .... ' 'none, we checked'
  printf '\n'
  pause 0.3
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
  printf '     fairlight * future crew * anthropic * every sysop still running screen\n\n'
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
