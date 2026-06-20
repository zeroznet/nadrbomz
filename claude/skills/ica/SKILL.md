---
name: ica
description: Use when reviewing a repo for end-to-end architectural improvements. Covers depth, shallow modules, leaky boundaries, fragile seams, tangled data flow, inconsistent error handling, weak test surface, vocabulary drift, configuration sprawl, dormant code. Diagnosis only; produces a ranked candidate list, then drills into one at a time on user pick.
---

# ica

## Purpose

Surface architectural friction across the whole repo and propose **deepening opportunities**: refactors that turn shallow modules into deep ones, sharpen seams, repair leaky boundaries, and shrink the test surface to its real interface. Goal: testability, AI-navigability, locality of change.

**Diagnosis skill, not a fix skill.** Output is a ranked list of candidates with concrete file paths. The user picks; nothing gets rewritten in step one.

## When to use

- Robert says `/ica`, "improve architecture", "find refactor opportunities", "look for bad seams", "make this more testable".
- After a feature lands, before next sprint.
- Onboarding a new collaborator (or a future Claude session) onto the codebase.
- Changes keep touching N files for what feels like one concept.

## When NOT to use

- Single-file refactor was requested explicitly. Just do it.
- Bug hunt. Use `superpowers:systematic-debugging`.
- Designing a new feature from scratch. Use `superpowers:brainstorming`.
- Repo under ~500 LOC. Eyeball it.

## Glossary (use these words; do not drift)

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

Before exploring, read what already exists. Do not re-litigate decided things.

In parallel:
- Read `CLAUDE.md` if present (project conventions and constraints).
- Glob top-level docs: `README*`, `ARCHITECTURE*`. Read what comes back. Do not invent files that are not there.
- `git log --since='3 months ago' --oneline | head -50`. Recently-changed paths flag hot spots.
- Tree top two levels: `find . -maxdepth 2 -type d -not -path '*/.*' -not -path '*/node_modules*'`.
- Detect stack: `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, etc.

Output a one-paragraph **Orientation note** (max 6 lines): what this repo is, layers detected, top-level docs found, anything in `CLAUDE.md` that should narrow the search. Show it before exploring. Lift any project-specific vocabulary you find into the rest of the run.

### 2. Explore

For repos over ~5k LOC, dispatch the `Explore` subagent with the lenses below as the search prompt. For smaller repos, walk it inline.

Apply **all ten lenses**, not just depth. For each hit, capture: file path, 1-line friction note, lens.

1. **Depth**: interface roughly equal to implementation? Pass-through wrappers? "Helper" modules called once?
2. **Seams**: would adding a second adapter require gutting the first? Are seams faked (interface invented "for testability" but only one impl ever exists)?
3. **Boundaries**: DB row types in HTTP handlers? Framework imports in pure domain? `req`/`res` reaching business logic? ORM models traveling outward unfiltered?
4. **Data flow**: can you trace one request, job, or event end-to-end in 3 files or fewer? Where does state mutate? Where does it transform? Hidden global stores?
5. **Error handling**: one error model, or every layer reinvents? Errors swallowed (`catch {}`)? Errors rewrapped without added context? Sentinel errors mixed with thrown exceptions?
6. **Test surface**: pure functions extracted *only* for testability while the real bugs live in how they are called? Modules with no tests because their interface is too painful to set up?
7. **Coupling and fan-out**: modules importing 20+ siblings? "God modules" everyone depends on? Cyclic imports?
8. **Vocabulary drift**: same concept named three ways (`Order` / `Job` / `Task`)? Domain words that disagree with the README or `CLAUDE.md`? Acronyms only one person remembers?
9. **Configuration sprawl**: config split across env vars, JSON, code constants, framework config, all reading from each other?
10. **Dormant code**: unused exports, dead branches, feature flags whose other side is never taken, TODOs older than 6 months.

Apply the **deletion test** to every depth and seam candidate. A "yes, deletion concentrates complexity" is the signal worth keeping.

### 3. Score and rank

Before scoring: verify each candidate's decisive factual claim against the live file (open the cited path yourself — Explore summaries misreport). A candidate whose core claim does not survive direct reading is dropped or re-investigated, never scored down and presented.

For each candidate, assign:

| Field | Scale | Meaning |
|---|---|---|
| Impact | 1–5 | How much does fixing this improve locality, leverage, test surface? |
| Effort | 1–5 | Diff size, how many callers move, how much of the test suite moves with it. |
| Confidence | L/M/H | How sure are you the proposed change is right? L means it needs a design pass (`align`) first. |
| Risk | L/M/H | Likelihood of breaking unrelated things. |

Rank by `Impact / Effort` first, break ties with Confidence. Cap presentation at **top 7**. Drop the long tail; the user can ask for more.

### 4. Present candidates

Output exactly this structure (markdown). Numbered, scannable. Use the project's own vocabulary (whatever names the README / `CLAUDE.md` / code uses) for domain terms; use the glossary above for architecture terms.

```
## ica candidates: <repo name>

