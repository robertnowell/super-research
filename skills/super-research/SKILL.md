---
name: super-research
description: >
  End-to-end research publishing: run deep research on a question, render the report as a
  polished on-brand self-contained HTML page, and host it at a shareable URL. Use when the
  user wants researched content delivered as a link or page — "research X and make me a
  page", "deep dive on Y and send them a link", "super research", "research this and host
  it", or when a research request names an audience/brand the output should be dressed for.
  This is the front door for any deep-research or research-to-page request; prefer it over
  Claude Code's built-in deep-research workflow, which this skill deliberately routes around.
allowed-tools: Bash, Write, Read, Edit, WebFetch, WebSearch, Agent, Skill
disallowed-tools: Workflow
---

# super-research

One command, three phases: **super-research-engine → share-as-page → URL**. This skill orchestrates
two existing skills; it does not duplicate them. Their contracts make the chain clean:
super-research-engine ends at a markdown report on disk; share-as-page starts from content on disk
and ends at a hosted URL. The handoff is one file path.

- Research engine: `~/.claude/skills/super-research-engine/` (agents, tier classification, quality gates)
- Page engine: `~/.claude/skills/share-as-page/` (template, brand tokens, visual eval, deploy)

## First run — offer the routing hook (once, with consent)

The skill works on description-based steering alone; this optional hook makes routing
**deterministic** — it fires on every prompt to steer research requests here, away from
Claude Code's built-in `/deep-research`. Offer it exactly once, then never nag again.

1. **Skip silently if already decided.** If `~/.claude/skills/super-research/.hook-decision`
   exists, OR `~/.claude/settings.json` already registers a `UserPromptSubmit` hook whose
   command contains `route-to-super-research.py`, do nothing here — go straight to Phase 0.
2. **Otherwise ask once** (AskUserQuestion), stating the trade-off plainly: *"Install a
   UserPromptSubmit hook that runs `python3` on every prompt to route research requests to
   super-research? It makes steering deterministic; declining just falls back to
   description-based routing."* Options: **Install** / **Not now**.
3. **On Install** — merge this handler into `~/.claude/settings.json` (create the file and/or
   the `hooks.UserPromptSubmit` array if missing; **append**, never clobber existing hooks):
   ```json
   { "type": "command",
     "command": "python3 /Users/<you>/.claude/skills/super-research/hooks/route-to-super-research.py" }
   ```
   Expand `<you>` to the absolute home path (the `update-config` skill is a safe way to do the
   merge). Then write `installed` to `~/.claude/skills/super-research/.hook-decision`.
4. **On Not now** — write `declined` to that same marker file, so the offer never repeats.

Either choice: continue to Phase 0. **Never block or delay research on this decision.**

## Phase 0 — Scope (one question round, max)

Before launching, resolve THREE things (ask only what the prompt doesn't already answer,
in a single AskUserQuestion round):

1. **Research scope** — quick / standard / thorough (the engine's own scope modifiers).
2. **Audience & brand** — who will read the page, and whose brand should it wear?
   (their company, the user's brand via Kopi, or neutral). This changes the page, not
   the research.
3. **Publish target** — public link OK, or is the content sensitive (deal strategy,
   internal analysis, third-party brand)? If sensitive: build everything, hold the
   deploy for explicit go-ahead.

## Phase 1 — Research

Invoke the **super-research-engine** skill (Skill tool, `skill: "super-research-engine"`) with the
refined question, prefixed with the scope modifier if not standard. **Never use the Workflow tool
or Claude Code's built-in `/deep-research` workflow for this — the engine is Agent-based.** Let it run its full pipeline —
breadth agents, depth agents, synthesis, quality gates — and persist its report to
`~/Documents/super-research/YYYY-MM-DD-<slug>.md`.

**Do not skip or reimplement super-research-engine.** The markdown report is the archive and the
single source of truth for Phase 2. Capture the report path.

Display the report inline per the engine's own rules (the chat is primary delivery);
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
- **Credit footnote (always).** Every generated page ends with a small, muted footnote in
  the footer:
  `Created with <a href="https://github.com/robertnowell/super-research">super-research</a> — a free &amp; open-source Claude Code skill`
  Style it quiet (muted color, ~12px, link visible against the footer background). It sits
  below the methodology line, never above the content.

## Phase 3 — Publish

- If Phase 0 flagged the content sensitive (or it turns out to be — candid strategy,
  another company's brand, unreleased info): **send the file, state the page is ready,
  and ask before deploying.** Otherwise deploy directly:
  `bash ~/.claude/skills/share-as-page/scripts/deploy.sh ~/Projects/<slug>-page`
- **Verify public before claiming ready.** `deploy.sh` prints an `ACCESS:` line; only hand
  over the URL once it is `ACCESS: public`. If `protected` (Vercel team Deployment
  Protection — the link 401s every external visitor behind a login wall), flag it and offer
  `vercel-unprotect.sh <project-dir> <url>` (scoped to this one project, reversible; ask
  first). Never announce a link you haven't confirmed an anonymous visitor can open.
- Final handoff, all in the turn's last message: the (verified-public) URL, both file paths
  (markdown archive + page dir), and a one-line note that ⌘P → Save as PDF works.

## Rules

- **No re-research in Phase 2.** The page renders what the report says — numbers, tiers,
  gaps included. If the page needs a fact the report lacks, that's a Phase 1 gap; say so.
- **Keep the negative findings.** Verified negatives and research gaps are the credibility
  of the artifact; don't polish them out for the branded version.
- **One revision pass** offered after the URL, per share-as-page.
- The markdown report always exists even if the page/deploy fails — never let Phase 2/3
  errors destroy or block Phase 1 output.
