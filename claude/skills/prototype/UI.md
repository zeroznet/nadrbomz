# UI Prototype

Generate **several radically different UI variations**, switchable from a floating bottom bar — as routes inside the project by default, or as a single published Artifact page when the project has no dev server to host them in. The user flips between variants in the browser, picks one (or steals bits from each), then throws the rest away.

If the question is about logic/state rather than what something looks like — wrong branch. Use [LOGIC.md](LOGIC.md).

## Contents
- When this is the right shape
- Pick a delivery mode (route-based or Artifact page)
- Two sub-shapes (route-based): existing page, new page
- Artifact page delivery (no dev server)
- Process: question and N, variants, wiring, floating switcher, hand-over, cleanup
- Anti-patterns

## When this is the right shape

- "What should this page look like?"
- "I want to see a few options for this dashboard before committing."
- "Try a different layout for the settings screen."
- Any time the user would otherwise spend a day picking between three vague mockups in their head.

## Pick a delivery mode

- **Route-based (default).** The variants render inside the project itself, switchable via a URL search param. Use this whenever the project has a runnable web app or dev server to host it in. Two sub-shapes below.
- **Artifact page (fallback).** When the project has no runnable web app or dev server — a backend-only repo, a CLI tool, a library with no UI shell to plug into — build the N variants into one self-contained HTML file with a client-side switcher and publish it with the Artifact tool instead of touching the repo. See "Artifact page delivery" below.

Default to route-based whenever the project already runs a web app; only fall back to the Artifact page when there's genuinely nowhere in the project to host the variants. Both modes draft variants the same way — "Generate radically different variants" below applies regardless of where the result gets delivered.

## Two sub-shapes (route-based) — strongly prefer sub-shape A

A UI prototype is much easier to judge when it's **butting up against the rest of the app** — real header, real sidebar, real data, real density. A throwaway route on its own is a vacuum: every variant looks fine in isolation. Default to sub-shape A whenever there's a plausible existing page to host the variants. Only reach for sub-shape B if the prototype genuinely has no nearby home.

### Sub-shape A — adjustment to an existing page (preferred)

The route already exists. Variants are rendered **on the same route**, gated by a `?variant=` URL search param. The existing data fetching, params, and auth all stay — only the rendering swaps. This is the default; pick it unless there's a specific reason not to.

If the prototype is for something that doesn't yet have a page but *would naturally live inside one* (a new section of the dashboard, a new card on the settings screen, a new step in an existing flow) — that's still sub-shape A. Mount the variants inside the host page.

### Sub-shape B — a new page (last resort)

Only use this when the thing being prototyped genuinely has no existing page to live inside — e.g. an entirely new top-level surface, or a flow that can't be embedded anywhere sensible.

Create a **throwaway route** following whatever routing convention the project already uses — don't invent a new top-level structure. Name it so it's obviously a prototype (e.g. include the word `prototype` in the path or filename). Same `?variant=` pattern.

Before committing to sub-shape B, sanity-check: is there really no existing page this could be embedded in? An empty route hides design problems that a populated one would expose.

In both sub-shapes the floating bottom bar is identical.

## Artifact page delivery (no dev server)

When the project has nothing to run — no dev server, no web app to plug a route into — don't scaffold anything into the repo. Build the N variants as **one self-contained HTML file**: every variant, plus the floating switcher, in a single page with inline CSS/JS and no external dependencies (matches how the Artifact tool has to be self-contained anyway).

- Each variant is a section or render function inside that one file, held to the same "structurally different" bar as route-based variants — see "Generate radically different variants" below. A single-file constraint is not license to make the variants look alike.
- Data is stubbed inline (representative sample values), since there's no backend to fetch from — same as any prototype under "No persistence by default."
- The switcher is the same floating bottom-bar concept as route-based delivery (left arrow / variant label / right arrow, keyboard-cyclable), just implemented in plain JS instead of a shared component — there's only one file, so it lives directly in it.
- The file lives in the **scratchpad directory**, never in the project tree. Prepare and publish it by following the Artifact tool's own current instructions, not from memory; its contract changes. The published URL is the artifact — nothing gets committed.
- There's no "production build" to hide the switcher from, so skip the `NODE_ENV` gating that route-based delivery needs — but the local file being throwaway doesn't make the published page throwaway too. It starts private but persists as a hosted URL on claude.ai until someone deletes it; see step 6 below for cleanup.

## Process

### 1. State the question and pick N

Default to **3 variants**. More than 5 stops being radically different and starts being noise — cap there.

Write down the plan in one line, in the prototype's location or a top-of-file comment:

> "Three variants of the settings page, switchable via `?variant=`, on the existing `/settings` route."

This works whether the user is here to push back or not.

### 2. Generate radically different variants

Draft each variant. Hold each one to:

