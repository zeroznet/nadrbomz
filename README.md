# nadrbomz

Personal shell and environment bootstrap.

## What it does

- installs Oh-My-Zsh if missing
- installs or updates `zsh-autosuggestions`
- downloads all config files from GitHub and deploys them:
  - `zshrc_zero` -> `~/.zshrc`
  - `bashrc_zero` -> `~/.bashrc`
  - `shell_aliases_zero` -> `~/.shell_aliases`
  - `init.vim_zero` -> `~/.config/nvim/init.vim`
  - `screenrc_zero` -> `~/.screenrc`
  - `tmuxrc_zero` -> `~/.tmux.conf`
  - `fastfetch_zero` -> `~/.config/fastfetch/config.jsonc`
  - `ssh_config_zero` -> `~/.ssh/config`
- backs up any existing target file before overwriting it (`.bak.YYYYMMDDHHMMSS` suffix)

## One-line install

Generic:

```sh
curl -fsSL https://raw.githubusercontent.com/zeroznet/nadrbomz/main/nadrbomz.sh | sh
```

FreeBSD without `curl`:

```sh
fetch -q -o - https://raw.githubusercontent.com/zeroznet/nadrbomz/main/nadrbomz.sh | sh
```

## Files

- `nadrbomz.sh` - bootstrap script
- `bashrc_zero` - Bash shell config
- `zshrc_zero` - Zsh shell config
- `shell_aliases_zero` - shared shell aliases and functions
- `init.vim_zero` - Neovim config
- `screenrc_zero` - GNU Screen config
- `tmuxrc_zero` - tmux config
- `fastfetch_zero` - fastfetch system info config
- `ssh_config_zero` - SSH client config (hosts and keepalive defaults)

## License

Licensed under the BSD-2-Clause license. See LICENSE.
