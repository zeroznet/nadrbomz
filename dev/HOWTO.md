# HOWTO — skill flows (80/20)

## When to use what

| Situation | Command |
|---|---|
| One question, one tweak, one bug | just chat |
| New feature or project | `/align deep`, then plan mode (shift+tab) |
| Resuming a project | `claude -r` |
| End of session | `/calibrate` |
| Polish your last diff | `/simplify` |
| Hostile second opinion before merge | `/code-review` |
| Touched auth, crypto, perms, SQL | `/security-review` |
| Repo feels tangled, structure is wrong | `/ica` |
| Plan exists, gut says gaps | `/align deep` |
| Deep, fact-checked research on a topic | `/deep-research <question>` |
| What people say about a topic lately | `/last30days <topic>` |
| Automate "when X, do Y" | `/update-config` |
| Task with a verifiable end state | `/goal <condition>` |
| Big job: codebase-wide hunt or large refactor | "Create a workflow" |
| Claude ephemera piling up, stale agents view | `/prune`, then `/prune --apply` |

## Gotchas

- **Plan mode before multi-step work.** It reads and plans without editing; approve the plan and it executes. `/align deep` first when the shape of the feature is still open.
- **`/goal` needs a checkable end state.** Example: `/goal all tests in test/auth pass and lint is clean`. It loops toward the condition on its own, validating after each step; vague goals ("make it nice") give the validator nothing to test.
- **`/deep-research` wants a specific question.** Give it budget/use-case/region up front. If it's underspecified ("what car to buy"), it asks 2-3 narrowing questions first, then returns a source-verified, cited report.
- **A workflow is one big job run as many parallel subagents** (codebase bug hunt, large refactor) in a single session. Ask "Create a workflow"; needs a Max/Team/Enterprise plan. Agents attack from independent angles and iterate until the answers converge.
- **`/simplify` rewrites code; `/code-review` only evaluates it.** Different jobs. `/simplify` defaults to the recent diff — scope it with `/simplify <path>`.
- **Verify before claiming.** Run the check command in the same message as "done / passes / fixed".

## After a feature lands

- `/simplify` — the diff still feels heavy
- `/code-review` — second opinion before merge
- `/security-review` — touched auth, crypto, perms, SQL
- `/ica` — the feature exposed a broader structural mess
- `/calibrate` — wrap the session
