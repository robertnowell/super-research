#!/usr/bin/env bash
# share-as-page deploy — push a directory containing index.html to a shareable URL.
# Primary: Vercel (non-interactive, persistent alias). Reads VERCEL_TOKEN from env if set,
# else uses ambient `vercel login`. Prints the live URL on success.
#
# Usage: deploy.sh <project-dir>
set -euo pipefail

DIR="${1:?usage: deploy.sh <project-dir containing index.html>}"
[ -f "$DIR/index.html" ] || { echo "error: $DIR/index.html not found" >&2; exit 1; }

command -v vercel >/dev/null 2>&1 || {
  echo "error: vercel CLI not found. Install: npm i -g vercel  (or use a fallback host)" >&2
  exit 1
}

cd "$DIR"

# --prod promotes to the production alias; --yes suppresses all setup prompts.
out="$(vercel deploy --prod --yes 2>&1)" || { echo "$out" >&2; exit 1; }

# Prefer the clean aliased URL; fall back to any *.vercel.app in the output.
url="$(printf '%s\n' "$out" | grep -i 'Aliased:' | grep -oE 'https://[^ ]+\.vercel\.app' | tail -1 || true)"
[ -z "$url" ] && url="$(printf '%s\n' "$out" | grep -oE 'https://[a-z0-9.-]+\.vercel\.app' | head -1 || true)"

if [ -z "$url" ]; then
  echo "$out" >&2
  echo "error: deployed but could not parse a URL from vercel output" >&2
  exit 1
fi

echo "$url"
