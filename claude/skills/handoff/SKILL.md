---
name: handoff
description: Writes HANDOFF.md in cwd so a fresh session can continue without the transcript. It holds a reference map of every file and URL the next session needs, plus goal, decisions, current state, gotchas, next steps, and open questions. With --apply, reads an existing HANDOFF.md back as context instead. Run at session end (after /calibrate), or with --apply at the start of the next one.
argument-hint: "[--apply] [focus the next session will pick up]"
disable-model-invocation: true
---

# handoff

## Purpose

Bridge sessions, nothing more. Two modes:

- **Write mode (default).** End-of-session: capture the *durable* output (decisions, current state, next move) into `$PWD/HANDOFF.md` and print it into chat, so a fresh session — or the current one — can pick it up without reading the transcript.
- **Restore mode (`--apply`).** Start-of-session: read back an existing `$PWD/HANDOFF.md` as context.

Folding session content into the project's own canonical files (TODO.md, CLAUDE.md, runbooks, memory) is `calibrate`'s job, not this skill's.

A handoff is **not** a chronology, recap, or compact summary.

## Mode detection (do this first)

- Arguments contain `--apply` → **restore mode**. Go to *Restore mode*.
- Otherwise → **write mode**. Go to *Write mode*.

There is no auto-detection of an empty session; restore only runs when `--apply` is passed explicitly.

## Restore mode (`--apply`)

1. Read `$PWD/HANDOFF.md`. If missing, fall back to `$PWD/HANDOFF.md.bak` with a note that no fresh HANDOFF.md was found. If neither exists, reply `nothing to restore` and stop.
2. Print the document back to the user inside a ```` ```markdown ```` fenced block so it's clearly the restored context.
3. Move the file to a single-level backup: `mv -f -- HANDOFF.md HANDOFF.md.bak`. Always one backup, no rolling history. Any prior `HANDOFF.md.bak` is overwritten silently. Skip this step when the source read was already `HANDOFF.md.bak` — there's nothing new to back up.
4. One short confirmation line: `restored from HANDOFF.md (backed up to HANDOFF.md.bak)`.
5. Wait for the next instruction. Do not start executing the next steps from the handoff unless the user asks.

## Write mode

### Sibling scan

Before drafting, enumerate `*.md` in cwd, shallow only (no subdirectories), excluding `HANDOFF.md` itself:

```sh
find . -maxdepth 1 -type f -name '*.md' ! -name HANDOFF.md
```

Read each file fully. Every one goes into #0 with a `✓` marker; facts they already document become pointers during the dedup pass (Procedure step 4).

### Focus argument (optional)

Anything in the slash-command arguments that does *not* start with `--` is treated as a one-line **focus** for the next session — what it should pick up. Examples:

- `/handoff "ship the rotation feature tomorrow"`
- `/handoff "investigate the rate-limit bug"`

When a focus is present:

- **#1 Goal** opens with the focus, then states how the current session left things relative to it.
- **#5 Next Steps** is ordered around the focus first; unrelated work moves down.
- **#7 Suggested skills** weights toward what the focus will need (e.g. `superpowers:executing-plans` if there's already a plan; `align deep` if scope is open; `ica` if the focus is "make this less of a mess").
- Other sections are unchanged.

Without a focus, write the handoff as the durable snapshot it is and let #7 suggest skills based on the leftover state.

### Git exclude

Keep HANDOFF.md out of git without touching any tracked file. Only the repo that contains `$PWD` matters; when cwd is in no repo, this is a no-op. Run exactly:

```sh
if exclude="$(git rev-parse --git-path info/exclude 2>/dev/null)"; then
  mkdir -p "$(dirname "$exclude")"
  for pattern in HANDOFF.md HANDOFF.md.bak; do
    grep -qxF "$pattern" "$exclude" 2>/dev/null || printf '%s\n' "$pattern" >> "$exclude"
  done
