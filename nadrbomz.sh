#!/usr/bin/env sh
# scripted by Robert Bopko (github.com/zeroznet) with Boba Bott (GPT-5.4-Thinking by OpenAI)

set -eu

BASE_URL="https://raw.githubusercontent.com/zeroznet/nadrbomz/main"

ZSHRC_URL="${BASE_URL}/zshrc_zero"
BASHRC_URL="${BASE_URL}/bashrc_zero"
SHELL_ALIASES_URL="${BASE_URL}/shell_aliases_zero"
SCREENRC_URL="${BASE_URL}/screenrc_zero"
NVIM_INIT_URL="${BASE_URL}/init.vim_zero"

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

need_cmd() {
  has_cmd "$1" || die "Missing required command: $1"
}

download_file() {
  url="$1"
  out="$2"

  if has_cmd curl; then
    curl -fsSL "$url" -o "$out"
  elif has_cmd fetch; then
    fetch -q -o "$out" "$url"
  else
    die "Need curl or fetch to download files"
  fi
}

install_ohmyzsh() {
  install_url="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"

  if [ -d "${OHMYZSH_DIR}" ]; then
    log "Oh My Zsh already exists, skipping install."
    return 0
  fi

  log "Installing Oh My Zsh..."

  if has_cmd curl; then
    CHSH=no RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL "${install_url}")" "" --unattended
  elif has_cmd fetch; then
    tmp_installer="$(mktemp "${TMPDIR:-/tmp}/ohmyzsh.XXXXXX")"
    fetch -q -o "${tmp_installer}" "${install_url}"
    CHSH=no RUNZSH=no KEEP_ZSHRC=yes sh "${tmp_installer}" --unattended
    rm -f "${tmp_installer}"
  else
    die "Need curl or fetch to install Oh My Zsh"
  fi
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
  deploy_file "${NVIM_INIT_URL}" "${HOME}/.config/nvim/init.vim" "init.vim"
}

main() {
  need_cmd git
  need_cmd zsh

  if ! has_cmd curl && ! has_cmd fetch; then
    die "Need curl or fetch"
  fi

  install_ohmyzsh

  mkdir -p "${ZSH_CUSTOM_DIR}/plugins"
  sync_git_repo "${AUTOSUGGEST_REPO}" "${AUTOSUGGEST_DIR}" "zsh-autosuggestions"

  deploy_dotfiles

  log "Done."
  log "Run: exec zsh"
}

main "$@"
