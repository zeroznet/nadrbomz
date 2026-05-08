# TODO

## Terminal / scrollback situation

**Problem:** Windows Terminal + ConPTY (and any modern terminal that emits DECSET 1007 alt-scroll) breaks mouse wheel inside tmux — wheel rotates shell history instead of scrolling. Shift+PgUp also doesn't reach tmux scrollback by default. PuTTY works because it predates DECSET 1007.

**Root cause:** tmux owns the screen via its own grid model and sends terminal capabilities that signal "interactive TUI", which makes the host terminal translate wheel events into arrow keys. No tmux config setting fixes this.

**Options going forward:**

- **Stay on tmux, use `prefix [` for scroll** — copy mode with PgUp/PgDn/arrows/`/search`, `q` exits. tmux has its own 50000-line history, always coherent. Different UX but works everywhere.
- **Go back to GNU `screen`** — `.screenrc` already in this repo. Screen lets the terminal scroll naturally (status bar gets scrolled up briefly then redrawn) so PuTTY/WT scrollback works as expected. Lose tmux's split panes.
- **Drop tmux entirely, use `mosh` for persistence** — modern terminals (Ptyxis, WezTerm, Ghostty) have tabs/splits/scrollback natively. `mosh user@host` survives disconnects/roaming/suspend without needing tmux/screen at all. Cleanest modern workflow.

**Decision pending.** Worth a serious test of `mosh + Ptyxis-via-WSLg` or `mosh + WezTerm` before committing.

## CLAUDE.md syncing and configuration

Need to sort out how `CLAUDE.md` files are managed across machines and projects — where the source of truth lives, what gets synced, and what stays per-machine. Also general Claude Code config (skills, hooks, settings.json, memory dir) hygiene.
