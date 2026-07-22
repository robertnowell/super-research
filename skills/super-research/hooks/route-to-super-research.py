#!/usr/bin/env python3
"""
UserPromptSubmit hook for the super-research skill.

Skill triggering is model judgment, not a deterministic rule — so a prompt that
plainly asks for research (or "deep research") can get hand-rolled, or worse,
routed to Claude Code's token-heavy built-in `/deep-research` workflow. This hook
closes that gap: when the user's prompt asks for research, it injects a reminder
to route through the `super-research` skill (via the Skill tool) and NOT the
built-in workflow.

Register in ~/.claude/settings.json as a UserPromptSubmit hook.

Contract: reads the UserPromptSubmit JSON event on stdin, emits JSON with
hookSpecificOutput.additionalContext when it matches. Always exits 0 so it can
never block prompt submission.
"""
import json
import re
import sys

# Phrases super-research should own. Kept reasonably tight so it doesn't fire on
# every casual lookup — but it DOES deliberately claim "deep research" so that
# intent is steered to super-research rather than the built-in /deep-research
# workflow (which we cannot delete, only route around).
TRIGGERS = [
    r"\bsuper[\s\-]?research\b",
    r"\bdeep[\s\-]?research\b",
    r"\bdeeply\s+research\b",
    r"\bresearch\b[^.?!]{0,40}\b(page|report|link|write[\s\-]?up|brief|deck)\b",
    r"\b(research|deep[\s\-]?dive)\b[^.?!]{0,40}\bdeeply\b",
]

REMINDER = (
    "This is a research request. Handle it with the `super-research` skill "
    "(Skill tool, skill: \"super-research\"). Do NOT run Claude Code's built-in "
    "`/deep-research` workflow and do NOT call the Workflow tool for this — "
    "super-research drives a bounded, Agent-based research engine "
    "(`super-research-engine`) and, when the user wants it, renders the result as "
    "a shareable page. If the question is underspecified, ask 1-3 clarifying "
    "questions FIRST, then invoke the skill."
)


def main() -> int:
    try:
        event = json.load(sys.stdin)
    except Exception:
        return 0  # never block on malformed input

    prompt = str(event.get("prompt", ""))
    if not prompt:
        return 0

    if not any(re.search(pat, prompt, re.IGNORECASE) for pat in TRIGGERS):
        return 0

    out = {
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": REMINDER,
        }
    }
    print(json.dumps(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
