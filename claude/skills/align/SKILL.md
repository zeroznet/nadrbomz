---
name: align
description: Use when intent, scope, or design decisions in a task or plan are not yet locked. Defaults to a fast numbered-question pass with lettered options; with `deep`, walks the full design tree, resolves dependencies between decisions, and explores code before asking what code already answers.
---

# align

## Purpose

Cut ambiguity before code happens. Either fast (a numbered list of questions, each with lettered options the user can answer with `1c, 2a, 3 free-text`) or deep (walk every branch of the design tree, resolve decision dependencies, prefer reading the codebase over asking). Same skill, two intensities.

The win in both modes is the same: stop the agent from silently choosing for you, and stop the conversation from looping on ambiguities that compound.

## When to use

- A task has multiple reasonable interpretations and you want them surfaced before work starts.
- A plan landed but you can feel the gaps — decisions implied but never named, dependencies left dangling.
- The agent is about to commit to an implementation choice that wasn't actually decided.
- Robert says `/align`, `/align <N>`, `/align deep`, "ask me questions first", "interview me on this plan".

## When NOT to use

- Trivial task with one obvious shape. Just do it.
- Single decision already named and answered. Don't manufacture questions.
- Bug hunt — use `superpowers:systematic-debugging`.
- New feature from scratch with no prior thinking — use `superpowers:brainstorming` first, then come back.
- Architecture diagnosis — use `ica`.

## Mode detection

| Invocation | Mode | Behavior |
|---|---|---|
| `/align` | light | 4 numbered questions (default), lettered options |
| `/align <N>` | light | up to `<N>` numbered questions, lettered options |
| `/align deep` | deep | walk every decision branch, loop until clear |
| `/align deep <N>` | deep | deep mode capped at `<N>` rounds |

`<N>` is a positive integer. Anything else falls back to the default for that mode.

## Light mode

### Workflow

1. **Read the room.** Look at the current task or plan in the conversation. Note explicit decisions, implicit ones, and gaps.
2. **Pick the top `<N>` ambiguities.** Default `<N>` is 4 if not specified. Prefer ambiguities where the wrong silent choice would cost real work.
3. **Generate questions with lettered options.** Each question: one short sentence, then 2–4 lettered options labeled `a)` `b)` `c)` `d)`. The options must be *concretely different*, not three flavors of the same thing. The user can also answer free-text if none fit; do not include an explicit "e) other" — that's always implied.
4. **Render the block.** Use the format in the next section verbatim.
5. **Wait.** Do not start implementing. Do not "tentatively pick" a default. The whole point is the pick.
6. **Parse the answer.** Accept compact forms: `1c, 2a, 3 free-text answer, 4 skip`. `skip` or empty = use your best judgment for that one, but call it out before acting on it.
7. **Resume the task** with the choices applied. Do not re-ask. Do not re-summarize the answers in long form — one short confirmation line is enough.

### Output format (light)

```markdown
## align — <N> questions

### 1. <one-sentence question>
- a) <concrete option A>
- b) <concrete option B>
- c) <concrete option C>

### 2. <one-sentence question>
- a) <option A>
- b) <option B>

...

Answer with `1c, 2a, 3 ...` or free-text per item. `skip` = use your judgment.
```

### Hard rules for light mode

- Options must be substantively different. If `a)` and `b)` collapse to the same outcome, the question is broken — rewrite.
- Never ask a question whose answer is already in the codebase, CLAUDE.md, an existing memory file, or earlier in this conversation. Look first.
- Never ask filler ("should we name it X or Y?") when the actual decision is upstream of naming.
- `<N>` is a ceiling, not a target. Never exceed it. Going below `<N>` is fine — and required — if you genuinely have fewer real ambiguities; state that fewer were warranted in one line.

## Deep mode

### Workflow

1. **Extract all decisions** from the plan or current discussion. A decision is anything where multiple options exist and one must be chosen before progress. Implicit decisions count.
2. **Build a decision tree.** Decisions that depend on other decisions are children. Don't ask the child until the parent is settled.
3. **For each open decision, in dependency order:**
   - First, try to answer it from the code. Read the relevant files. The answer is often already there, encoded in interfaces, types, tests, or existing call sites.
   - If the code answers it, state the answer and the file you got it from. Move on.
   - If the code does not answer it, ask the user — one decision at a time, with the relevant context (what depends on this, what alternatives are real).
4. **Apply the answer**, then re-check the tree. New decisions may have surfaced; old ones may now be irrelevant.
5. **Loop** until every decision is resolved or explicitly deferred. If `<N>` was supplied, stop after `<N>` rounds and report what's still open.
6. **Output a recap** when done: the decisions made, the reasons, and the files consulted along the way. Short. No chronology.

### Output format (deep, per round)

```markdown
## align deep — round <K>

**Tree so far:** <one-line snapshot of open decisions, indented by dependency>

### Now resolving: <decision name>
- **Why now:** <one line — what depends on this>
- **What I checked in the code:** <file paths and lines, or "nothing relevant">
- **Alternatives:** <a, b, c with one-line tradeoff each>
- **My read:** <which alternative seems right, why — one short paragraph; explicit recommendation, not a hedge>

Answer (a/b/c, free-text, or "go with your read")?
```

### Recap (deep, when done)

```markdown
## align deep — recap

**Decisions:**
- <name>: <choice> — <one-line reason> (from <file path> or "asked")
- ...

**Still open:** <list, or "none">

**Files read:** <list of paths>
```

### Hard rules for deep mode

- **Code before user.** Every decision is first probed against the code. Asking what `git grep` would have answered wastes the user's attention.
- **One decision per round.** Bundling questions defeats dependency walking — answers to one change the shape of the next.
- **State the recommendation.** "My read" is a real opinion with a real reason. Hedging ("could go either way") is a failure — if it really could, the decision is too small to ask about.
- **No silent assumptions.** If a decision feels too small to ask, decide it explicitly and name it in the recap. Future-you reading the recap should know what was chosen and why.
- **Stop when done.** Don't manufacture decisions to pad the loop.

## Anti-patterns

- **Vague options.** `a) shorter b) more concise c) tighter` — pick one, delete the rest. Options must differ in *outcome*, not in word choice.
- **Asking what's already answered.** Re-read CLAUDE.md, memory, and the plan first. If the answer is there, cite it instead of asking.
- **Defaulting silently.** The whole point of align is to *not* pick for the user. If you find yourself adding "I'll go with X if you don't reply," stop — the question wasn't actually needed.
- **Mode confusion.** `<N>` selects count, not mode. `/align 10` is still light. `/align deep` is deep. Don't mix.
- **Padding the question count.** `<N>` is a ceiling. If only 2 real ambiguities exist, ask 2 — even if the user said `/align 5`. State that fewer were warranted in one line.
- **Sycophantic confirmation.** "Great choice!" after a pick adds nothing. Apply and move on.

## Quick reference

| Mode | Trigger | Default `<N>` | Stops when |
|---|---|---|---|
| Light | `/align`, `/align <N>` | 4 | user answers |
| Deep | `/align deep`, `/align deep <N>` | unbounded | tree resolved or `<N>` rounds hit |

## Hand off (deep mode, when done)

- Plan is now clear and multi-step → `superpowers:writing-plans`.
- Plan is clear and single-step → just do it.
- Plan revealed it should be reframed as a refactor → `ica`.
- Decisions revealed a missing skill/command/setting the user wants to keep → mention `calibrate` so they can sweep at session end.
