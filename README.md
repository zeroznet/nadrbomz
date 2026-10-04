# nadrbomz

Personal shell and environment bootstrap.

## What it does

- installs Oh-My-Zsh if missing
- installs or updates `zsh-autosuggestions`
- downloads all config files from GitHub and deploys them:
  - `zshrc_zero` -> `~/.zshrc`
  - `zshenv_zero` -> `~/.zshenv`
  - `bashrc_zero` -> `~/.bashrc`
  - `shell_aliases_zero` -> `~/.shell_aliases`
  - `init.vim_zero` -> `~/.config/nvim/init.vim`
  - `screenrc_zero` -> `~/.screenrc`
  - `tmuxrc_zero` -> `~/.tmux.conf`
  - `fastfetch_zero` -> `~/.config/fastfetch/config.jsonc`
  - `ssh_config_zero` -> `~/.ssh/config`
- on WSL machines (kernel release contains `microsoft`), also deploys `ssh-key-ensure_zero` -> `~/.local/bin/ssh-key-ensure` and `wt-connect_zero` -> `~/.local/bin/wt-connect`; in a local WSL session every Windows Terminal tab shares one ssh-agent on a fixed socket and the key passphrase is asked once per boot, while SSH logins and non-WSL hosts keep the forwarded agent or keychain
- syncs the authored Claude config into place:
  - `claude/skills/` -> `~/.claude/skills/` (align, calibrate, handoff, ica, prototype)
  - `claude/commands/`, `claude/scripts/`, `claude/statusline-command.sh`, `claude/settings.json` -> `~/.claude/`
  - `dev/CLAUDE.md` -> `~/dev/CLAUDE.md`, `dev/HOWTO.md` -> `~/dev/HOWTO.md`
- reinstalls marketplace plugins declared in `settings.json` via `claude plugin` (needs `claude` + `jq`; skipped with a warning if either is missing). Plugin code itself is never vendored.
- backs up any existing target file before overwriting it (`.bak.YYYYMMDDHHMMSS` suffix)
- fixes FreeBSD's stale `xterm-256color` terminfo (unconditional `setaf`) by compiling a corrected entry into `~/.terminfo` so bold + a base colour renders correctly instead of as a bold font; no-op where already correct

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
- `zshenv_zero` - Zsh env for every zsh (PATH basics, shared ssh-agent socket in local WSL sessions)
- `ssh-key-ensure_zero` - starts the shared ssh-agent and loads the key once per boot (WSL only)
- `wt-connect_zero` - Windows Terminal remote-tab launcher: ensures the agent, then runs an ssh alias (WSL only)
- `shell_aliases_zero` - shared shell aliases and functions
- `init.vim_zero` - Neovim config
- `screenrc_zero` - GNU Screen config
- `tmuxrc_zero` - tmux config
- `fastfetch_zero` - fastfetch system info config
- `ssh_config_zero` - SSH client config (hosts and keepalive defaults)
- `claude/` - authored Claude Code config (skills, commands, scripts, statusline, `settings.json`) mirrored into `~/.claude`
- `dev/` - workspace docs (`CLAUDE.md`, `HOWTO.md`) deployed to `~/dev`

## License

Licensed under the BSD-2-Clause license. See LICENSE.
