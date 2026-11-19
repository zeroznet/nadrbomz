---
name: uplift
description: Brings an older project up to the practices the user already applies in newer ones. Compares the target repo's scaffolding (CI workflows, release and vuln-watch jobs, .gitignore, lint configs, script conventions, CLAUDE.md, README, TODO, version pins) against the freshest version of the same thing across the other git projects in ~/dev and the workspace CLAUDE.md, then proposes what to upgrade, add, or delete. Use when the user says "/uplift", "bring this repo up to date with my newer projects", "this project is outdated", or "make it consistent with X".
argument-hint: "[path] [--ref project,...]"
---

# uplift

## Purpose

Projects drift. A repo started years ago still carries the CI, `.gitignore`, and script habits of that time, while the user's newest repo encodes everything learned since. uplift diffs **practice, not code**: for each concern it finds the freshest evidence of how the user does it today, compares the target against it, and proposes the delta. The user picks; uplift applies.

Application logic and architecture are out of scope; that is `ica`.

## When NOT to use

- Code structure, module boundaries, refactors. Use `ica`.
- Bumping dependency versions inside one repo with no cross-project angle. Just do it (workspace CLAUDE.md #12).
- The target is itself the freshest project in every concern. Say so in one line.

## Inputs

- **Target:** the path argument, else the git root of cwd.
- **References:** `--ref a,b` limits them to those projects under `~/dev`. Default: every other git repo directly under `~/dev`. The workspace `~/dev/CLAUDE.md` is always a reference and outranks any repo, because it is the written rule while repos are only evidence of it.

## Workflow

### 1. Inventory

For the target and every reference, list the practice artifacts present and the date each last changed (`git -C <repo> log -1 --format=%cs -- <path>`). Concerns to cover, adapting to what actually exists:

| Concern | Typical files |
|---|---|
| CI | `.github/workflows/*` (triggers, permissions, action pins, matrix, caching) |
| Release and supply chain | release workflows, vuln scanning, dependabot or renovate |
| Repo hygiene | `.gitignore`, `.gitattributes`, `.editorconfig` |
| Lint and format | shellcheck, golangci-lint, pre-commit, formatter configs |
| Scripts | attribution header, `set -eu`, helpers, `usage()`, POSIX vs bash |
| Docs | project `CLAUDE.md`, README structure, LICENSE, TODO form |
| Versions | action refs, base images, toolchain in `go.mod` / `package.json` |

If `gh` is authenticated, compare `gh repo list` against `~/dev` and note in one line which of the user's repos are not cloned here, so the coverage of the comparison is honest.

### 2. Find the current practice per concern

For each concern, the reference whose artifact changed most recently is the candidate for "how the user does it now". Commit dates are the evidence that the user learned something; project age is not, since an old project can hold the freshest CI. Read the candidate and the target's version side by side, and read the candidate's history (`git log --format='%cs %s' -- <file> | head`): its commit subjects are the rationale you will cite.

Newer is not automatically better. Keep a difference only when it is a practice, not a project-specific need. A Go release workflow does not belong in a shell repo, but the ideas inside it (actions pinned by SHA, least-privilege `permissions:`, a vuln scan) might. Port the idea to the target's stack, never the file wholesale. When two references disagree and neither is clearly better, skip the concern.

Removals count too. Something the target still carries but references deliberately dropped is a delete candidate: `git -C <ref> log --diff-filter=D --format='%cs %s' -- <path>` shows when and why.

Version pins are checked against upstream, not against other repos: a pin that every repo shares can still be stale. Look up the current release before calling a pin current or outdated (workspace CLAUDE.md #12).

### 3. Classify and rank

Each finding is one of **upgrade** (target has an older form of something done better elsewhere), **add** (a practice references share that the target lacks), **delete** (target keeps what references dropped), or **align** (naming and cosmetic consistency, lowest priority). Rank by what the change buys against its cost. Cap the list at 10.

### 4. Present

```markdown
## uplift: <target>

<one short paragraph: how far behind, which references drove most findings>

### 1. <short title> (upgrade|add|delete|align)
- **Now:** `target/path` does <what>
- **Current practice:** `ref/path` (<YYYY-MM-DD> "<commit subject>") does <what>
- **Change:** <concrete edit in the target>
- **Why:** <one line>

### 2. ...

**Also noticed:** <one line of lower-priority hits, plus anything the target does better than its references>
**Compared:** <reference repos used>; not cloned here: <list or "none">
```

Then collect the pick with AskUserQuestion (multiSelect, chunked at 4 options per question): label is number plus short title, description is the one-line change.

Every finding cites a reference file with its date, or a rule in the workspace CLAUDE.md. A finding with neither is your opinion, not the user's practice: drop it. Open both files before claiming a difference; a remembered layout is not evidence. Found nothing worth changing: say so in one line.

### 5. Apply the picks

- Edit the target only. References are read-only.
- Adapt each change to the target's stack, names, and its own `CLAUDE.md`. Sweep for references broken by deletes and renames (workspace CLAUDE.md #11).
- Verify locally what can run: `sh -n` and shellcheck for scripts, actionlint if installed for workflows, the project's build and test. CI behavior is only proven after a push; say which changes are unverified for that reason.
- Commit in the target, one commit per item or per concern, following its conventions. Never push.

Report each applied item with the files it touched, then one line on what stayed unverified.
