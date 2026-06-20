# HOWTO — skill flows (80/20)

## When to use what

| Situation | Command |
|---|---|
| One question, one tweak | just chat |
| New feature or project | `/brainstorming` |
| Resuming a project | `/handoff` |
| End of session | `/calibrate` then `/handoff "<focus>"` |
| Polish your last diff | `/simplify` |
| Hostile second opinion before merge | `/requesting-code-review` |
| Someone gave you review comments to handle | `/receiving-code-review` |
| Touched auth, crypto, perms, SQL | `/security-review` |
| One bug, no clue why | `/systematic-debugging` |
| Repo feels tangled, structure is wrong | `/ica` |
| Plan exists, gut says gaps | `/align deep` |
| Want to test a design first | `/prototype` |
| Automate "when X, do Y" | `/update-config` |
| Task with a verifiable end state | `/goal` |
| Big job: codebase-wide hunt or large refactor | dynamic workflow ("Create a workflow") |

## Flows

**New feature:** `/brainstorming`. Auto-chains to merge. One mid-flow prompt (subagent-driven vs inline).

**Resume:** `/handoff`. Restores HANDOFF.md.

**End session:** `/calibrate`, then `/handoff "<focus>"`. Order matters.

**Run until done:** `/goal <condition>`. Set a verifiable stop condition; Claude loops toward it without prompting at each step. A fast validator checks after every step whether the goal is met, and only closes the loop when it is. Example: `/goal all tests in test/auth pass and the lint step is clean`. Needs a checkable end state — vague goals ("make it nice") give the validator nothing to test.

**Hand off a large task:** ask Claude to "Create a workflow." Dynamic workflows (research preview, Max/Team/Enterprise plans) run one big job — codebase-wide bug hunt, large refactor — as a coordinated fleet of parallel subagents in a single session. Claude writes a JavaScript orchestration script from your request; a runtime executes it in the background while the session stays responsive. Up to 1000 agents per run, 16 concurrent. Agents attack from independent angles, others refute, the run iterates until answers converge.

## After `/brainstorming` says "done"

The chain already wrote, tested, reviewed, and finished the branch. Optional extra passes:

- `/simplify` — one more polish if the diff still feels heavy
- `/security-review` — touched auth, crypto, perms, SQL (chain's review is general, not security-focused)
- `/ica` — feature exposed broader structural mess worth fixing next
- `/calibrate` then `/handoff "<focus>"` — wrap the session

## Rules

- Before saying "done / passes / fixed", run the verification command in the same message.
- `/simplify` rewrites code. `/requesting-code-review` evaluates code. Different jobs.
- `/simplify` defaults to recent diff. Scope with `/simplify <path>`.
- Never reply "you're absolutely right" to review feedback. `/receiving-code-review` enforces that.
- `/calibrate` is terminal. End the thread after.
- Inside `/brainstorming`, plan / TDD / review / finish chain automatically. Don't call them by hand.
