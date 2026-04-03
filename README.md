# nadrbomz

Personal shell bootstrap for Zsh.

## Files

- `nadrbomz.sh`
- `zshrc_zero`

## What it does

- installs Oh-My-Zsh if missing
- installs or updates `zsh-autosuggestions`
- downloads `zshrc_zero` from GitHub
- backs up current `~/.zshrc`
- overwrites `~/.zshrc` with the downloaded config

## One-line install

Generic:
curl -fsSL https://raw.githubusercontent.com/zeroznet/nadrbomz/main/nadrbomz.sh | sh

FreeBSD without curl:
fetch -q -o - https://raw.githubusercontent.com/zeroznet/nadrbomz/main/nadrbomz.sh | sh


## License

Licensed under the BSD-2-Clause license. See LICENSE.
