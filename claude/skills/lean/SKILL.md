---
name: lean
description: Walks every file in the current project, works out end to end how the project runs today, and proposes deleting whatever is no longer needed or no longer true. Covers orphaned scripts, configs for tools no longer used, workflows and assets nothing reaches, leftovers, and inside text files (.md, CLAUDE.md, README, TODO, plans, specs, handoffs) and the project's auto-memory every claim that is stale, finished, duplicated, or history git already holds. Use when the user says "/lean", "clean up this repo", "remove outdated stuff", "what here is not needed anymore", "the md files are full of old junk", or "prune memory".
argument-hint: "[path,...]"
---

# lean

## Purpose

Projects accumulate weight. Scripts that nothing calls anymore, a workflow for a feature that was removed, configs for a linter that was replaced, plans for work that shipped, TODO items long done, CLAUDE.md sections about things that no longer exist, memory entries the code has since contradicted. Each stale file costs attention, and each stale line in an always-loaded file costs context in every session and teaches the next one something false.

lean reads every file, builds an end-to-end picture of how the project actually runs today, and proposes deleting what that picture does not need. It only removes. Capturing new knowledge is `calibrate`'s job; line-level dead code inside a live source file (unused exports, dead branches) is `ica`'s.

## Scope

- **Target:** the paths given as arguments, else the git root of cwd.
- **In scope:** every tracked file, untracked files not ignored by `.gitignore`, and this project's auto-memory directory (the one named in the system prompt, with its `MEMORY.md` index). Skip vendored and generated trees (`node_modules`, `vendor`, build output) and read lockfiles only to check they match a manifest.
- **Out of scope:** the workspace `~/dev/CLAUDE.md` and other nadrbomz-deployed copies (change those only from their source in `~/dev/nadrbomz`, and only on explicit request), and anything outside the target.

## Workflow

### 1. Map how the project runs today

List every file (`git ls-files` plus `git ls-files --others --exclude-standard`), then read enough to know what each one is for. Build the map from the entry points outward:

- **Entry points:** what a user, CI, or deploy actually runs. Main binaries and packages, scripts named in README usage, Makefile or justfile targets, `package.json` scripts, workflow triggers and the steps they call, deploy or install lists, cron and service units.
- **Reachability:** follow each entry point to what it uses: imports, `source`d files, script calls, files copied or deployed, templates, fixtures loaded by tests, assets referenced by docs or code.
- **Conventional files:** some files are needed without being referenced, because a tool or a human reads them by name: `LICENSE`, `README`, `.gitignore`, `CLAUDE.md`, a linter config whose linter still runs, `.github/` templates.

Also read `git log --since='6 months ago' --format='%cs %s' --name-status` to see what is alive and what was recently replaced. Every later verdict is measured against this map, not against what the docs claim.

### 2. Judge every file, then every section

A file is a delete candidate when it is neither reachable from an entry point nor a conventional file whose reader still exists. Prove it, do not assume it: grep the whole repo for its name and path (including CI, docs, and scripts), check whether a tool still reads it, check `git log` for the commit that replaced or orphaned it.

| File-level signal | Typical case |
|---|---|
| Orphan | a script, module, or asset nothing references and no entry point reaches |
| Dead tool config | config for a linter, formatter, CI service, or bot the project no longer uses |
| Dead workflow | a CI job for a removed feature, target, or platform |
| Superseded | an old version kept beside its replacement (`foo.sh` and `foo2.sh`, `old/`, `*.orig`) |
| Committed output | a generated file the build recreates anyway (unless the repo ships it on purpose, as a banner or a release artifact) |
| Leftover | `*.bak`, `HANDOFF*`, scratch notes, empty files, debug dumps |

Text files and memory get a second pass, section by section and entry by entry, because a needed file can still hold stale content:

| Content signal | How to prove it |
|---|---|
| Points at something gone | the path, function, flag, command, env var, or URL no longer exists |
| Work that is finished | a plan, spec, or TODO item whose result is in the code; cite the commit (`git log -S'<symbol>'`) |
| History git already holds | chronologies, "Done" or "Decisions" sections, "we switched X to Y on <date>" |
| Duplicate | the same fact lives in a more canonical file; keep that one, cite it |
| Derivable | layouts, stack lists, or signatures any session can read from the code |
| Contradicted | the text says X, the code does Y |
| Expired | a dated deadline, a workaround whose cause is fixed, a "for now" that ended |

Keep, even if old: gotchas and failure contracts, rationale the code cannot explain, safety prohibitions, open work, pointers that still resolve, and anything you could not disprove. Doubt means keep; a three-year-old file that is still used stays. Think through what breaks if the file disappears: a deploy step, a CI job, a user following the README, another host. If something would break, it is needed.

### 3. Present

Whole-file deletions first, then section edits; within each, biggest win first. Always-loaded files (CLAUDE.md, `MEMORY.md`) get an est. token saving (chars / 4).

```markdown
## lean: <project>

<one or two lines: what the project is today, how many files and sections no longer serve it>

### Files no longer needed
1. `<path>` (<signal>): <evidence: no references, replaced by `<path>` in <hash>, tool removed in <hash>>

### Stale content
2. `<file>` > **<section, quoted short>** (<signal>): <evidence> (est. <N> tokens/session if always loaded)

### Memory
3. `<memory-file>.md`: "<its one-line content>" (<signal>): <evidence>

**Kept despite age:** <one line naming what looked old but is still used or true>
```

Collect the pick with AskUserQuestion (multiSelect, chunked at 4 options per question, one option per numbered item, or per group when there are many). Memory and untracked files are not in git, so a deletion there is permanent: the menu's quote is the user's only record.

Found nothing worth removing: say so in one line.

### 4. Apply the picks

- Delete the picked files and sections. Remove a deleted memory's line from `MEMORY.md` and fix any `[[link]]` that pointed at it.
- Sweep the project for references to everything deleted (paths, names, section titles) and fix them in the same commit (workspace CLAUDE.md #11). A file listed in a deploy list, CI step, or README must leave all of them together.
- Verify nothing still needed broke: run the project's build, tests, or `sh -n` on touched scripts, whatever exists.
- Commit in the target following its conventions. Never push.

Report each applied item with its path, the est. tokens saved per session in always-loaded files, and one line on what could not be verified locally (CI, deploy, other hosts).
