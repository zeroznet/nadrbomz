---
name: prototype
description: Use when the user wants to validate a design before committing to it — a state machine, data model, API shape, or UI layout that's hard to judge on paper. Routes between two branches: a terminal TUI for logic/state questions, or several radically different UI variants on one route for visual questions.
---

# prototype

## Purpose

A prototype is **throwaway code that answers a question.** The question decides the shape. Logic questions (does this state machine handle the edge cases?) get a tiny interactive TUI. Visual questions (what should this look like?) get N radically different variants on one route. Either way, the artifact is disposable; the *answer* is what's worth keeping.

## When to use

- Robert says `/prototype`, "prototype this", "let me play with it", "try a few designs", "I want to feel this out".
- A design decision is hard to judge without driving it — state transitions you can't reason about on paper, layouts you can't pick from a description.
- Sanity-checking a data model or API shape before committing.
- The cost of building the real thing wrong is higher than the cost of throwing a prototype away.

## When NOT to use

- The question is clear and the answer is obvious. Just build it.
- Bug investigation. Use `superpowers:systematic-debugging`.
- New feature with no prior thinking. Use `superpowers:brainstorming` first; come back if a prototype is still warranted.
- Architectural restructure. Use `ica`.
- The "prototype" would touch real data, real money, or production state. That isn't a prototype — that's a release.

## Pick a branch

Identify which question is being answered — from the user's prompt, the surrounding code, or by asking if the user is reachable:

- **"Does this logic / state model feel right?"** → [LOGIC.md](LOGIC.md). Tiny interactive terminal app that pushes the state machine through cases that are hard to reason about on paper.
- **"What should this look like?"** → [UI.md](UI.md). Several radically different UI variants on a single route, switchable via a URL search param and a floating bottom bar.

Branches produce very different artifacts — getting this wrong wastes the whole prototype. If the question is genuinely ambiguous and the user isn't reachable, default to whichever matches the surrounding code (backend module → logic; page or component → UI) and state the assumption at the top of the prototype.

## Rules that apply to both branches

1. **Throwaway from day one, marked as such.** Locate the prototype close to where it will actually be used (next to the module or page it's prototyping for) so context is obvious — but name it so a casual reader can see it's a prototype, not production. For throwaway UI routes, obey the project's existing routing convention; don't invent a new top-level structure.
2. **One command to run.** Whatever the project's task runner supports — `pnpm <name>`, `python <path>`, `bun <path>`, `sh script.sh`, `make <target>`. The user must be able to start it without thinking.
3. **No persistence by default.** State lives in memory. Persistence is the thing the prototype is *checking*, not something it should depend on. If the question explicitly involves a database, hit a scratch DB or a local file with a clear "PROTOTYPE — wipe me" name.
4. **Skip the polish.** No tests, no error handling beyond what makes the prototype runnable, no abstractions. The point is to learn something fast and then delete it.
5. **Surface the state.** After every action (logic) or variant switch (UI), print or render the full relevant state so the user can see what changed.
6. **Delete or absorb when done.** When the prototype has answered its question, either delete it or fold the validated decision into the real code. Don't leave it rotting.

## When done

The *answer* is the only thing worth keeping. Capture it where it will survive:

- A commit message on the absorbing change, if absorption is happening immediately.
- A `NOTES.md` next to the prototype if the answer needs to outlive the code before deletion.
- A new feedback/project memory via `calibrate` if the answer is a durable preference future sessions will need.
- A `HANDOFF.md` reference (via `handoff`) if the user is signing off before absorption — list the prototype's `NOTES.md` in #0 of the handoff.

If the user is around, that capture is a quick conversation. If not, leave a `NOTES.md` placeholder so they (or you, on the next pass) can fill in the verdict before deletion.

## Anti-patterns

- **No explicit question.** A prototype without a written-down question turns into general-purpose throwaway code that survives forever.
- **Polishing.** Tests, error handling, abstractions are signals the thing isn't a prototype anymore. Either commit to it as real code (with the standards real code earns) or strip it back.
- **Wiring to real systems.** Real DB, real API keys, real production endpoints turn "I'll just try this" into "I just took down staging". Stubs and local scratch only.
- **Promoting prototype code directly to production.** It was written under prototype constraints. Re-write the part worth keeping; do not lift the throwaway shell.
- **Letting it linger.** A prototype still in the repo a week after it answered its question is rot. Delete or absorb.
- **Picking the wrong branch.** A logic question answered with UI variants, or a UI question answered with a TUI, wastes the whole effort. Re-read the "Pick a branch" rule before writing code.

## Quick reference

| Question | Branch | Artifact |
|---|---|---|
| State / logic / data model | [LOGIC.md](LOGIC.md) | tiny TUI driving a portable logic module |
| Look / layout / visual | [UI.md](UI.md) | N variants on one route, floating switcher bar |

## Hand off

- Answer captured, prototype deleted → done.
- Answer captured, ready to fold into real code → `superpowers:test-driven-development` for the real implementation.
- Answer surfaced decisions worth saving → `calibrate` at session end.
- Signing off mid-prototype → `handoff` with the prototype's `NOTES.md` listed in #0.
