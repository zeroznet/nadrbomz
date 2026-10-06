---
name: ica
description: Diagnoses architectural friction across a whole repo (shallow modules, leaky boundaries, fragile seams, tangled data flow, inconsistent error handling, weak test surface, vocabulary drift, config sprawl, dormant code) and presents a ranked top-5 list of refactor candidates with file paths, then drills into one at a time on user pick. Diagnosis only, no code edits. Use when the user says "/ica", "improve architecture", "find refactor opportunities", "look for bad seams", or "make this more testable", or when changes keep touching many files for one concept.
argument-hint: "[lens,...]"
---

# ica

## Purpose

Surface architectural friction across the whole repo and propose **deepening opportunities**: refactors that turn shallow modules into deep ones, sharpen seams, repair leaky boundaries, and shrink the test surface to its real interface. Goal: testability, AI-navigability, locality of change.

**Diagnosis skill, not a fix skill.** Output is a ranked list of candidates with concrete file paths. The user picks; nothing gets rewritten in step one.

## When NOT to use

- Single-file refactor was requested explicitly. Just do it.
- Bug hunt. Use `superpowers:systematic-debugging`.
- Designing a new feature from scratch. Use `superpowers:brainstorming`.
- Repo under ~500 LOC. Eyeball it.

## Scope

Arguments narrow the run to the named lenses, by the keyword in parentheses in step 2: `/ica boundaries`, `/ica coupling,errors`, `/ica depth seams`. No argument means all ten.

## Glossary (internal analysis vocabulary — use these words while thinking; they never appear in the output)

- **Module**: anything with an interface and an implementation. Function, class, package, slice, route handler.
- **Interface**: everything a caller must know to use the module. Types, invariants, error modes, ordering, config. Not just the type signature.
- **Implementation**: the code inside.
- **Depth**: leverage at the interface. *Deep* means small interface, lots of behavior behind it. *Shallow* means interface nearly as complex as the implementation.
- **Seam**: where an interface lives. A place behavior can be altered without editing in place. Use this word, not "boundary".
- **Adapter**: a concrete thing satisfying an interface at a seam. *One adapter is a hypothetical seam. Two adapters is a real seam.*
- **Boundary**: a frontier between architectural layers (HTTP, domain, persistence, external). A leaky boundary is a layer whose types or concerns escape into another.
- **Locality**: change, bugs, knowledge concentrated in one place. The maintainer payoff of depth.
- **Leverage**: how much a caller gets from a small interface. The user payoff of depth.

**Deletion test**: imagine deleting the module. If complexity vanishes, it was a pass-through (kill it). If complexity reappears across N callers, it was earning its keep (keep it, deepen it).

## Workflow

### 1. Orient (cheap, mandatory)

Before exploring, read what already exists. Do not re-litigate decided things, and do not skip this because "I already know this codebase" — it may have changed.

