# super-research

**Question in → tier-classified deep research → on-brand HTML report → hosted URL.**

A [Claude Code](https://claude.com/claude-code) skill that chains two other skills (included)
into one end-to-end research-publishing pipeline:

```
your question
   │
   ▼
super-research-    parallel research agents · source tier-classification (T1–T4)
   engine          cross-referencing · verification gates · confidence labels
   │               → markdown report on disk
   ▼
share-as-page      brand-token resolution (cached per domain) · self-contained HTML
   │               screenshot visual eval · zero external requests
   ▼
hosted URL         one-command Vercel deploy (surge/netlify fallbacks)
```

## The three skills

| Skill | Role |
|---|---|
| `super-research` | Thin orchestrator: scope → research → page → publish |
| `super-research-engine` | Multi-agent research with source tiers, contradiction resolution, and hard quality gates (every finding cited, failed angles disclosed, no fabricated URLs). Invoked by `super-research`; named distinctly so it never collides with Claude Code's built-in `/deep-research` workflow |
| `share-as-page` | Report → polished self-contained HTML wearing a real brand's tokens, visually verified via headless-Chrome screenshots before deploy |

Each also works standalone.

## Install

```bash
git clone https://github.com/robertnowell/super-research
cp -R super-research/skills/* ~/.claude/skills/
```

Optional but recommended — the deterministic trigger hook (skill discovery by
description-matching is probabilistic; a hook isn't). Register
`skills/super-research/hooks/route-to-super-research.py` as a `UserPromptSubmit`
hook in `~/.claude/settings.json`. It steers research prompts to `super-research`
and away from Claude Code's token-heavy built-in `/deep-research` workflow.

> **Heads up:** newly installed skills may need a fresh Claude Code session before
> they're callable — if `/super-research` isn't found, start a new session.

## Use

In Claude Code:

```
/super-research <your question>
```

or just ask naturally: *"deep research X and make me a page for <audience>"*.

The skill will ask (at most once) about research depth, whose brand the page should
wear, and whether the content is too sensitive for an auto-deploy.

## Requirements

- Claude Code
- Chrome/Chromium (screenshot visual-eval gate)
- `vercel` CLI, logged in (deploy step; surge/netlify work as fallbacks)

## Notes

- Pages are single self-contained HTML files: inline CSS, base64 logos, no external
  requests. They render double-clicked offline and print cleanly to PDF (⌘P).
- Brand tokens are cached per domain in `share-as-page/brands/*.json` after first
  resolution, so the second page for a brand is instant.
- The research report (markdown) is always preserved on disk as the source of truth;
  the page renders it and never silently adds facts.
- The research engine is deliberately named `super-research-engine`, **not**
  `deep-research`: the bare name `deep-research` collides with Claude Code's built-in
  `/deep-research` workflow (a separate, token-heavy primitive) that would shadow this
  skill and fire instead. Don't rename it back. As defense-in-depth, `super-research`
  and the engine both set `disallowed-tools: Workflow`.

## Token footprint

super-research runs on Claude Code's **Agent** tool, not the **Workflow** tool — deliberately.
A quick-scope run fans out 2 research agents at **~25k tokens each (~51k total, measured)**; a
full run lands around **~100k**. Claude Code's built-in `/deep-research` workflow, by contrast,
routinely runs **>3M tokens per run** (measured, observed repeatedly). Same multi-agent research,
1–2 orders of magnitude less spend — which is also why the engine sets `disallowed-tools: Workflow`.

## License

MIT
