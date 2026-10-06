---
description: Clear Claude ephemera (transcripts, history, plans, caches, daemon/agent-view state). Dry-run by default; --apply stops the background daemon and deletes. Preserves credentials, settings, plugins, skills, commands, agents, hooks, and per-project memory/.
argument-hint: "[--apply]"
disable-model-invocation: true
allowed-tools: Bash(~/.claude/scripts/prune.sh:*)
---

Run `~/.claude/scripts/prune.sh $ARGUMENTS` and show the output verbatim.

If the user invoked this without `--apply`, end your reply by reminding them: "Re-run as `/prune --apply` to actually delete."

If they invoked with `--apply`, the script prints a single "cleared <size>" line — relay it verbatim and add nothing else.

Do not perform any other actions. Do not delete anything outside what the script handles.
