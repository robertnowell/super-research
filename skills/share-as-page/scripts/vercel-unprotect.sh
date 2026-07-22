#!/usr/bin/env bash
# vercel-unprotect.sh — disable Vercel Deployment Protection (Vercel Authentication)
# for a SINGLE deployed project so its URL is publicly reachable. Scoped by the project
# id in <project-dir>/.vercel/project.json — the team default and all other projects are
# left untouched. Reversible (re-enable in the dashboard, or PATCH ssoProtection back).
#
# Usage: vercel-unprotect.sh <project-dir> [deployed-url]
#   - Reads projectId/orgId from <project-dir>/.vercel/project.json (created by `vercel deploy`).
#   - Auth: $VERCEL_TOKEN if set, else the ambient CLI token from auth.json.
#   - If a URL is given, re-verifies it is publicly reachable afterward.
set -euo pipefail

DIR="${1:?usage: vercel-unprotect.sh <project-dir> [deployed-url]}"
URL="${2:-}"
LINK="$DIR/.vercel/project.json"
[ -f "$LINK" ] || { echo "error: $LINK not found (run a deploy first so the project is linked)" >&2; exit 1; }

PID="$(python3 -c "import json;print(json.load(open('$LINK'))['projectId'])")"
TEAM="$(python3 -c "import json;print(json.load(open('$LINK')).get('orgId',''))")"

TOKEN="${VERCEL_TOKEN:-}"
if [ -z "$TOKEN" ]; then
  for f in \
    "$HOME/Library/Application Support/com.vercel.cli/auth.json" \
    "$HOME/.local/share/com.vercel.cli/auth.json" \
    "$HOME/.config/com.vercel.cli/auth.json" \
    "$HOME/.vercel/auth.json"; do
    [ -f "$f" ] && TOKEN="$(python3 -c "import json;print(json.load(open('$f')).get('token',''))" 2>/dev/null || true)" && [ -n "$TOKEN" ] && break
  done
fi
[ -n "$TOKEN" ] || { echo "error: no Vercel token (set VERCEL_TOKEN or run 'vercel login')" >&2; exit 1; }

q=""; [ -n "$TEAM" ] && q="?teamId=$TEAM"

# Disable Vercel Authentication for this project (ssoProtection = null).
resp="$(curl -s -X PATCH "https://api.vercel.com/v9/projects/${PID}${q}" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"ssoProtection": null}')"

err="$(printf '%s' "$resp" | python3 -c "import sys,json;print(json.load(sys.stdin).get('error',{}).get('message','') if sys.stdin else '')" 2>/dev/null || true)"
[ -z "$err" ] || { echo "error: Vercel API: $err" >&2; exit 1; }

echo "ok: Vercel Authentication disabled for project $PID (this project only)."

# Optional: confirm the URL is now public.
if [ -n "$URL" ]; then
  sleep 2
  tmpb="$(mktemp)"; trap 'rm -f "$tmpb"' EXIT
  meta="$(curl -sL --max-time 25 -o "$tmpb" -w '%{http_code} %{url_effective}' "$URL" 2>/dev/null || echo '000 -')"
  code="${meta%% *}"; eff="${meta#* }"
  if printf '%s' "$eff" | grep -qiE 'vercel\.com/(sso|login)|/sso-api' || \
     grep -qiE 'Authentication Required|_vercel_sso_nonce|Vercel Authentication|<title>Login' "$tmpb"; then
    echo "warning: still gated after change — protection may be set at the team level; check the dashboard." >&2
    exit 3
  elif [ "$code" = "200" ]; then
    echo "verified: $URL is now publicly reachable."
  else
    echo "note: URL returned HTTP $code — may still be propagating." >&2
  fi
fi
