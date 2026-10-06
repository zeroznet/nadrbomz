---
name: calibrate
description: Persists what a session taught before it evaporates. Routes corrections, preferences, and tool-call noise into skills, commands, settings, CLAUDE.md, or auto-memory (config lane), and durable session facts such as open work, decisions, and operational facts into the project's canonical files (state lane). Sweeps the conversation, proposes a short numbered menu, applies only what the user picks. Run at session end, before /handoff.
argument-hint: "[--light]"
disable-model-invocation: true
---

# calibrate

## Purpose

Turn this session's hard-won lessons into durable configuration before they evaporate. Read the conversation, detect signals worth keeping (corrections, preferences, frustrations the user expressed more than once, tool noise that should have been allowlisted), and propose **applicable** updates as a short numbered menu with concrete file paths. User picks; calibrate applies. Nothing is written without consent.

Calibrate is the bridge between "I keep correcting Claude on the same thing" and "Claude already knows." It does not store activity logs, summaries, or context — only the *deltas* that future sessions need.

Two lanes, one sweep. **Config lane:** corrections, preferences, tool-call noise, workflow desires → skill files, commands, settings.json, CLAUDE.md, auto-memory. **State lane:** durable session facts — open work, operational facts, decisions with rationale — routed into the project's canonical files (TODO.md, owning docs, CLAUDE.md, auto-memory, rationale home) so nothing is lost when the session ends. Handoff writes the temporary bridge file; calibrate gives facts a permanent home.

## When NOT to use

- Session was trivial (one tweak, one answer). Nothing to calibrate — say so in one line.
- You want a session bridge for a future session — use `handoff`.
- You want to author decisions or architecture rationale from scratch — that's `superpowers:writing-plans`. Routing an already-made decision to its rationale home is the state lane's job, not excluded here.
- Mid-task. Calibrate is a sweep, not a checkpoint.

## Mode detection

| Invocation | Mode | Scope |
|---|---|---|
| `/calibrate` | full | whole conversation context |
| `/calibrate --light` | light | last ~20 turns or last 5 user messages, whichever is smaller |

Light is for when tokens are tight or the session was short and you just want the obvious wins. Full is the default and should be preferred when you have headroom.

## Signal taxonomy

Only these types of signals are worth routing. Anything else is noise — drop it.

| Signal | Symptom | Likely target |
|---|---|---|
| Explicit correction | "no, do X instead", "stop doing Y" | feedback memory |
| Repeated correction | same correction landed 2+ times | feedback memory (high priority) |
| Preference statement | "I prefer X", "always do Y", "match this tone" | feedback or user memory |
| Voice / reply-style rule | "shorter replies", "stop summarizing", "don't praise" | CLAUDE.md Voice or Behavioral Guidelines |
| Tool-call noise | same permission prompt fired repeatedly | settings.json `permissions.allow` |
| Recurring automated action | "every time we deploy, do X", "before each commit, Y" | hook in settings.json (defer to `update-config`) |
| Skill misfire | invoked skill produced wrong output and user redirected | that skill's `SKILL.md` |
| Workflow desire | "make a command that does X" | new `~/.claude/commands/<name>.md` |
| Project fact (durable) | "the reason we're doing X is Y", "deadline is Z" | project memory |
| External resource pointer | "the dashboard is at Y", "tickets go to Z" | reference memory |
| User profile fact | role, expertise, knowledge gaps | user memory |

If a signal does not match any row above, do not propose it. The point of calibrate is the *route*: signal → target. No route, no proposal.

## What calibrate must NOT propose

Filter ruthlessly. Skip if:

