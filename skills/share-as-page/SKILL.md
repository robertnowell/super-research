---
name: share-as-page
description: >
  Turn any report, research finding, analysis, audit, meeting recap, or conversation
  summary into a polished, on-brand, self-contained HTML page and host it on a shareable
  URL. Resolves brand tokens (color, fonts, logo) so the page looks like it belongs to the
  brand. Use when the user asks to "make this shareable", "host this", "turn this into a
  page / site / one-pager", "put it on the web", "send them a link", "create an HTML
  report", or shares a finished piece of analysis and wants a link to hand to someone.
allowed-tools: Bash, Write, Read, WebFetch, Edit
---

# share-as-page

Turn content you already have (a report, research, audit, recap) into **one self-contained,
on-brand HTML file** and **deploy it to a shareable URL**. One template → brand tokens →
inline everything → one deploy command.

Skill dir: `~/.claude/skills/share-as-page/` — `templates/report.html`, `references/layout.md`,
`scripts/deploy.sh`. **Work in a per-page project dir** (e.g. `~/Projects/<slug>-page/`); the
deploy reads `index.html` from there.

This is the *default reusable* path. If the content has a strong native metaphor (e.g. a
boarding pass for a travel brand) you may design a bespoke layout instead — but still follow
the same token + inline + deploy rules below.

## Workflow

### 1. Gather the content
Identify exactly what to render — the report/analysis/recap text, its sections, any tables.
Don't re-research; this skill packages content that already exists in the conversation or a file.
Pick a short kebab-case slug for the project dir and the URL.

### 2. Resolve brand tokens — **Kopi-first, then site, then default**
You need 6–8 values: `--color-brand`, `--color-accent`, `--color-text`, `--color-bg`,
`--color-heading`, `--font-heading`, `--font-body`, and a `--logo` (data URI).

1. **Explicit** — if the user gave colors/logo/brand, use them.
2. **Kopi** — if a brand is named or implied, resolve it:
   `set_active_brand` (query by name) → `get_context`. Map the returned briefing:
   - `colors.primary` → `--color-brand`; `colors.primaryForeground` → on-brand foreground
   - `colors.bodyBackground` → `--color-bg`; `colors.textBody` → `--color-text`
   - `colors.textHeading` (or `--color-brand` if null) → `--color-heading`
   - `fonts.heading.family` / `fonts.body.family` → font tokens
   - Logo: the brand's logo if present; otherwise fall through to step 3 for the logo only.
   Pick an `--color-accent` from the brand's secondary/logo color (sample the logo image if needed).
3. **Site scrape** (fallback, or for the logo) — `WebFetch`/curl the brand site:
   `meta[name=theme-color]` → brand color; `og:image` / `apple-touch-icon` / a `.logo` img → logo.
   Download the logo and **base64-embed it** as a data URI (see references/layout.md).
4. **Default** — none available: use the neutral tokens already in `templates/report.html`.

**Foreground rule** (accessible, one line): for any colored background, compute relative
luminance L; if **L > 0.179 use black text, else white** (guarantees ≥4.5:1). Logos are exempt.

### 3. Author the HTML
Copy `templates/report.html` to `<project>/index.html`, then:
- Set the `:root` tokens to the resolved brand values.
- Replace the `<title>`, header logo (`<!-- LOGO -->`), `<!-- TITLE -->`, `<!-- META -->`.
- Replace `<!-- CONTENT -->` with the report as semantic HTML (`<section>`, `<h2>`, `<p>`,
  `<table>`, `<ul>`). Keep prose to the `--measure` width; tables/callouts may go full width.
- **Inline everything** — no external requests. CSS stays in `<style>`; embed the logo and any
  non-system fonts as data URIs. System font stacks need no embedding.
- Keep the readable defaults (66ch measure, 16px/1.5, the `@media print` block). See
  `references/layout.md` for the cheat sheet and snippets.

