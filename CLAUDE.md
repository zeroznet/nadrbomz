<!-- written by Robert Bopko (github.com/zeroznet) with Boba Bott (Claude Opus 5.5) -->

# CLAUDE.md: nadrbomz

Project-specific context for working in this repo. Workspace-wide rules in `/home/zero/dev/CLAUDE.md` still apply; this file only adds what is unique to nadrbomz.

`dev/CLAUDE.md` in this repo is that workspace file, deployed to `~/dev/CLAUDE.md` by the bootstrap. It is a payload, not instructions for this repo. This file is never deployed.

## Parallel lists

The deploy list lives in `nadrbomz.sh` (`deploy_file` / `deploy_tree` calls) and is mirrored in two places. Change all three in the same commit:

- the Source/Target tables in `README.md`, under the matching `NN/06` section
- the target list in the `Bootstrap smoke run` step of `.github/workflows/ci.yml`

Adding or removing a numbered section in the script also renumbers the `NN/06` headings in `README.md`.

## Banner

`assets/cracktro.svg` is generated from the intro awk inside `nadrbomz.sh` (logo, palettes, credits, scroller). After any intro change, run `python3 assets/render-cracktro.py` and commit the SVG with it. CI fails on a stale banner.

## Claude config

- `claude/settings.json` is the source of truth; the live `~/.claude/settings.json` is a deployed copy.
- Live `modelSettings.claude-sonnet-*.effortLevel` drift is intentional (Robert switches it by hand). Do not report it or sync it back.
- `*@builtin` plugins ship with the CLI and are only enabled in `enabledPlugins`; `bootstrap_claude_plugins` skips them because `claude plugin install` rejects them.

## Shell

`nadrbomz.sh` is POSIX sh and must run on dash, bash, busybox ash and FreeBSD `sh`. `set -o pipefail` is POSIX.1-2024 and in FreeBSD `sh` since 12.1, hence its `SC3040` exception. Anything newer than that needs the same proof before use.
