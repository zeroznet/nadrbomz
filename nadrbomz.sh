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

NADRBOMZ_CLONE_URL="${NADRBOMZ_CLONE_URL:-https://github.com/zeroznet/nadrbomz.git}"
CLAUDE_DIR="${HOME}/.claude"
DEV_DIR="${HOME}/dev"

OHMYZSH_DIR="${HOME}/.oh-my-zsh"
ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-${OHMYZSH_DIR}/custom}"
AUTOSUGGEST_DIR="${ZSH_CUSTOM_DIR}/plugins/zsh-autosuggestions"
AUTOSUGGEST_REPO="https://github.com/zsh-users/zsh-autosuggestions.git"

log() {
  printf '%s\n' "$*"
}

warn() {
  printf 'WARNING: %s\n' "$*" >&2
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
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
    log "Oh My Zsh already exists, skipping install."
    return 0
  fi

  log "Installing Oh My Zsh..."
  CHSH=no RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL "${install_url}")" "" --unattended
}

sync_git_repo() {
  repo_url="$1"
  repo_dir="$2"
  repo_name="$3"

  if [ -d "${repo_dir}/.git" ]; then
    log "Updating ${repo_name}..."
    git -C "${repo_dir}" pull --ff-only
  else
    log "Installing ${repo_name}..."
    rm -rf "${repo_dir}"
    git clone --depth 1 "${repo_url}" "${repo_dir}"
  fi
}

deploy_file() {
  url="$1"
  target="$2"
  label="$3"

  tmp_file="$(mktemp "${TMPDIR:-/tmp}/dotfile.XXXXXX")"
  trap 'rm -f "${tmp_file}"' EXIT HUP INT TERM

  log "Downloading ${label} from GitHub..."
  download_file "${url}" "${tmp_file}"

  target_dir="$(dirname "${target}")"
  mkdir -p "${target_dir}"

  if [ -f "${target}" ] || [ -L "${target}" ]; then
    backup="${target}.bak.$(date +%Y%m%d%H%M%S)"
    cp -p "${target}" "${backup}"
    log "Backed up existing ${label} to ${backup}"
  fi

  mv "${tmp_file}" "${target}"
  trap - EXIT HUP INT TERM

  log "Installed ${target}"
}

deploy_dotfiles() {
  deploy_file "${SHELL_ALIASES_URL}" "${HOME}/.shell_aliases" ".shell_aliases"
  deploy_file "${ZSHRC_URL}" "${HOME}/.zshrc" ".zshrc"
  deploy_file "${BASHRC_URL}" "${HOME}/.bashrc" ".bashrc"
  deploy_file "${SCREENRC_URL}" "${HOME}/.screenrc" ".screenrc"
  deploy_file "${TMUXRC_URL}" "${HOME}/.tmux.conf" ".tmux.conf"
  deploy_file "${NVIM_INIT_URL}" "${HOME}/.config/nvim/init.vim" "init.vim"
  deploy_file "${FASTFETCH_CONFIG_URL}" "${HOME}/.config/fastfetch/config.jsonc" "fastfetch config"
  deploy_file "${SSH_CONFIG_URL}" "${HOME}/.ssh/config" "ssh config"
}

fix_terminfo_setaf() {
  # FreeBSD base ships only termcap (/etc/termcap), whose xterm-256color uses an
  # unconditional setaf (\E[38;5;%p1%dm) that encodes the 8 ANSI colours as
  # indexed. Bold + an indexed colour can't be brightened, so Windows Terminal
  # renders it as heavier font weight. Compile a corrected entry (conditional
  # setaf: legacy \E[3Nm for colours 0-7) into ~/.terminfo, which tinfo reads
  # before /etc/termcap. No-op where setaf is already correct (e.g. Linux).
  if ! has_cmd infocmp || ! has_cmd tic; then
    log "infocmp/tic missing, skipping terminfo fix."
    return 0
  fi

  if ! infocmp xterm-256color 2>/dev/null | grep -q 'setaf=\\E\[38;5;%p1%dm'; then
    log "Terminfo xterm-256color already correct, skipping."
    return 0
  fi

  log "Patching xterm-256color terminfo (conditional setaf) into ~/.terminfo..."
  ti_src="$(mktemp "${TMPDIR:-/tmp}/terminfo.XXXXXX")"
  trap 'rm -f "${ti_src}"' EXIT HUP INT TERM
  infocmp -x xterm-256color | sed \
    -e 's#setaf=\\E\[38;5;%p1%dm#setaf=\\E[%?%p1%{8}%<%t3%p1%d%e%p1%{16}%<%t9%p1%{8}%-%d%e38;5;%p1%d%;m#' \
    -e 's#setab=\\E\[48;5;%p1%dm#setab=\\E[%?%p1%{8}%<%t4%p1%d%e%p1%{16}%<%t10%p1%{8}%-%d%e48;5;%p1%d%;m#' \
    > "${ti_src}"
  tic -x "${ti_src}"
  rm -f "${ti_src}"
  trap - EXIT HUP INT TERM
  log "Installed corrected xterm-256color to ~/.terminfo"
}

print_post_install_hint() {
  os="$(detect_os)"
  zsh_path="$(command -v zsh)"

  log "Done."
  log ""
  log "Start zsh now:           exec zsh"
  case "${os}" in
    freebsd)
      log "Set zsh as login shell:  sudo chsh -s ${zsh_path} ${USER:-\$USER}"
      ;;
    *)
      log "Set zsh as login shell:  chsh -s ${zsh_path}"
      ;;
  esac
}