In parallel:
- Read `CLAUDE.md` if present (project conventions and constraints).
- Glob top-level docs: `README*`, `ARCHITECTURE*`. Read what comes back. Do not invent files that are not there.
- `git log --since='3 months ago' --oneline | head -50`. Recently-changed paths flag hot spots. Stretch to 6 months on slow repos, 1 month on fast ones.
- Tree top two levels: `find . -maxdepth 2 -type d -not -path '*/.*' -not -path '*/node_modules*'`.
- Detect stack: `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, etc.

Output a one-paragraph **Orientation note** (max 6 lines): what this repo is, layers detected, top-level docs found, anything in `CLAUDE.md` that should narrow the search. Show it before exploring. Lift any project-specific vocabulary you find into the rest of the run.

### 2. Explore

For repos over ~5k LOC, dispatch the `Explore` subagent with the lenses in scope as the search prompt, explicitly requesting "very thorough" breadth so every lens covers multiple locations and naming conventions. For smaller repos, walk it inline.

Apply every lens in scope (all ten by default), not just depth. For each hit, capture: file path, 1-line friction note, lens.

1. **Depth** (`depth`): interface roughly equal to implementation? Pass-through wrappers? "Helper" modules called once?
2. **Seams** (`seams`): would adding a second adapter require gutting the first? Are seams faked (interface invented "for testability" but only one impl ever exists)?
3. **Boundaries** (`boundaries`): DB row types in HTTP handlers? Framework imports in pure domain? `req`/`res` reaching business logic? ORM models traveling outward unfiltered?
4. **Data flow** (`data`): can you trace one request, job, or event end-to-end in 3 files or fewer? Where does state mutate? Where does it transform? Hidden global stores?
5. **Error handling** (`errors`): one error model, or every layer reinvents? Errors swallowed (`catch {}`)? Errors rewrapped without added context? Sentinel errors mixed with thrown exceptions?
6. **Test surface** (`tests`): pure functions extracted *only* for testability while the real bugs live in how they are called? Modules with no tests because their interface is too painful to set up?
7. **Coupling and fan-out** (`coupling`): modules importing 20+ siblings? "God modules" everyone depends on? Cyclic imports?
8. **Vocabulary drift** (`vocabulary`): same concept named three ways (`Order` / `Job` / `Task`)? Domain words that disagree with the README or `CLAUDE.md`? Acronyms only one person remembers?
9. **Configuration sprawl** (`config`): config split across env vars, JSON, code constants, framework config, all reading from each other?
10. **Dormant code** (`dormant`): unused exports, dead branches, feature flags whose other side is never taken, TODOs older than 6 months.

Apply the **deletion test** to every depth and seam candidate. A "yes, deletion concentrates complexity" is the signal worth keeping. "This module is bad" without it is vibes, not analysis.

### 3. Rank (internal — never shown)

Before ranking: verify each candidate's decisive factual claim against the live file (open the cited path yourself — Explore summaries misreport). A candidate whose core claim does not survive direct reading is dropped or re-investigated, never presented anyway.

Rank by what fixing it buys versus what it costs, in your head. Biggest win for the least work goes first. No scoring tables, no shorthand codes — if you can't justify a candidate's position in one plain sentence, it doesn't belong in the list. Cap presentation at **top 5**. Drop the long tail; the user can ask for more.

### 4. Present candidates

The lenses, the deletion test, and the glossary are analysis tools — they never appear in the output. No lens names, no "deletion test" verdicts, no Impact/Effort/Confidence/Risk labels, no architecture jargon a reader would have to look up. Translate everything into plain sentences. Use the project's own vocabulary for domain terms.

Output exactly this structure (markdown). Numbered, scannable.

```
## ica: <repo name>

<1 short paragraph: what this repo is and where the friction concentrates>

### 1. <short title>
- **Where:** `path/to/a.ts`, `path/to/b.ts:42-87`
- **Problem:** <2 to 3 plain sentences a tired reader gets on first pass. Concrete. Cite a real call site if useful.>
- **Fix:** <what to do, plain English, no code yet>
- **Worth it because:** <one line — what gets easier, and roughly how big the change is (small edit / one file / touches N callers)>

### 2. ...

**Also noticed:** <one line listing the lower-priority hits so the user knows you saw them>
```

Collect the pick via the AskUserQuestion tool (multiSelect): one option per candidate, label = number + short title, description = the one-line problem. Free-text "Other" covers "none, go deeper on X". The markdown block above still renders in full before the tool call — the widget replaces any trailing "pick" prompt.

**Hard rules for step 4:**
- Never propose interface signatures, method names, or code. That is design-pass work.
- Never list more than 5 candidates in the main block.
- Every candidate must cite at least one concrete file path. "Consider SOLID" is not a candidate.
- Found nothing meaningful? Say so in one line. Do not pad.

### 5. Design pass (no ad-hoc loop — invoke a skill)

When the user picks a candidate, do NOT improvise a focused conversation inside ica. Hand off:

- **`align` (deep)** — the default. Walks the design tree: constraints, dependencies, the shape of the deepened module, what sits behind the seam, which tests survive, which die, which callers move.
- **`superpowers:brainstorming`** — when the candidate is open-ended design work (a new module shape, a feature-sized restructure) rather than a set of resolvable decisions.

Things that may happen during that pass:

- **Want to explore alternative interfaces?** Sketch 2 to 3 in plain English, run the deletion test against each, only then write code.
- **User rejects the candidate with a load-bearing reason?** Note the reason in your reply so the next ica run can avoid re-suggesting it. Do not write any persistence files unless the user asks.
- **A naming or vocabulary decision lands?** Mention it in the reply. Do not silently edit project docs — this skill is read-only unless the user explicitly asks.

### 6. Hand off (only when the user asks)

Once the design pass turns a candidate into a real plan, hand off:
- `superpowers:writing-plans` for non-trivial multi-step refactors.
- `superpowers:test-driven-development` if the test shape is changing.
- A direct edit if it is a one-file extraction.

Never silently start refactoring at the end of a design pass. Confirm with the user first.
