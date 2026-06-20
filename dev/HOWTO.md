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
| Handle review comments you were given | `/receiving-code-review` |
| Touched auth, crypto, perms, SQL | `/security-review` |
| One bug, no clue why | `/systematic-debugging` |
| Repo feels tangled, structure is wrong | `/ica` |
| Plan exists, gut says gaps | `/align deep` |
| Validate a design before building | `/prototype` |
| Deep, fact-checked research on a topic | `/deep-research <question>` |
| Automate "when X, do Y" | `/update-config` |
| Task with a verifiable end state | `/goal <condition>` |
| Big job: codebase-wide hunt or large refactor | "Create a workflow" |

## Gotchas

- **`/brainstorming` is the whole chain.** It auto-runs plan → TDD → review → finish; don't call those by hand. Expect one mid-flow prompt (subagent-driven vs inline).
- **`/calibrate` then `/handoff`, in that order.** `/calibrate` is terminal — end the thread after it.
- **`/goal` needs a checkable end state.** Example: `/goal all tests in test/auth pass and lint is clean`. It loops toward the condition on its own, validating after each step; vague goals ("make it nice") give the validator nothing to test.
- **`/deep-research` wants a specific question.** Give it budget/use-case/region up front. If it's underspecified ("what car to buy"), it asks 2-3 narrowing questions first, then returns a source-verified, cited report.
- **A workflow is one big job run as many parallel subagents** (codebase bug hunt, large refactor) in a single session. Ask "Create a workflow"; needs a Max/Team/Enterprise plan. Agents attack from independent angles and iterate until the answers converge.
- **`/simplify` rewrites code; `/requesting-code-review` only evaluates it.** Different jobs. `/simplify` defaults to the recent diff — scope it with `/simplify <path>`.
- **Verify before claiming.** Run the check command in the same message as "done / passes / fixed".
- **Never reply "you're absolutely right" to review feedback.** `/receiving-code-review` enforces it.

## After `/brainstorming` finishes

The chain already wrote, tested, reviewed, and merged. Optional extra passes:

- `/simplify` — the diff still feels heavy
- `/security-review` — touched auth, crypto, perms, SQL (the chain's review is general, not security-focused)
- `/ica` — the feature exposed a broader structural mess
- `/calibrate` then `/handoff "<focus>"` — wrap the session
