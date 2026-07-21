# super-research

**Question in → tier-classified deep research → on-brand HTML report → hosted URL.**

A [Claude Code](https://claude.com/claude-code) skill that chains two other skills (included)
into one end-to-end research-publishing pipeline:

```
your question
   │
   ▼
deep-research      parallel research agents · source tier-classification (T1–T4)
   │               cross-referencing · verification gates · confidence labels
   ▼               → markdown report on disk
share-as-page      brand-token resolution (cached per domain) · self-contained HTML
   │               screenshot visual eval · zero external requests
   ▼
hosted URL         one-command Vercel deploy (surge/netlify fallbacks)
```

## The three skills

| Skill | Role |
|---|---|
| `super-research` | Thin orchestrator: scope → research → page → publish |
| `deep-research` | Multi-agent research with source tiers, contradiction resolution, and hard quality gates (every finding cited, failed angles disclosed, no fabricated URLs) |
| `share-as-page` | Report → polished self-contained HTML wearing a real brand's tokens, visually verified via headless-Chrome screenshots before deploy |

Each also works standalone.

## Install

```bash
git clone https://github.com/robertnowell/super-research
cp -R super-research/skills/* ~/.claude/skills/
```

Optional but recommended — the deterministic trigger hook (skill discovery by
description-matching is probabilistic; a hook isn't). Register
`skills/deep-research/hooks/route-to-deep-research.py` as a `UserPromptSubmit`
hook in `~/.claude/settings.json`.

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

## License

MIT
