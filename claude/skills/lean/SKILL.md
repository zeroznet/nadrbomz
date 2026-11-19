---
name: lean
description: Finds what a project's knowledge files still say but is no longer true or needed, and proposes deleting it. Checks every claim in .md files (CLAUDE.md, README, TODO, docs, plans, specs, handoffs, lessons logs) and the project's auto-memory against the live code and git history; flags stale references, finished work, history git already holds, duplicates, and expired facts. Use when the user says "/lean", "clean up the docs", "remove outdated stuff", "the md files are full of old junk", or "prune memory".
argument-hint: "[path or file,...]"
---

# lean

## Purpose

Claude-assisted projects accumulate text: plans for work that shipped, TODO items long done, CLAUDE.md sections about features that were removed, memory entries the code has since contradicted, chronologies of decisions that git log already records. Each stale line costs context in every session that loads it, and worse, it teaches the next session something false. lean finds what is no longer true or no longer needed and proposes deleting it. It only removes; capturing new knowledge is `calibrate`'s job, and dead code is `ica`'s.

## Scope

- **Target:** the paths given as arguments, else the git root of cwd.
- **In scope:** every tracked and untracked `*.md` outside vendored and generated directories, `TODO*`, `HANDOFF*` and `*.bak` leftovers, and this project's auto-memory directory (the one named in the system prompt, with its `MEMORY.md` index).
- **Out of scope:** the workspace `~/dev/CLAUDE.md` and other nadrbomz-deployed copies (edit those only from their source in `~/dev/nadrbomz`, and only on explicit request), code, and anything outside the target.

## Workflow

### 1. Learn what the project is now

Read the README, project CLAUDE.md, the manifest (`go.mod`, `package.json`, ...), the top two levels of the tree, and `git log --since='6 months ago' --format='%cs %s'`. Write a short mental model: what it does, what it is built from, what is actively changing. Every later verdict is measured against this, not against what the docs claim.

### 2. Test every claim against the live state

Walk each in-scope file section by section and each memory entry one by one. A candidate for deletion is anything that matches one of these, with the evidence named:

| Signal | How to prove it |
|---|---|
| Points at something gone | the path, function, flag, command, env var, or URL no longer exists (`ls`, `grep -rn`, `--help`) |
| Work that is finished | a plan, spec, or TODO item whose result is in the code; cite the commit (`git log -S'<symbol>'` or `git log --format='%h %cs %s' -- <path>`) |
| History git already holds | chronologies, changelogs of decisions, "Done" or "Decisions" sections, "we switched X to Y on <date>" |
| Duplicate | the same fact lives in a more canonical file; keep that one, cite it |
| Derivable | file layouts, stack lists, or signatures any session can read from the code |
| Contradicted | the doc or memory says X, the code does Y |
| Expired | a dated deadline, a temporary workaround whose cause is fixed, a "for now" that became permanent or was removed |
| Leftover | `HANDOFF.md.bak`, scratch notes, empty or orphaned files nothing links to |

Keep, even if old: gotchas and failure contracts, rationale the code cannot explain, safety prohibitions, open work, external pointers that still resolve, and anything you could not disprove. Doubt means keep. Old is not the same as stale; a three-year-old line that is still true stays.

A whole file becomes a delete candidate only when every section in it is stale. Otherwise propose the specific sections.

### 3. Present

Group by file, biggest win first. Always-loaded files (CLAUDE.md, `MEMORY.md`) rank first because they cost context every session; give their est. token saving (chars / 4).

```markdown
## lean: <project>

<one line: what the project is now, and how much stale text was found>

### `<file>` (est. <N> tokens/session if always loaded)
1. **<section or line, quoted short>** (<signal>): <evidence: missing path, commit hash, canonical copy>
2. ...

### memory
3. **`<memory-file>.md`**: "<its one-line content>" (<signal>): <evidence>

**Kept despite age:** <one line naming what looked old but is still true>
```

Collect the pick with AskUserQuestion (multiSelect, chunked at 4 options per question, one option per numbered item or per file when a file has many). Memory is not in git, so a deleted entry is gone for good: the quoted content in the menu is the user's only record of it.

Found nothing stale: say so in one line.

### 4. Apply the picks

- Delete the picked sections or files. Remove a deleted memory's line from `MEMORY.md`, and fix any `[[link]]` that pointed at it.
- Sweep the project for references to deleted files and section names and fix them in the same commit (workspace CLAUDE.md #11).
- Commit tracked changes in the target following its conventions. Never push.

Report each applied item with its file, then the est. tokens saved per session in always-loaded files.