- The signal is momentary task state (what file we're editing right now, mid-edit progress) with no bearing past this session — distinct from durable open work/next steps, which the state lane routes to a task file.
- The signal duplicates content already in CLAUDE.md, an existing memory file, or an existing skill. Read before proposing.
- The signal is a code pattern, git-history fact, or architectural shape — those are derivable by reading the repo.
- The signal is a one-off frustration with no signal of recurrence (user grumbled once, moved on).
- The signal is praise or hedging ("you're doing great", "this is fine"). Not durable.
- The signal would write a fix recipe for a specific bug. Fixes live in commits, not memory.

The auto-memory system's exclusion rules apply here verbatim. If the auto-memory rules would block writing it, calibrate must not propose it either.

## Routing rules

When a signal could plausibly land in multiple targets, prefer in this order:

1. **Skill** if it's a correction to a specific skill's instructions — the skill itself is the right home.
2. **Command** if the user described a recurring invocation they want as a slash-command.
3. **Settings hook** if it's an automated behavior ("from now on whenever X happens"). Hooks fire deterministically; memory only nudges.
4. **Settings permissions** if it's tool-call noise. The harness reads these.
5. **CLAUDE.md** if it's a global behavioral rule applying across all sessions in this workspace.
6. **Auto-memory** as the fallback for user/feedback/project/reference facts that don't belong in any of the above.

A signal goes in **one** place. No mirroring — see CLAUDE.md rule #10. If calibrate is about to propose the same change in two files, pick the canonical one and reference it from the other only if a reference is needed.

Scope stays in the current workspace: its CLAUDE.md and the auto-memory dir named in the system prompt. Other projects' state is off-limits unless the user explicitly named them.

### nadrbomz-managed targets

These paths are deployed copies. `nadrbomz.sh` overwrites them from GitHub on every run, so an edit made only there is lost and never reaches other hosts:

| Deployed path | Source in `~/dev/nadrbomz/` |
|---|---|
| `~/.claude/skills/<name>/` (except `synced/`) | `claude/skills/<name>/` |
| `~/.claude/commands/`, `~/.claude/scripts/` | `claude/commands/`, `claude/scripts/` |
| `~/.claude/statusline-command.sh` | `claude/statusline-command.sh` |
| `~/.claude/settings.json` | `claude/settings.json` |
| `~/dev/CLAUDE.md`, `~/dev/HOWTO.md` | `dev/CLAUDE.md`, `dev/HOWTO.md` |

When a target is in this table, edit the source, copy it over the deployed path so the change applies this session too, and commit in `~/dev/nadrbomz`. For `settings.json`, `update-config` writes the deployed file; apply the same change to the source, never copy the whole deployed file back (it can carry host-local drift such as a `/model` switch). If `~/dev/nadrbomz` is missing on this host, say so in the report instead of editing only the copy.

## State lane

The state lane extracts durable session facts and routes each into its canonical home, replacing what a HANDOFF.md would otherwise carry indefinitely.

**Sources:** the current session, plus `$PWD/HANDOFF.md` if present (else `$PWD/HANDOFF.md.bak` when the session is empty).

**Fact routing table:**

| Fact kind | Destination |
|---|---|
| Open work, next steps, watch items | task file (TODO.md or equivalent) |
| Operational facts: setup steps, cron tables, env vars | the runbook/doc owning that topic |
| Behavior/structure changes that make the playbook stale | CLAUDE.md |
| Constraint tied to one script/module | that file's usage()/comment, or its owning doc |
| User preferences, corrections, cross-project lessons, external URLs | auto-memory |
| Decisions + rationale | the project's rationale home (lessons log, commit message) |
| Already documented at destination | skip — verify it's current, don't duplicate |
| Derivable from repo/git, chronology | drop |

**Rules:** read the project's canonical files first (CLAUDE.md, TODO.md, README, owning docs, memory index) — the project's own rules win over the table; one owner per fact; rewrite in the destination's voice; update stale copies in place, never duplicate.

**Accountability gate:** every extracted fact ends in exactly one bucket — **routed** (path), **already documented** (path), or **dropped** (reason). State-lane items the user declined at pick time count as dropped with reason "user skipped". No fourth bucket; loop until the list is empty. The applied report includes this routing table.

**Bridge consumption:** if HANDOFF.md was a source and at least one state-lane item was applied, after applying run `mv -f -- HANDOFF.md HANDOFF.md.bak`; do not write a new HANDOFF.md. If every state-lane item was declined, leave HANDOFF.md in place.

## Workflow

### 1. Scope the scan

Take the scope from the mode table. Note cwd, which CLAUDE.md applies, and the auto-memory dir named in the system prompt.

### 2. Extract signals

Walk the scoped turns. For each candidate signal:

- Quote the user verbatim (1 short line, paraphrase only if quote would be too long).
- Tag with one signal type from the taxonomy above.
- Note whether it recurred (count occurrences). A single occurrence is fine to propose if it's an unambiguous preference statement.
- Drop anything that fails the "must not propose" filter.

### 3. Route + verify

For each surviving signal:

- Choose the target file using the routing rules, resolving nadrbomz-managed targets to their source.
- **Read the target file first.** No proposal touches a file you have not opened this session. This catches duplicates and ensures the diff fits the existing structure.
- Draft the change as a unified diff (for edits) or a complete new file body (for new memory entries / commands).
- For settings.json edits, hand off to the `update-config` skill — do not author hook/permission JSON directly inside calibrate. It knows the schema and won't break the file.

### 4. Present the sweep

State-lane items join the same numbered list as config-lane items. There is one sweep, one numbered list, one pick — not a separate list per lane.

The sweep is a menu, not an audit dump. One line per item: **bold what** gets saved, plain-words why, and where it lands. No verbatim quotes, no turn numbers, no occurrence counts, no diff fences, no file bodies — the drafted change from step 3 stays in your head until apply. If the user wants to see the exact text of an item before picking, show that one item on request.

Group items by theme — never mix unrelated kinds in one flat list. Typical themes: how to communicate (voice, formatting, question style), how to work (models, process, tooling), project state (TODO, docs, facts). Related signals within a theme that share one home merge into one item rather than fragmenting the menu.

Output exactly this structure:

```markdown
## calibrate — <date>

**<Theme>**
**1. <short bold title>** — <one plain sentence: what gets remembered/updated and why> → `<file>`

**<Theme>**
**2. ...**

Skipped: <one line naming the dropped signals, so the user can override>
```

Collect the pick via the AskUserQuestion tool: one question per theme (multiSelect when the theme has several items; a save/drop pair when it has one), option label = number + short title, description = the one-line summary. Free-text "Other" covers previews and edits.

Hard rules for this step:
- Cap at top 5 proposals. Long tail goes in "Skipped"; the user can ask for more in chat.
- Every proposal names its destination file (short path is fine; keep the absolute path for apply time).
- The one-line summary must say the substance ("save: subagents run on sonnet, haiku for trivia"), not a label ("save a model preference").
- Found nothing? Say so in one line and stop. Do not pad.

### 5. Apply

Never write before the user picks, even on `--light`. After the pick:

- Apply only the selected items, in the order listed.
- For new memory files: also update the memory `MEMORY.md` index per the auto-memory format. One index line per file.
- For skill edits: preserve frontmatter, do not bump version metadata.
- For CLAUDE.md: surgical edit, match existing style, no commentary added.
- Commit in each touched repo (including `~/dev/nadrbomz` for managed targets) per that project's commit conventions; never push.

Report back in one block. The two "state lane" lines complete the accountability gate (every extracted fact ends routed, already documented, or dropped) — omit a line only if that bucket was empty:

```markdown
Applied:
- <N>: <one-line summary, ending in the path written>
- ...

Skipped: <N>, <N>

Already documented (state lane): <path> — <fact>, ...
Dropped (state lane): <fact> — <reason>, ...

Files written: <count>. Files unchanged: <count>.
```

### 6. Stop

Do not summarize the session itself. Do not propose follow-up work. Calibrate's job ends when the diff lands.