Match the brand's character — don't ship a generic page. The template is a skeleton; raise it
to the brand (a tasteful accent band, a logo lockup, on-brand section styling).

### 4. Visual eval — **REQUIRED, before any deploy**
Never ship a page you haven't looked at. Render it and inspect the actual pixels:
```bash
bash ~/.claude/skills/share-as-page/scripts/shot.sh <project-dir> /tmp/preview.png
```
Then **Read `/tmp/preview.png`** and check, concretely:
- **Centering & width** — masthead, chips, prose, and tables share one aligned column; no
  content pinned left with a dead right gutter; no horizontal overflow.
- **Brand** — logo renders (not a broken-image box), brand color on the band, accent visible.
- **Contrast** — header text readable on the brand band (the `--on-brand` choice was right).
- **Spacing & overflow** — nothing clipped, no text overlapping, tables not blown out.
- **Tone** — it looks like the brand, not a generic template.

Fix the HTML and re-shoot until it's right. Only then deploy. (Optionally shoot a narrow
width too, e.g. `... /tmp/m.png 420 900`, to catch mobile breakage.) This gate is not optional —
the most common failures (off-center columns, missing logo, low contrast) are invisible until rendered.

### 5. Deploy — **and verify it's public before you call it ready**
```bash
bash ~/.claude/skills/share-as-page/scripts/deploy.sh <project-dir>
```
`deploy.sh` prints TWO lines and self-checks reachability:
```
https://<slug>-…​.vercel.app
ACCESS: public | protected | unreachable
```
**Never tell the user "the link is ready" until `ACCESS: public`.** A deploy can succeed
while the URL is gated — Vercel **team Deployment Protection** puts every deployment behind
a login wall (the fetch lands on a "Login – Vercel" page, often HTTP 200), so the link works
for you but 401s every external visitor. The script detects this and exits `3`.

If `ACCESS: protected`, **flag it and offer to fix it** — don't silently hand over a dead link:
```bash
bash ~/.claude/skills/share-as-page/scripts/vercel-unprotect.sh <project-dir> <url>
```
This disables Vercel Authentication for **that one project only** (scoped by
`.vercel/project.json`; team default + other projects untouched; reversible) and re-verifies
the URL is now public. Because it changes a protection setting on the user's account, **ask
before running it** unless they've already said "make it public." Alternative: Dashboard →
Project → Settings → Deployment Protection → Vercel Authentication → Disabled.
If `ACCESS: unreachable`, wait a moment for propagation and re-check; don't share it yet.

### 6. Hand off — only after ACCESS: public
Give the user the verified-public URL and offer **one revision pass**. Mention they can
⌘P → Save as PDF (the print CSS is wired). If any benchmark/number came from the
conversation, don't invent new ones.

## Hosting reference
- **Vercel (default):** `deploy.sh` runs `vercel deploy --prod --yes`; reads `VERCEL_TOKEN`
  from env if set, else ambient login. Persistent clean alias.
- **surge.sh (fallback, pick-your-subdomain):** `surge ./dir my-slug.surge.sh` with
  `SURGE_TOKEN`+`SURGE_LOGIN`. Unlimited, persists until `surge teardown`.
- **Netlify anonymous (zero-auth one-shot):** `netlify deploy --dir=./dir --allow-anonymous`
  — but the claim window is ~1h with undocumented persistence; use only for throwaway links.
- **Skip GitHub Pages** for agent use — needs repo + branch + Actions, too multi-step.

## Rules
- **One self-contained file.** It must render double-clicked offline and over the web with zero
  external requests. Inline CSS, fonts, and images (data URIs).
- **Tokens, not hard-codes.** All brand color/font decisions live in `:root` custom properties so
  a re-brand is a few-line edit.
- **Don't fabricate data.** Render only what's in the source content; never invent metrics.
- **Lightweight.** No JSON data model, no logo pipeline, no build step beyond the deploy. The only
  script is the deterministic deploy.
