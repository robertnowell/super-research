#!/usr/bin/env python3
"""
UserPromptSubmit hook for the deep-research skill.

Skill triggering is model judgment, not a deterministic rule — so a prompt that
plainly asks for "deep research" can still get hand-rolled with ad-hoc Explore /
Agent fan-out that skips the skill's tiered source classification, cross-
referencing, and verification gates. This hook closes that gap: when the user's
prompt clearly asks for deep research, it injects a reminder that the request
MUST be routed through the `deep-research` skill (via the Skill tool).

Contract: reads the UserPromptSubmit JSON event on stdin, emits JSON with
hookSpecificOutput.additionalContext when it matches. Always exits 0 so it can
never block prompt submission.
"""
import json
import re
import sys

# Phrases that unambiguously ask for deep research. Kept tight on purpose — a
# bare "research X" is intentionally NOT matched, to avoid firing on every
# casual lookup. We want the explicit "deep research" intent.
TRIGGERS = [
    r"\bdeep[\s\-]?research\b",
    r"\bdeeply\s+research\b",
    r"\bresearch\b[^.?!]{0,40}\bdeeply\b",
    r"\bdeep[\s\-]?dive\b[^.?!]{0,40}\bresearch\b",
]

REMINDER = (
    "The user's prompt asks for deep research. This MUST be handled by invoking "
    "the `deep-research` skill via the Skill tool (skill: \"deep-research\"), "
    "NOT by hand-rolling your own Explore/Agent fan-out. The skill exists to add "
    "what ad-hoc agents skip: source tier-classification, cross-referencing, and "
    "the verification quality gates. Pass the refined research question as args. "
    "If the question is underspecified, ask 1-3 clarifying questions FIRST, then "
    "invoke the skill. Do not substitute generic verification agents for it."
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
