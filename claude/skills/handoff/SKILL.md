---
name: handoff
description: Use when the user wants to end a session and hand off to a future session, OR when invoked in an empty session to restore prior context from HANDOFF.md, OR when invoked with --apply to fold the durable session/handoff content into the project's canonical files and memory.
argument-hint: "[--md | --apply] [focus the next session will pick up]"
---

# handoff

## Purpose

Bridge sessions. End-of-session: capture the *durable* output (decisions, current state, next move) into `$PWD/HANDOFF.md` so a fresh session can resume without reading the transcript. Start-of-session: if `$PWD/HANDOFF.md` exists and there's nothing else going on, source it as context and delete it. With `--apply`: skip the bridge entirely — dissolve the durable content into the project's own canonical files and memory so nothing depends on a HANDOFF.md surviving.

A handoff is **not** a chronology, recap, or compact summary.

## Mode detection (do this first)

- **Apply mode** — arguments contain `--apply`. Go to *Apply mode*. Overrides the other two modes regardless of session state.
- **Read mode** — current session has no meaningful content yet (the `/handoff` invocation is essentially the first/only turn) AND `$PWD/HANDOFF.md` exists. Go to *Read mode*.
- **Write mode** — otherwise. Go to *Write mode*.

If both conditions are ambiguous (e.g., a HANDOFF.md exists but the session has work), default to write mode and warn that an existing HANDOFF.md will be overwritten.

## Read mode

1. Read `$PWD/HANDOFF.md`.
2. Print it back to the user inside a ```` ```markdown ```` fenced block so it's clearly the restored context.
3. Move the file to a single-level backup: `mv -f -- HANDOFF.md HANDOFF.md.bak`. Always one backup, no rolling history. Any prior `HANDOFF.md.bak` is overwritten silently.
4. One short confirmation line: `restored from HANDOFF.md (backed up to HANDOFF.md.bak)`.
5. Wait for the next instruction. Do not start executing the next steps from the handoff unless the user asks.

## Apply mode (`--apply`)

Goal: **zero loss, zero bridge.** Every durable fact from the current session and/or an existing `HANDOFF.md` ends up in the project's own canonical structure — repo files or memory — so nothing depends on a HANDOFF.md surviving. Write mode persists a snapshot; apply mode dissolves it into permanent homes.

### Sources

- The current session, if it has meaningful content.
- `$PWD/HANDOFF.md` if present; else `$PWD/HANDOFF.md.bak` if the session is empty (a restore already happened or the bridge was consumed earlier).
- Neither has content → reply `nothing to apply` and stop.

### Procedure

1. **Extract.** Mentally draft the same #0–#6 content write mode would produce (skip #7), from all sources combined. The write-mode filter-OUT rules apply unchanged.
2. **Learn the structure.** Before routing anything, read the project's canonical files: CLAUDE.md (conventions, repo map, documentation rules), TODO.md or the project's task file, README, the docs/runbooks the facts touch, and the auto-memory index. The project's own rules govern where each kind of fact lives — never assume a generic layout.
3. **Route — one owner per fact.** Default map; the project's own rules win over this table:

   | Fact kind | Destination |
   |---|---|
   | Open work, next steps, watch items | task file (TODO.md or equivalent) |
   | Operational facts: setup steps, cron tables, env vars | the runbook/doc owning that topic |
   | Behavior/structure changes that make the playbook stale | CLAUDE.md |
   | Constraint tied to one script/module | that file's usage()/comment, or its owning doc |
   | User preferences, corrections, cross-project lessons, external URLs | auto-memory |
   | Decisions + rationale | the project's rationale home (lessons log, commit message) |
   | Already documented at destination | skip — verify it's current, don't duplicate |
   | Derivable from repo/git, chronology, #7-type pointers | drop |

   Rewrite each fact in the destination's voice and granularity — a handoff bullet pasted verbatim into TODO.md is a smell. Respect the destination's own anti-rot rules (no incident dates in a playbook, no status snapshots in a README).
4. **Check before writing.** Read the destination section first. If the fact already exists in stale form, update it in place. Never create a second copy of state that already has an owner.
5. **Accountability gate.** Walk the extracted facts once more. Each must land in exactly one bucket: **routed** (destination path), **already documented** (path), or **dropped** (reason). There is no fourth bucket. An unaccounted fact means the pass is not done — loop until the list is empty.
6. **Consume the bridge.** If `HANDOFF.md` was a source: `mv -f -- HANDOFF.md HANDOFF.md.bak`. Do not write a new HANDOFF.md.
7. **Commit.** In each repo touched, commit the edits per that project's commit conventions, grouped logically. Do **not** push unless the project's rules or the user authorize pushes — the gitignore-push rule from write mode does not extend here.
8. **Report.** A routing table — every fact with its bucket and destination path or drop reason — replaces the one-line confirmation. The user must be able to audit that nothing was silently lost.

### Flags & arguments

- `--apply` overrides `--md`; the structure-learning in step 2 subsumes the sibling scan.
- Apply mode takes no focus argument; non-flag arguments are ignored.

## Write mode

### `--md` flag (optional)

If invoked as `/handoff --md`, run a sibling-scan pass before drafting:

1. Enumerate `*.md` in cwd, shallow only (no subdirectories), excluding `HANDOFF.md` itself:
   ```sh
   find . -maxdepth 1 -type f -name '*.md' ! -name HANDOFF.md
   ```
2. Read each file fully.
3. In #0 Reference map, list every consulted file with a leading `✓` marker and a one-line note on what it covers. The `✓` distinguishes "I read this file this session" from files merely referenced.
4. While drafting #1–#6, if a fact is already documented in a consulted file, replace the restatement with a pointer (`see PLAN.md #3`). A one-sentence summary plus pointer is fine; anything longer becomes a pointer only.
5. Add a dedup pass to the Procedure (see step 4 below).

