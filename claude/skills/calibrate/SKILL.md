---
name: calibrate
description: Use when a session has accumulated corrections, preferences, or repeated frustrations that should persist into future sessions. Sweeps the conversation, routes durable signals to the right destination (skill, command, CLAUDE.md, settings.json, auto-memory), proposes a numbered diff, applies only what the user picks.
---

# calibrate

## Purpose

Turn this session's hard-won lessons into durable configuration before they evaporate. Read the conversation, detect signals worth keeping (corrections, preferences, frustrations the user expressed more than once, tool noise that should have been allowlisted), and propose **applicable** updates with concrete file paths and diffs. User picks; calibrate applies. Nothing is written without consent.

Calibrate is the bridge between "I keep correcting Claude on the same thing" and "Claude already knows." It does not store activity logs, summaries, or context — only the *deltas* that future sessions need.

## When to use

- End of a session with multiple corrections or preference statements.
- After a frustrating debugging loop that revealed a missing permission, hook, or skill gap.
- After a long session where you noticed the same nudge being given more than once.
- Robert says `/calibrate`, `/calibrate --light`, "save what we learned", "polish the setup before I go".

## When NOT to use

- Session was trivial (one tweak, one answer). Nothing to calibrate.
- You want to capture *state* (what was built, where work resumed) — use `handoff` instead.
- You want to capture decisions and architecture rationale — that lives in commits, lessons logs, or `superpowers:writing-plans`, not here.
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

- The signal is ephemeral (current task state, in-progress work, what file we're editing right now).
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

## Workflow

### 1. Scope the scan

- Full mode: the entire conversation in context.
- Light mode: the most recent ~20 turns or the last 5 user messages, whichever is smaller.

Note current cwd and which CLAUDE.md / memory dir applies. The auto-memory dir for cwd is `~/.claude/projects/<urlencoded-dir>/memory/` — for `/home/zero/dev`, that resolves to `~/.claude/projects/-home-zero-dev/memory/`.

### 2. Extract signals

Walk the scoped turns. For each candidate signal:

- Quote the user verbatim (1 short line, paraphrase only if quote would be too long).
- Tag with one signal type from the taxonomy above.
- Note whether it recurred (count occurrences).
- Drop anything that fails the "must not propose" filter.

### 3. Route + verify

For each surviving signal:

- Choose the target file using the routing rules.
- **Read the target file first.** No proposal touches a file you have not opened this session. This catches duplicates and ensures the diff fits the existing structure.
- Draft the change as a unified diff (for edits) or a complete new file body (for new memory entries / commands).
- For settings.json edits, hand off to the `update-config` skill — do not author hook/permission JSON directly inside calibrate.

### 4. Present the sweep

Output exactly this structure:

```markdown
## calibrate sweep — <date>, mode: <full|light>

Scanned: <N> turns. Signals kept: <K>. Dropped: <D> (one-off / duplicate / ephemeral).

### 1. <signal type> — <short title>
- **Signal:** "<verbatim user quote>" (~turn <N>, occurred <X>×)
- **Target:** `<absolute file path>` (<new file | existing section>)
- **Change:**
  ```diff
  - <old line>
  + <new line>
  ```
  *(or, for new files, show the full intended body in a fenced block)*
- **Why durable:** <one short clause>

### 2. ...

**Skipped (low value):** <one line listing the dropped signals so the user can override>

**Pick:** numbers, or "all", or "all except 2,4", or "none".
```

Hard rules for this step:
- Cap at top 7 proposals. Long tail goes in "Skipped" as a one-liner per item.
- Every proposal cites an absolute path.
- Every proposal shows the actual change, not a paraphrase ("update the Voice section" is not enough — show the diff).
- Found nothing? Say so in one line and stop. Do not pad.

### 5. Apply

After the user picks:

- Apply only the selected items, in the order listed.
- For new memory files: also update the memory `MEMORY.md` index per the auto-memory format. One index line per file.
- For settings.json: delegate to `update-config`.
- For skill edits: preserve frontmatter, do not bump version metadata.
- For CLAUDE.md: surgical edit, match existing style, no commentary added.

Report back in one block:

```markdown
Applied:
- <N>: <one-line summary, ending in the path written>
- ...

Skipped: <N>, <N>

Files written: <count>. Files unchanged: <count>.
```

### 6. Stop

Do not summarize the session itself. Do not propose follow-up work. Calibrate's job ends when the diff lands.

## Anti-patterns

- **Proposing memory for a one-off frustration.** If the user complained once and moved on, drop it.
- **Mirroring the same rule into CLAUDE.md and memory.** Pick one canonical home. Memory `[[link]]` to CLAUDE.md if needed.
- **Writing without reading.** Every target file must be opened first; otherwise the diff is a guess.
- **Authoring settings.json directly.** Hand off to `update-config`. That skill knows the schema and won't break the file.
- **Long proposals.** A proposal is one signal → one diff. Multi-signal bundles hide intent and make pick-by-number unreliable.
- **Padding when nothing changed.** Trivial session, no signals — say so in one line, no shame in stopping.
- **Auto-applying.** Never write before the user picks, even on `--light`. The pick step is the whole point.
- **Touching projects outside cwd.** Calibrate scopes to the current workspace's CLAUDE.md and `~/.claude/projects/<urlencoded-dir>/memory/`. Other projects' state is off-limits unless the user explicitly named them.

## Quick reference

| Step | Output | Notes |
|---|---|---|
| 1. Scope | mode + path map | 1 line |
| 2. Extract | raw signal list | internal, not shown |
| 3. Route + verify | proposals with diffs | reads target files |
| 4. Present | numbered top-7 sweep | hard cap |
| 5. Apply | edits + summary | only on user pick |
| 6. Stop | nothing | no follow-up suggestions |

## Tuning

- **Light cap:** 20 turns / 5 user messages. Adjust down if the session was small.
- **Top-N:** 7 proposals. User can ask for more in chat ("show me 5 more") — keep the default scannable.
- **Recurrence threshold:** mention occurrence count when ≥2. Single occurrence is fine to propose if it's an unambiguous preference statement.
- **CLAUDE.md target:** the project-level CLAUDE.md (in cwd) by default. Touch `~/.claude/CLAUDE.md` only if the rule is truly user-global and the project is `~/dev` itself.