- The page's purpose and the data it has access to (route-based) or the stubbed sample data standing in for it (Artifact page).
- The project's component library / styling system (TailwindCSS, shadcn, MUI, plain CSS, whatever) for route-based delivery; inline CSS for an Artifact page, since it has to stay self-contained.
- A clear exported component name (route-based) or a clearly named render function (Artifact page) — `VariantA`, `VariantB`, `VariantC` either way.

Variants must be **structurally different** — different layout, different information hierarchy, different primary affordance, not just different colours. Three slightly-tweaked card grids isn't a UI prototype, it's wallpaper. If two drafts come out too similar, redo one with explicit "do not use a card grid" guidance.

### 3. Wire them together

**Route-based:** create a single switcher component on the route:

```tsx
// pseudo-code — adapt to the project's framework
const variant = searchParams.get('variant') ?? 'A';
return (
  <>
    {variant === 'A' && <VariantA {...data} />}
    {variant === 'B' && <VariantB {...data} />}
    {variant === 'C' && <VariantC {...data} />}
    <PrototypeSwitcher variants={['A','B','C']} current={variant} />
  </>
);
```

For sub-shape A (existing page): keep all the existing data fetching above the switcher; only the rendered subtree changes per variant.

For sub-shape B (new page): the throwaway route under `/prototype/<name>` mounts the same switcher.

**Artifact page:** the same idea, without a framework — one script in the same HTML file dispatches to a render function per variant:

```js
// pseudo-code — single self-contained HTML file
const variants = { A: renderVariantA, B: renderVariantB, C: renderVariantC };
let current = new URLSearchParams(location.search).get('variant') ?? 'A';
function render() {
  root.innerHTML = '';
  variants[current](root, sampleData);
  updateSwitcher(current);
}
render();
```

### 4. Build the floating switcher

A small fixed-position bar at the bottom-centre of the screen with three pieces:

- **Left arrow** — cycles to the previous variant (wraps around).
- **Variant label** — shows the current variant key and, if the variant exports a name, that name too. e.g. `B — Sidebar layout`.
- **Right arrow** — cycles forward (wraps around).

Behaviour:

- Clicking an arrow updates the URL search param so the variant is shareable and reload-stable — via the framework's router (`router.replace` on Next, `navigate` on React Router, etc) for route-based delivery, or plain `history.replaceState` for an Artifact page.
- Keyboard: `←` and `→` arrow keys also cycle. Don't intercept arrow keys when an `<input>`, `<textarea>`, or `[contenteditable]` is focused.
- Visually distinct from the page (e.g. high-contrast pill, subtle shadow) so it's obviously not part of the design being evaluated.
- Route-based only: hidden in production builds — gate on `process.env.NODE_ENV !== 'production'` or an equivalent check, so a stray prototype merge can't ship the bar to users. An Artifact page has no production build and no separate production audience, so there's nothing to gate the switcher against.

Route-based: put the switcher in a single shared component so both sub-shapes can reuse it, located wherever shared UI lives in the project. Artifact page: there's only one file, so the switcher lives directly in it.

### 5. Hand it over

Surface the URL (and the `?variant=` keys) — the dev server's route, or the published Artifact link. The user will flip through whenever they get to it. The interesting feedback is usually **"I want the header from B with the sidebar from C"** — that's the actual design they want.

### 6. Capture the answer and clean up

Once a variant has won, write down which one and why (commit message, ADR, issue, or a `NOTES.md` next to the prototype if running AFK and the user hasn't responded yet). Then:

- **Sub-shape A** — delete the losing variants and the switcher; fold the winner into the existing page.
- **Sub-shape B** — promote the winning variant to a real route, delete the throwaway route and the switcher.
- **Artifact page** — nothing to delete from the repo; the file only ever lived in the scratchpad directory. Rebuild the winner properly as real code — the artifact's markup was written under prototype constraints, not folded in directly. The published page itself is separate from the local file: it stays on claude.ai after the file is gone, so ask the user whether to delete it (the Artifact tool's `delete` action, which they confirm) or keep it as the record of the answer.

Don't leave variant components or the switcher lying around. They rot fast and confuse the next reader.

## Anti-patterns

- **Variants that differ only in colour or copy.** That's a tweak, not a prototype. Real variants disagree about structure.
- **Sharing too much code between variants.** A shared `<Header>` is fine; a shared `<Layout>` defeats the point. Each variant should be free to throw out the layout.
- **Wiring variants to real mutations.** Read-only prototypes are fine. If a variant needs to mutate, point it at a stub — the question is "what should this look like", not "does the backend work".
- **Promoting the prototype directly to production.** The variant code was written under prototype constraints (no tests, minimal error handling). Rewrite it properly when you fold it in.
- **Reaching for the Artifact page when the project already runs a web app.** Route-based delivery beats a standalone page every time real header/sidebar/data context is available — only fall back when there's genuinely no dev server to host the variants in.