deploy_tree_from_clone() {
  src="$1"
  target="$2"
  label="$3"

  if [ -d "${target}" ]; then
    backup="${target}.bak.$(date +%Y%m%d%H%M%S)"
    cp -rp "${target}" "${backup}"
    log "Backed up existing ${label} to ${backup}"
  fi

  mkdir -p "${target}"
  cp -r "${src}/." "${target}/"
  log "Synced ${label} into ${target}"
}

deploy_file_from_clone() {
  src="$1"
  target="$2"
  label="$3"

  mkdir -p "$(dirname "${target}")"

  if [ -f "${target}" ] || [ -L "${target}" ]; then
    backup="${target}.bak.$(date +%Y%m%d%H%M%S)"
    cp -p "${target}" "${backup}"
    log "Backed up existing ${label} to ${backup}"
  fi

  cp "${src}" "${target}"
  log "Installed ${target}"
}

deploy_claude_config() {
  clone_dir="$(mktemp -d "${TMPDIR:-/tmp}/nadrbomz-clone.XXXXXX")"
  trap 'rm -rf "${clone_dir}"' EXIT HUP INT TERM

  log "Cloning nadrbomz for Claude config..."
  git clone --depth 1 "${NADRBOMZ_CLONE_URL}" "${clone_dir}"

  deploy_tree_from_clone "${clone_dir}/claude/skills"   "${CLAUDE_DIR}/skills"   "Claude skills"
  deploy_tree_from_clone "${clone_dir}/claude/commands" "${CLAUDE_DIR}/commands" "Claude commands"
  deploy_tree_from_clone "${clone_dir}/claude/scripts"  "${CLAUDE_DIR}/scripts"  "Claude scripts"
  deploy_file_from_clone "${clone_dir}/claude/statusline-command.sh" "${CLAUDE_DIR}/statusline-command.sh" "Claude statusline"
  deploy_file_from_clone "${clone_dir}/claude/settings.json" "${CLAUDE_DIR}/settings.json" "Claude settings.json"

  deploy_file_from_clone "${clone_dir}/dev/CLAUDE.md" "${DEV_DIR}/CLAUDE.md" "workspace CLAUDE.md"
  deploy_file_from_clone "${clone_dir}/dev/HOWTO.md"  "${DEV_DIR}/HOWTO.md"  "workspace HOWTO.md"

  chmod +x "${CLAUDE_DIR}/scripts/prune.sh" "${CLAUDE_DIR}/statusline-command.sh" 2>/dev/null || true

  rm -rf "${clone_dir}"
  trap - EXIT HUP INT TERM
}

bootstrap_claude_plugins() {
  if ! has_cmd claude; then
    log "claude CLI not found, skipping plugin bootstrap."
    return 0
  fi
  if ! has_cmd jq; then
    warn "jq not found, skipping plugin bootstrap (install jq to enable). settings.json already deployed."
    return 0
  fi

  settings="${CLAUDE_DIR}/settings.json"
  if [ ! -f "${settings}" ]; then
    log "No settings.json found, skipping plugin bootstrap."
    return 0
  fi

  # set -o pipefail is active, so a jq failure on a malformed settings.json
  # would propagate through the pipelines below and abort the installer under
  # set -e. Validate up front and skip rather than letting bootstrap kill the run.
  if ! jq empty "${settings}" 2>/dev/null; then
    warn "settings.json is not valid JSON, skipping plugin bootstrap."
    return 0
  fi

  known="${CLAUDE_DIR}/plugins/known_marketplaces.json"
  log "Syncing extra marketplaces..."
  jq -r '.extraKnownMarketplaces // {} | to_entries[] | "\(.key) \(.value.source.repo // "")"' "${settings}" |
  while read -r name repo; do
    [ -n "${repo}" ] || continue
    if [ -f "${known}" ] && jq -e --arg n "${name}" 'has($n)' "${known}" >/dev/null 2>&1; then
      continue
    fi
    log "  marketplace add ${repo}"
    claude plugin marketplace add "${repo}" >/dev/null 2>&1 || warn "  marketplace add ${repo} failed"
  done

  installed="${CLAUDE_DIR}/plugins/installed_plugins.json"
  log "Syncing enabled plugins..."
  jq -r '.enabledPlugins // {} | to_entries[] | select(.value == true) | .key' "${settings}" |
  while IFS= read -r plugin; do
    [ -n "${plugin}" ] || continue
    if [ -f "${installed}" ] && jq -e --arg p "${plugin}" '.plugins | has($p)' "${installed}" >/dev/null 2>&1; then
      continue
    fi
    log "  install ${plugin}"
    claude plugin install "${plugin}" >/dev/null 2>&1 || warn "  install ${plugin} failed"
  done
}

main() {
  check_prereqs

  install_ohmyzsh

  mkdir -p "${ZSH_CUSTOM_DIR}/plugins"
  sync_git_repo "${AUTOSUGGEST_REPO}" "${AUTOSUGGEST_DIR}" "zsh-autosuggestions"

  deploy_dotfiles

  deploy_claude_config
  bootstrap_claude_plugins

  fix_terminfo_setaf

  print_post_install_hint
}

main "$@"
