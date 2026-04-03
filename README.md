# nadrbomz

Personal shell bootstrap for Zsh.

## What it does

- installs Oh-My-Zsh if missing
- installs or updates `zsh-autosuggestions`
- downloads `zshrc_zero` from GitHub
- backs up current `~/.zshrc`
- overwrites `~/.zshrc` with the downloaded config

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

- `nadrbomz.sh` - bootstrap
- `zshrc_zero` - my default config

## License

Licensed under the BSD-2-Clause license. See LICENSE.