fi
```

The `.bak` line covers the single-level backup restore mode leaves behind. **No git add, no commit, no push.**

### What to include in HANDOFF.md

These sections, in this order. Omit any section that genuinely has nothing to say — don't pad. **#0 is mandatory and cannot be omitted.**

#### 0. Reference map (mandatory)

Every file path, doc, runbook, spec, plan, or external resource the next session must read or might want to consult. Annotate each with what it covers and what section/topic came up this session. Frozen docs included — frozen makes them MORE durable as references, not less. Live-truth files (CLAUDE.md, TODO.md, agent-specific dirs, memory/, routines/, settings) listed even when "obvious."

If you would tell a teammate "go read X to understand this," X belongs here.

Prefix each file actually read this session (via the sibling scan) with `✓ ` so the next session can see the dedup audit trail at a glance. Files merely referenced (not opened) appear without the marker.

#### 1. Goal
One or two sentences. What is the user trying to accomplish across this work? State it as if the next session has never heard of it.

#### 2. Decisions
The decisions made and *why*. Each entry: the choice, alternatives considered (briefly), and the reason this one won. A future session should be able to defend these decisions without re-deriving them. Include decisions that constrain the design space, even if they feel "obvious" now.

#### 3. Current State
What exists right now that didn't before, or what changed. File paths, function names, configuration keys, schema shapes — concrete artifacts the next session can locate. If a system has parts working and parts not, say which.

"Frozen" or "historical" status of a doc is NOT a reason to omit its path. Frozen docs are stable references — exactly what handoffs are for. Decisions made with reference to a spec section must cite that section by path + section number.

#### 4. Constraints & Gotchas
Non-obvious things the next session must know to avoid breaking something or repeating dead ends:
- Hidden invariants ("X must run before Y or Z silently fails")
- Environment specifics ("only reproduces with node 22+")
- Things that look wrong but are intentional
- Dead ends discovered (only if they reveal a constraint — otherwise drop)

#### 5. Next Steps
The immediate next move, ordered. Specific enough to execute: file to touch, command to run, question to resolve. Not "continue work" — what *exactly*.

#### 6. Open Questions
Things the user hasn't decided yet, that the next session will need to ask before proceeding.

#### 7. Suggested skills for next session
Which skills the next session should reach for, and why. Two or three at most — this is a pointer, not a curriculum. Format: `` `skill-name` — one short reason ``. Example:

- `superpowers:executing-plans` — `docs/plans/rotation-3.2b.md` is ready to execute
- `align deep` — #6 has two open decisions the implementation hinges on
- `calibrate` — session generated corrections worth saving before they evaporate

Skip the section entirely if nothing useful comes to mind — empty pointers are noise.

### What to filter OUT

- **Chronology** — "first we tried X, then Y, then Z." Only the final decision matters.
- **Trivial fixes** — typos, formatting, lint cleanup, renaming a variable.
- **Q&A history** — "user asked about X, I explained Y." If it didn't change direction, it's not durable.
- **Tool-call play-by-play** — "ran grep, found 3 results, read file." The result is in Current State; the search isn't.
- **Abandoned attempts** — unless they revealed a constraint that's now in #4.
- **Restating CLAUDE.md content** — the next session reads it the same way. (But its *path* still belongs in #0.)
- **Praise, hedging, narration** — "we made great progress" adds nothing.

**Never filter file paths.** A path is not "obvious" or "the next session will find it." Paths are the cheapest, most lossless thing you can persist. When in doubt, include the path. Cut a sentence about a path before you cut the path itself.

### Style

- Terse. Bullets over prose. No introduction, no conclusion.
- Concrete nouns: file paths, function names, exact strings. Not "the config" — `src/config.ts:loadEnv()`.
- Write for someone who has the codebase and CLAUDE.md but zero memory of this conversation.
- If the whole session was one trivial change, say so in one line and stop. Length should match substance.

### Procedure

1. Run the sibling scan above and prepare the `✓`-marked entries for #0.
2. Mentally scan the session for decisions, state changes, and constraints. Ignore everything else.
3. Draft the document in the structure above.
4. **Dedup pass.** Walk the draft line by line. For each fact, check whether it is already documented in a consulted file. If yes, replace with a pointer (`see PLAN.md #3`). A one-sentence summary plus pointer is fine; longer restatements collapse to pointer only. Never delete a path during dedup — paths are exempt.
5. Re-read your draft and delete any line that fails the test: *"Would the next session reach a different/worse outcome without this?"* If no, cut it. **This filter does not apply to file paths — see the path rule above and the gate below.**
6. **Pre-write self-check gate.** Before saving, verify each box. If any is unchecked, add the missing items:
   - [ ] Every spec/plan/RFC referenced in this session is listed in #0 by path
   - [ ] Every runbook the next session might need is listed in #0 by path
   - [ ] Every live-truth file (CLAUDE.md, TODO.md, memory/, routines/, config files) the next session must read is listed in #0
   - [ ] Every external URL discussed (dashboards, tickets, vendor docs) is listed in #0
   - [ ] Every `*.md` file returned by the shallow scan is listed in #0 with a `✓` marker, even if it turned out to contain nothing relevant (note it as `✓ NAME.md — scanned, nothing relevant` so the next session knows it was checked, not missed)
   - [ ] If a focus arg was passed, #1 Goal opens with it and #5 Next Steps is reordered around it
   - [ ] #7 Suggested skills lists 0–3 skills with one-line reasons (empty section omitted entirely, not left as a stub)

   This check overrides the "cut anything that isn't durable" rule from step 5. Paths are exempt from that filter.
7. Write the result to `$PWD/HANDOFF.md` (overwrite if present), then print the full document to chat inside a ```` ```markdown ```` fenced block.
8. Run the git exclude snippet above. No commit, no push.
9. Reply with one line: `wrote HANDOFF.md; consulted N md file(s); git exclude: <added|already set|not in a repo>`.

### Example

A minimal good handoff (illustrative, not a template to copy literally):

```markdown
## 0. Reference map
- ✓ `CLAUDE.md` — repo conventions; #"Commits" governs the commit style used here
- ✓ `TODO.md` — scanned, nothing relevant
- `specs/auth-rotation.md` #3.2 — token-rotation contract; this session implemented #3.2 case (b) only
- `runbooks/incident-2026-04-12-auth.md` — postmortem the rotation work derives from (frozen)
- `src/auth/rotator.ts` — new module added this session
- `src/auth/index.ts` — entrypoint, now re-exports `rotateToken`
- https://dash.internal/auth-latency — oncall dashboard; rotation should not regress p99

## 1. Goal
Land token rotation per `specs/auth-rotation.md` #3.2(b), without regressing the latency dashboard above.

## 2. Decisions
- Used a per-tenant clock instead of global. Alternative (global clock) rejected because spec #3.2(b) requires tenant isolation under partial outage.

## 3. Current State
- `src/auth/rotator.ts:rotateToken()` implements #3.2(b). #3.2(a) and (c) NOT started.
- Tests in `src/auth/rotator.test.ts` cover happy path; failure paths TODO.

## 5. Next Steps
1. Add failure-path tests in `src/auth/rotator.test.ts` (network drop, clock skew).
2. Implement #3.2(a) — same module.
3. Verify p99 on the dashboard URL above before merging.
```

Notice: #0 lists paths first with the scanned `*.md` marked `✓`, every later section refers back to those paths by relative position (#3.2, file paths, dashboard URL), and frozen docs are cited normally.

## Hand off

Session also produced corrections or durable facts worth folding into project files → run `calibrate` before `/handoff`.
