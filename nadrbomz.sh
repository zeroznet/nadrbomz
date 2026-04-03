#!/usr/bin/env sh
set -eu

ZSHRC_URL="https://tfx.one/~zero/zsh/zshrc"
OHMYZSH_DIR="${HOME}/.oh-my-zsh"
ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-${OHMYZSH_DIR}/custom}"
AUTOSUGGEST_DIR="${ZSH_CUSTOM_DIR}/plugins/zsh-autosuggestions"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1" >&2
    exit 1
  }
}

need_cmd curl
need_cmd git
need_cmd zsh

if [ ! -d "${OHMYZSH_DIR}" ]; then
  echo "Installing Oh My Zsh..."
  CHSH=no RUNZSH=no KEEP_ZSHRC=yes sh -c \
    "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    "" --unattended
else
  echo "Oh My Zsh already exists, skipping install."
fi

mkdir -p "${ZSH_CUSTOM_DIR}/plugins"

if [ ! -d "${AUTOSUGGEST_DIR}" ]; then
  echo "Cloning zsh-autosuggestions..."
  git clone https://github.com/zsh-users/zsh-autosuggestions "${AUTOSUGGEST_DIR}"
else
  echo "zsh-autosuggestions already exists, skipping clone."
fi

if [ -f "${HOME}/.zshrc" ]; then
  cp "${HOME}/.zshrc" "${HOME}/.zshrc.bak.$(date +%Y%m%d%H%M%S)"
fi

echo "Downloading .zshrc..."
curl -fsSL "${ZSHRC_URL}" -o "${HOME}/.zshrc"

echo "Done."
echo "Run: exec zsh"
