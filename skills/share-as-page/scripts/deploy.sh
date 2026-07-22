#!/usr/bin/env bash
# share-as-page deploy — push a directory containing index.html to a shareable URL,
# then VERIFY the URL is actually reachable by the public before reporting success.
# Primary: Vercel (non-interactive, persistent alias). Reads VERCEL_TOKEN from env if set,
# else uses ambient `vercel login`.
#
# Usage: deploy.sh <project-dir>
#
# Output contract (stdout), two lines on a successful deploy:
#   <url>
#   ACCESS: public | protected | unreachable
# Exit codes: 0 = deployed AND public · 3 = deployed BUT not publicly accessible
#             1 = deploy failed
#
# When ACCESS is not "public" the link is NOT ready to share — a remediation block is
# printed to stderr. For Vercel team Deployment Protection, run vercel-unprotect.sh.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

# --- Public-accessibility gate -------------------------------------------------
# A deploy is NOT "ready" until an unauthenticated fetch returns the real page.
# Vercel team Deployment Protection commonly redirects to a "Login" SSO page (often
# HTTP 200), so a bare status check is not enough — inspect the effective (post-
# redirect) URL and the body too.
access="public"
tmpb="$(mktemp)"; trap 'rm -f "$tmpb"' EXIT
meta="$(curl -sL --max-time 25 -o "$tmpb" -w '%{http_code} %{url_effective}' "$url" 2>/dev/null || echo '000 -')"
code="${meta%% *}"; eff="${meta#* }"

if printf '%s' "$eff" | grep -qiE 'vercel\.com/(sso|login)|/sso-api'; then
  access="protected"
elif grep -qiE 'Authentication Required|_vercel_sso_nonce|Vercel Authentication|<title>Login' "$tmpb"; then
  access="protected"
elif [ "$code" != "200" ]; then
  access="unreachable"
fi

# stdout: url + machine-readable access status (callers must parse BOTH lines).
echo "$url"
echo "ACCESS: $access"

[ "$access" = "public" ] && exit 0

{
  echo
  echo "⚠  DEPLOYED BUT NOT PUBLIC (ACCESS: $access) — do NOT tell the user the link is ready."
  if [ "$access" = "protected" ]; then
    echo "   The URL is behind Vercel Deployment Protection (team authentication). Anyone"
    echo "   without access to your Vercel team hits a login wall instead of the page."
    echo
    echo "   Make it public (THIS project only, reversible):"
    echo "     bash \"$HERE/vercel-unprotect.sh\" \"$DIR\""
    echo "   or Dashboard -> Project -> Settings -> Deployment Protection ->"
    echo "      Vercel Authentication -> Disabled."
  else
    echo "   The URL did not return the page (HTTP $code). It may still be propagating,"
    echo "   or the deploy is broken. Re-check in a moment before sharing."
  fi
} >&2
exit 3
