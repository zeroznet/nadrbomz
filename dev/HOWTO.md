# HOWTO: skill flows

| Situation | Command |
|---|---|
| One question, one tweak, one bug | just chat |
| New feature, or a plan that feels thin | `/align deep`, then plan mode (shift+tab) |
| Diff feels heavy | `/simplify [path]` |
| Second opinion before merge | `/code-review` |
| Touched auth, crypto, perms, SQL | `/security-review` |
| Public text draft (PR, issue, comment, post) | `/slopbeth:slopbeth` |
| Repo feels tangled | `/ica` |
| Old repo lags behind newer ones | `/uplift [path]` |
| Repo, docs or memory hold dead weight | `/lean` |
| Cited research on a topic | `/deep-research <question>` |
| Automate "when X, do Y" | `/update-config` |
| Task with a checkable end state | `/goal <condition>` |
| Claude ephemera piling up | `/prune` (`--dry-run` to preview) |

## Gotchas

- `/goal` needs a testable condition: `/goal all tests in test/auth pass and lint is clean`, not "make it nice".
- `/deep-research` wants a specific question with budget, use case and region up front.
- `/simplify` rewrites code, `/code-review` only evaluates it.
