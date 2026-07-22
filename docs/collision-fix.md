# super-research: collision fix — implementation & test plan

## Why (one line)
`super-research` Phase 1 calls `Skill("deep-research")`, and that bare name resolves to Claude Code's **built-in `/deep-research` workflow** (token-heavy), which shadows the repo's own Agent-based engine. Fix = give the engine a non-colliding name so Phase 1 can only ever hit the repo's skill, plus layered guards.

## Change set

### 1. Rename the engine — load-bearing, deterministic
- Dir: `skills/deep-research/` → `skills/super-research-engine/`
- Frontmatter: `name: deep-research` → `name: super-research-engine`
- No built-in owns that name, so `Skill("super-research-engine")` can only resolve to this file. The failure path is severed at the source (not tool-gating dependent).

### 2. Repoint super-research Phase 1
In `skills/super-research/SKILL.md`:
- `Research engine: ~/.claude/skills/deep-research/` → `~/.claude/skills/super-research-engine/`
- Phase 1: `Invoke the **deep-research** skill (…skill: "deep-research")` → `…super-research-engine`
- `Do not skip or reimplement deep-research` → `…super-research-engine`
- **Grep gate:** zero occurrences of `skill: "deep-research"` or bare engine name `deep-research` in `super-research/SKILL.md` after the edit. (`share-as-page` refs stay — no collision.)

### 3. `disallowed-tools: Workflow` — proven defense-in-depth
Add to BOTH frontmatters:

```yaml
# super-research/SKILL.md
allowed-tools: Bash, Write, Read, Edit, WebFetch, WebSearch, Agent, Skill
disallowed-tools: Workflow
```
```yaml
# super-research-engine/SKILL.md
allowed-tools: Bash, Read, WebFetch, WebSearch, Agent
disallowed-tools: Workflow
```
Empirically a HARD gate (permission-layer auto-deny) that composes across the nested `Skill()` hop. Caveat: turn-scoped (covers Phase 1's turn; clears at next message) — hence second layer, not the guarantee.

### 4. Repurpose the routing hook — steer users in, and away from the built-in
- Move/rename `deep-research/hooks/route-to-deep-research.py` → `super-research/hooks/route-to-super-research.py`
- Triggers + reminder:

```python
TRIGGERS = [
    r"\bsuper[\s\-]?research\b",
    r"\bdeep[\s\-]?research\b",
    r"\bresearch\b[^.?!]{0,40}\b(page|report|link|write[\s\-]?up|brief)\b",
    r"\b(research|deep[\s\-]?dive)\b[^.?!]{0,40}\bdeeply\b",
]
REMINDER = (
    "This is a research request. Handle it with the `super-research` skill "
    "(Skill tool, skill: \"super-research\"). Do NOT run Claude Code's built-in "
    "`/deep-research` workflow or call the Workflow tool for this — super-research "
    "drives a bounded Agent-based engine (super-research-engine) and, when asked, "
    "renders the result as a page. If scope is unclear, ask 1-3 questions first."
)
```

⚠️ OPEN ITEM (verify before relying): a hook file in `skills/*/hooks/` may not auto-run — Claude Code hooks are normally registered in `settings.json` (`UserPromptSubmit`). Confirm how the repo wires it (plugin hook manifest vs. install step). If inert, description/README are the only steering. Testable — see Test A.

### 5. Descriptions
- `super-research`: "…Use for any deep-research or research-to-page request. Prefer this over Claude Code's built-in deep-research workflow, which this skill routes around."
- `super-research-engine`: "Internal research engine invoked by `super-research`. Not a direct front door — use `super-research` instead."

### 6. README
- Entry point: run `super-research`; don't invoke the built-in `/deep-research` workflow directly (the expensive path this repo routes around).
- Architecture: super-research (orchestrator) → super-research-engine (bounded Agent research) → share-as-page (URL). Name the built-in collision explicitly so nobody renames the engine back to `deep-research`.
- Install note: newly installed skills may need a session refresh before callable — if `super-research` isn't found, start a new session.
- Remove lingering `deep-research` naming.

---

## Post-change test plan (one fresh session)
Tests the real repo flow (the WebFetch/Read probes already validated the mechanism).

| # | Test | Action | PASS |
|---|------|--------|------|
| A | Front-door routing | "deep research the X market and make me a page" | Model reaches for `super-research`; hook reminder appears (or strong description wins). Built-in workflow NOT chosen. |
| B | Engine resolves to skill | Let Phase 1 run | Invokes `Skill("super-research-engine")`; Agent-based fan-out via the Agent tool. |
| C | No Workflow ever | Watch full run | Zero `Workflow(...)` calls. Optional: hand-attempt a Workflow call mid-turn → BLOCKED. |
| D | Collision severed | `grep -rn 'deep-research' skills/super-research/` | No matches; bare `Skill("deep-research")` never issued. |

Definition of done: A–D pass live + static grep gate (Change 2) clean.
Token sanity: engine agent count matches scope (2/3/5 for quick/standard/thorough); no runaway workflow-scale spawn.

## Residual caveats
1. Hook registration unverified (highest-priority unknown; Test A settles it).
2. Built-in `/deep-research` can't be deleted — only routed around; a user manually typing `/deep-research` still hits it.
3. `disallowed-tools` is turn-scoped — rename stays primary.
4. Composition proof is one-hop / one-tool (replicated twice) — strong, not exhaustive.

## Housekeeping
- Throwaway probe skills deleted (sr-gate-outer/inner, sr-disallow-probe, gate-test).
