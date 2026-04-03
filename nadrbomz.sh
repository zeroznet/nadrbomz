#!/usr/bin/env sh
# scripted by Robert Bopko (github.com/zeroznet) with Boba Bott (GPT-5.4-Thinking by OpenAI)

set -eu

ZSHRC_URL="https://raw.githubusercontent.com/zeroznet/nadrbomz/main/zshrc_zero"
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
    CHSH=no RUNZSH=no KEEP_ZSHRC=yes sh -c \
      "$(curl -fsSL "${install_url}")" "" --unattended
  elif has_cmd fetch; then
    tmp_installer=$(mktemp "${TMPDIR:-/tmp}/ohmyzsh.XXXXXX")
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

deploy_zshrc() {
  tmp_zshrc=$(mktemp "${TMPDIR:-/tmp}/zshrc.XXXXXX")
  trap 'rm -f "${tmp_zshrc}"' EXIT HUP INT TERM

  log "Downloading .zshrc from GitHub..."
  download_file "${ZSHRC_URL}" "${tmp_zshrc}"

  if [ -f "${HOME}/.zshrc" ] || [ -L "${HOME}/.zshrc" ]; then
    backup="${HOME}/.zshrc.bak.$(date +%Y%m%d%H%M%S)"
    cp -p "${HOME}/.zshrc" "${backup}"
    log "Backed up existing .zshrc to ${backup}"
  fi

  mv "${tmp_zshrc}" "${HOME}/.zshrc"
  trap - EXIT HUP INT TERM
  log "Installed ${HOME}/.zshrc"
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

  deploy_zshrc

  log "Done."
  log "Run: exec zsh"
}

main "$@"
