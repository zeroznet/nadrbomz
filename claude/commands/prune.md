---
description: Clear Claude ephemera (transcripts, history, plans, caches). Dry-run by default; --apply deletes. Preserves credentials, settings, plugins, skills, commands, agents, hooks, and per-project memory/.
argument-hint: "[--apply]"
allowed-tools: Bash(~/.claude/scripts/prune.sh:*)
---

Run `~/.claude/scripts/prune.sh $ARGUMENTS` and show the output verbatim.

If the user invoked this without `--apply`, end your reply by reminding them: "Re-run as `/prune --apply` to actually delete."

If they invoked with `--apply`, end your reply with one line confirming the prune ran and the freed-space delta if visible in output.

Do not perform any other actions. Do not delete anything outside what the script handles.
