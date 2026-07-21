---
name: super-research
description: >
  End-to-end research publishing: run deep research on a question, render the report as a
  polished on-brand self-contained HTML page, and host it at a shareable URL. Use when the
  user wants researched content delivered as a link or page — "research X and make me a
  page", "deep dive on Y and send them a link", "super research", "research this and host
  it", or when a research request names an audience/brand the output should be dressed for.
allowed-tools: Bash, Write, Read, Edit, WebFetch, WebSearch, Agent, Skill
---

# super-research

One command, three phases: **deep-research → share-as-page → URL**. This skill orchestrates
two existing skills; it does not duplicate them. Their contracts make the chain clean:
deep-research ends at a markdown report on disk; share-as-page starts from content on disk
and ends at a hosted URL. The handoff is one file path.

- Research engine: `~/.claude/skills/deep-research/` (agents, tier classification, quality gates)
- Page engine: `~/.claude/skills/share-as-page/` (template, brand tokens, visual eval, deploy)

## Phase 0 — Scope (one question round, max)

Before launching, resolve THREE things (ask only what the prompt doesn't already answer,
in a single AskUserQuestion round):

1. **Research scope** — quick / standard / thorough (deep-research's own modifiers).
2. **Audience & brand** — who will read the page, and whose brand should it wear?
   (their company, the user's brand via Kopi, or neutral). This changes the page, not
   the research.
3. **Publish target** — public link OK, or is the content sensitive (deal strategy,
   internal analysis, third-party brand)? If sensitive: build everything, hold the
   deploy for explicit go-ahead.

## Phase 1 — Research

Invoke the **deep-research** skill (Skill tool, `skill: "deep-research"`) with the refined
question, prefixed with the scope modifier if not standard. Let it run its full pipeline —
breadth agents, depth agents, synthesis, quality gates — and persist its report to
`~/Documents/deep-research/YYYY-MM-DD-<slug>.md`.

**Do not skip or reimplement deep-research.** The markdown report is the archive and the
single source of truth for Phase 2. Capture the report path.

Display the report inline per deep-research's own rules (the chat is primary delivery);
the page is an *additional* rendering, not a replacement.

## Phase 2 — Page

Follow the **share-as-page** workflow (`~/.claude/skills/share-as-page/SKILL.md`) with the
report as content. Pick ONE slug and reuse it everywhere: project dir `~/Projects/<slug>-page/`,
and remember the dir name becomes the public URL (`<slug>-page.vercel.app`) — choose it
like a URL, not like a filename.

Overrides and hard-won amendments to the share-as-page flow (these supersede its docs
where they conflict):

- **Brand cache first.** Before scraping a brand site, check
  `~/.claude/skills/share-as-page/brands/<domain>.json`. On a cache miss, after resolving
  tokens (Kopi → site scrape → past-session research), WRITE that file: colors, fonts,
  motifs, logo data URI, and a `source` note. Next page for the brand is instant and better.
- **Logo embedding: placeholder, never paste.** Author the HTML with a literal
  `LOGO_DATA_URI` placeholder, then inject:
  `python3 -c "import sys;h=open('index.html').read();open('index.html','w').write(h.replace('LOGO_DATA_URI', open('logo-datauri.txt').read().strip()))"`
  Base64 blobs must never round-trip through model context.
- **Visual eval floor is 500px.** Headless Chrome clamps window width to ~500; narrower
  shot.sh runs produce phantom overflow (clipped words that look like layout bugs).
  Use `shot.sh <dir> <out> 1300 1100` for desktop and `... 500 1000` for narrow. Never
  diagnose "mobile overflow" from a sub-500px screenshot.
- **Full-page check.** Also shoot tall (`1300 9000+`, downscale with
  `sips --resampleWidth 640`) and actually Read it — tables, code blocks, footer.
- **Structure for reports**: metric-chip row for the 3–5 headline numbers, finding cards
  with confidence badges, vendor/comparison tables, sources grouped by tier. Match the
  brand's signature devices (e.g. mono uppercase eyebrows, dark sections) — not just its hex.

## Phase 3 — Publish

- If Phase 0 flagged the content sensitive (or it turns out to be — candid strategy,
  another company's brand, unreleased info): **send the file, state the page is ready,
  and ask before deploying.** Otherwise deploy directly:
  `bash ~/.claude/skills/share-as-page/scripts/deploy.sh ~/Projects/<slug>-page`
- Final handoff, all in the turn's last message: the URL, both file paths (markdown
  archive + page dir), and a one-line note that ⌘P → Save as PDF works.

## Rules

- **No re-research in Phase 2.** The page renders what the report says — numbers, tiers,
  gaps included. If the page needs a fact the report lacks, that's a Phase 1 gap; say so.
- **Keep the negative findings.** Verified negatives and research gaps are the credibility
  of the artifact; don't polish them out for the branded version.
- **One revision pass** offered after the URL, per share-as-page.
- The markdown report always exists even if the page/deploy fails — never let Phase 2/3
  errors destroy or block Phase 1 output.
