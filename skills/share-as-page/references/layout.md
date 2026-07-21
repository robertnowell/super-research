# Layout & inlining cheat sheet

Quick reference for authoring the self-contained HTML. (Loaded on demand — read when you need
a specific snippet.) Contents: 1) readable defaults · 2) brand tokens · 3) embedding logo/fonts
· 4) accessible foreground · 5) brand extraction order · 6) print/PDF · 7) do/don't.

## 1. Readable defaults (already in the template — keep them)
- **Measure (line length): 66 chars ideal, 45–75 OK** → `max-width: 70ch` (or `33em`). WCAG caps at 80.
- **Body ≥16px, line-height 1.5+.** Template uses 17px / 1.6.
- Prose stays at `--measure`; tables, metric chips, and callouts may span full width
  (set `<main class="wide">` for table-heavy reports).

## 2. Brand tokens (the only routine edit)
Six-to-eight semantic CSS custom properties on `:root`. Don't add primitive palettes, spacing
scales, or motion tokens — dead weight without a component library.
```
--color-brand --color-accent --color-bg --color-paper
--color-text --color-heading --color-muted --color-line --on-brand
--font-heading --font-body
```

## 3. Embedding assets (portability = zero external requests)

**Logo as a data URI** — download then base64-embed:
```bash
curl -sL "<logo-url>" -o /tmp/logo.png
echo "data:image/png;base64,$(base64 -i /tmp/logo.png | tr -d '\n')"
```
Paste into `<img class="mast-logo" src="data:image/png;base64,…">`. SVG: `data:image/svg+xml;base64,…`.
Keep raster logos reasonably small; SVG preferred when available.

**Non-system fonts as data URIs.** The rule is *embed the font file, never `<link>` to a CDN at
runtime* (a runtime link breaks offline portability + the Artifact CSP). Three cases:

1. **System font** (Helvetica/Arial/Georgia/system-ui) — don't embed; just name it in `--font-body`.
2. **Google / open-source font** — there IS a cheap path. The helper fetches the latin woff2 and
   emits ready-to-paste self-contained `@font-face` blocks:
   ```bash
   bash ~/.claude/skills/share-as-page/scripts/embed-font.sh "Fraunces" 400 700 >> /tmp/fonts.css
   ```
   Paste the output into the template `<style>`, then set `--font-heading`/`--font-body` to the
   family name. (Detect a site's Google font via `link[href*="fonts.googleapis.com"]`.)
3. **Proprietary foundry font** (TWK Lausanne, Berkeley Mono, brand-licensed) — no cheap auto
   path; these aren't freely downloadable. Provide the `.woff2` yourself and embed it, or fall
   back to the nearest system/Google stack.

Manual embed of any `.woff2` you have on disk:
```css
@font-face{ font-family:"Brand Sans"; font-weight:400; font-display:swap;
  src:url(data:font/woff2;base64,PASTE) format("woff2"); }
```
`base64 -i Brand.woff2 | tr -d '\n'` → paste as PASTE. Base64 inflates size ~33%; fine for a doc.

## 4. Accessible foreground (`--on-brand`)
For text on the brand band, pick black or white by luminance of the brand color:
```
L = 0.2126*R + 0.7152*G + 0.0722*B   (channels sRGB→linear first; see WCAG G18)
L > 0.179  → use #000 (black text)
else       → use #fff (white text)
```
Guarantees ≥4.5:1 in normal cases. Quick check: dark brand → `--on-brand:#fff`; light/pastel brand
→ `--on-brand:#000`. Logos are exempt from contrast rules.

## 5. Brand extraction order (fallback / logo only — Kopi is preferred)
Cheapest → richest:
1. `meta[name="theme-color"]` content — CSS-ready brand color, no image decode.
2. `link[rel="manifest"]` → `theme_color` field.
3. `link[rel="apple-touch-icon"]` href — logo PNG; sample dominant color.
4. `meta[property="og:image"]` — branded card; noisier dominant color.
5. inline `.logo`/`.brand` `<img>`/SVG — fragile, site-specific.

Dominant color from an image (no deps): draw to a 1×1 canvas and read the pixel — fast average.
For a salient hue over a white background, prefer the logo's own swatch.
Fonts have no meta equivalent: only `link[href*="fonts.googleapis.com"]` is a cheap signal; else
default a stack.

## 6. Print / PDF
The template's `@media print` block already wires A4, `break-inside:avoid`, widows/orphans, and
`print-color-adjust:exact` so the brand band survives. Tell the user: ⌘P → Save as PDF.

## 7. Do / Don't
- **Do** keep it one self-contained file; render offline when double-clicked.
- **Do** raise the page to the brand — accent band, logo lockup, on-brand section styling.
- **Don't** `<link>` Google Fonts, pull CDNs, or hotlink remote images *at runtime* (breaks
  portability + Artifact CSP) — **embed** them instead (see §3; `embed-font.sh` for Google fonts).
- **Don't** invent data — render only what's in the source content.
- **Don't** add a JSON data model or build step. Author HTML directly; the only script is deploy.