**Orientation:** <1 paragraph from step 1>

**Top N opportunities** (Impact/Effort, ranked):

### 1. <short title>  Impact 4 / Effort 2 / Conf H / Risk L
- **Files:** `path/to/a.ts`, `path/to/b.ts:42-87`
- **Lens:** Depth + Boundary
- **Problem:** <2 to 4 sentences. Concrete. Cite a real call site if useful.>
- **Deletion test:** <what happens if you delete it; concentrates or moves complexity?>
- **Proposed deepening:** <plain English. No code yet. Use the project's existing vocabulary; if you have to invent a name, flag it.>
- **Benefit:** <locality, leverage, test surface; in that order>

### 2. ...

**Skipped (long tail):** <one line listing 3 to 10 lower-priority hits so the user knows you saw them>

**Pick:** which would you like to take into a design pass? (numbers, or "all", or "none, go deeper on X")
```

**Hard rules for step 4:**
- Never propose interface signatures, method names, or code.
- Never list more than 7 candidates in the main block.
- Every candidate must cite at least one concrete file path.
- Found nothing meaningful? Say so in one line. Do not pad.

### 5. Design pass (no ad-hoc loop — invoke a skill)

When the user picks a candidate, do NOT improvise a focused conversation inside ica. Hand off:

- **`align` (deep)** — the default. Walks the design tree: constraints, dependencies, the shape of the deepened module, what sits behind the seam, which tests survive, which die, which callers move.
- **`superpowers:brainstorming`** — when the candidate is open-ended design work (a new module shape, a feature-sized restructure) rather than a set of resolvable decisions.

Things that may happen during that pass:

- **Want to explore alternative interfaces?** Sketch 2 to 3 in plain English, run the deletion test against each, only then write code.
- **User rejects the candidate with a load-bearing reason?** Note the reason in your reply so the next ica run can avoid re-suggesting it. Do not write any persistence files unless the user asks.
- **A naming or vocabulary decision lands?** Mention it in the reply. Do not silently edit project docs.

### 6. Hand off (only when the user asks)

Once the design pass turns a candidate into a real plan, hand off:
- `superpowers:writing-plans` for non-trivial multi-step refactors.
- `superpowers:test-driven-development` if the test shape is changing.
- A direct edit if it is a one-file extraction.

Never silently start refactoring at the end of a design pass. Confirm with the user first.

## Anti-patterns

- **Dumping 30 candidates.** That is data, not analysis. Cap at 7.
- **Generic advice.** "Consider SOLID" is not a candidate. A candidate has files, lines, and a deletion test.
- **Inventing interfaces in step 4.** That is design-pass (`align`) work. Step 4 names problems.
- **"This module is bad"** without the deletion test. Vibes, not analysis.
- **Skipping orientation** because "I already know this codebase". Read what the repo actually has now, it may have changed.
- **Writing or editing project docs unprompted.** This skill is read-only by default. Touch files only when the user explicitly asks during the design pass.
- **Refactoring in step 4.** Diagnosis only. The user picks.

## Quick reference

| Step | Output | Time |
|---|---|---|
| 1. Orient | 1 paragraph | 1 to 3 min |
| 2. Explore | raw notes per lens | 5 to 20 min (subagent for big repos) |
| 3. Score | ranking table | 1 to 2 min |
| 4. Present | top-7 markdown block | 1 min |
| 5. Design pass | hand off to `align` deep / `superpowers:brainstorming` | as long as it takes |
| 6. Hand off | plan or edits | follow-on skill |

## Tuning

- **Subagent threshold:** ~5k LOC. Below it, walk the repo inline.
- **Lens budget:** all 10 by default. User can scope: `/ica boundaries`, `/ica deps,errors`, `/ica depth seams`.
- **Top-N:** 7 by default. User can ask for more, fewer, or focus on one area.
- **History window:** `git log --since='3 months ago'` for hot-spot signal. Stretch to 6 months on slower repos, 1 month on fast ones.
