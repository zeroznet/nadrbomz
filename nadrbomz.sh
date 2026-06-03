#!/usr/bin/env sh
# scripted/written by Robert Bopko (github.com/zeroznet) with Boba Bott (Claude Opus 4.7)

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

OHMYZSH_DIR="${HOME}/.oh-my-zsh"
ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-${OHMYZSH_DIR}/custom}"
AUTOSUGGEST_DIR="${ZSH_CUSTOM_DIR}/plugins/zsh-autosuggestions"
AUTOSUGGEST_REPO="https://github.com/zsh-users/zsh-autosuggestions.git"

log() {
  printf '%s\n' "$*"
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

main() {
  check_prereqs

  install_ohmyzsh

  mkdir -p "${ZSH_CUSTOM_DIR}/plugins"
  sync_git_repo "${AUTOSUGGEST_REPO}" "${AUTOSUGGEST_DIR}" "zsh-autosuggestions"

  deploy_dotfiles

  print_post_install_hint
}

main "$@"