Without `--md`, skip this scan; #0 still applies but no `✓` markers appear.

### Focus argument (optional)

Anything in the slash-command arguments that does *not* start with `--` is treated as a one-line **focus** for the next session — what it should pick up. Examples:

- `/handoff "ship the rotation feature tomorrow"`
- `/handoff --md "investigate the rate-limit bug"`

When a focus is present:

- **#1 Goal** opens with the focus, then states how the current session left things relative to it.
- **#5 Next Steps** is ordered around the focus first; unrelated work moves down.
- **#7 Suggested skills** weights toward what the focus will need (e.g. `superpowers:executing-plans` if there's already a plan; `align deep` if scope is open; `ica` if the focus is "make this less of a mess").
- Other sections are unchanged.

Without a focus, write the handoff as the durable snapshot it is and let #7 suggest skills based on the leftover state.

### Output target

- Write the handoff to `$PWD/HANDOFF.md` (overwrite if present).
- Do **not** also print the document to chat. After writing, give a one-line confirmation: path written, plus a short list of repos whose `.gitignore` was updated and pushed.

### Gitignore + push (after writing the file)

For every git repo found under cwd:

```sh
find . -type d -name .git -prune | sed 's|/\.git$||'
```

For each repo:
1. If its `.gitignore` does not already contain a line `HANDOFF.md`, append one. Same check for `HANDOFF.md.bak` — append if missing. The `.bak` line is needed because Read mode leaves a single-level backup behind.
2. If `.gitignore` was changed:
   - `git -C <repo> add .gitignore`
   - `git -C <repo> commit -m "ignore HANDOFF.md"`
   - `git -C <repo> push` — tolerate failure (no remote, auth, detached HEAD, dirty tree blocking commit). Report failures briefly; do not retry destructively.
3. Skip repos with no remote configured (no push attempted) and note them in the confirmation line.

Never `git add -A`, never push to a branch other than the current one, never force-push.

### What to include in HANDOFF.md

These sections, in this order. Omit any section that genuinely has nothing to say — don't pad. **#0 is mandatory and cannot be omitted.**

#### 0. Reference map (mandatory)

Every file path, doc, runbook, spec, plan, or external resource the next session must read or might want to consult. Annotate each with what it covers and what section/topic came up this session. Frozen docs included — frozen makes them MORE durable as references, not less. Live-truth files (CLAUDE.md, TODO.md, agent-specific dirs, memory/, routines/, settings) listed even when "obvious."

If you would tell a teammate "go read X to understand this," X belongs here.

When the `--md` flag was used: prefix each file actually read this session with `✓ ` so the next session can see the dedup audit trail at a glance. Files merely referenced (not opened) appear without the marker.

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

1. **(`--md` only)** Run the sibling-scan from the `--md` section above: enumerate `*.md` shallow in cwd, read each, prepare the `✓`-marked entries for #0.
2. Mentally scan the session for decisions, state changes, and constraints. Ignore everything else.
3. Draft the document in the structure above.
4. **(`--md` only) Dedup pass.** Walk the draft line by line. For each fact, check whether it is already documented in a consulted file. If yes, replace with a pointer (`see PLAN.md #3`). A one-sentence summary plus pointer is fine; longer restatements collapse to pointer only. Never delete a path during dedup — paths are exempt.
5. Re-read your draft and delete any line that fails the test: *"Would the next session reach a different/worse outcome without this?"* If no, cut it. **This filter does not apply to file paths — see the path rule above and the gate below.**
6. **Pre-write self-check gate.** Before saving, verify each box. If any is unchecked, add the missing items:
   - [ ] Every spec/plan/RFC referenced in this session is listed in #0 by path
   - [ ] Every runbook the next session might need is listed in #0 by path
   - [ ] Every live-truth file (CLAUDE.md, TODO.md, memory/, routines/, config files) the next session must read is listed in #0
   - [ ] Every external URL discussed (dashboards, tickets, vendor docs) is listed in #0
   - [ ] **(`--md` only)** Every `*.md` file returned by the shallow scan is listed in #0 with a `✓` marker, even if it turned out to contain nothing relevant (note it as `✓ NAME.md — scanned, nothing relevant` so the next session knows it was checked, not missed)
   - [ ] If a focus arg was passed, #1 Goal opens with it and #5 Next Steps is reordered around it
   - [ ] #7 Suggested skills lists 0–3 skills with one-line reasons (empty section omitted entirely, not left as a stub)

   This check overrides the "cut anything that isn't durable" rule from step 5. Paths are exempt from that filter.
7. Write the result to `$PWD/HANDOFF.md`.
8. Update `.gitignore` and push for each git repo under cwd as described above.
9. Reply with one line: `wrote HANDOFF.md; gitignore updated in: <repo list>` (or `gitignore already up to date` if none changed). When `--md` was used, append `; consulted N md file(s)`.

### Example

A minimal good handoff (illustrative, not a template to copy literally):

```markdown
## 0. Reference map
- `specs/auth-rotation.md` #3.2 — token-rotation contract; this session implemented #3.2 case (b) only
- `runbooks/incident-2026-04-12-auth.md` — postmortem the rotation work derives from (frozen)
- `CLAUDE.md` — repo conventions; #"Commits" governs the commit style used here
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

Notice: #0 lists paths first, every later section refers back to those paths by relative position (#3.2, file paths, dashboard URL), and frozen docs are cited normally.
