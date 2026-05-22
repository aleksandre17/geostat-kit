#!/bin/bash
# Prepare minimal secrets for CI (manifest-driven paths)
set -euo pipefail
PKG="$(cd "$(dirname "$0")/.." && pwd)"
ROOT="$(cd "$PKG/../.." && pwd)"
export GEOSTAT_PROJECT_ROOT="$ROOT"

MF="$ROOT/geostat.ops.json"
SECRETS="secrets"
if [[ -f "$MF" ]]; then
  SECRETS="$(python3 -c "import json;print(json.load(open('$MF')).get('secrets','secrets'))")"
fi

BE="$ROOT/$SECRETS/backend"
FE="$ROOT/$SECRETS/frontend"
STACK="$(python3 -c "import json;print(json.load(open('$MF')).get('stack',{}).get('composeDir','deploy/compose'))" 2>/dev/null || echo deploy/compose)"

mkdir -p "$BE" "$FE" "$ROOT/$STACK"

for f in .env.dev .env.prod; do
  [[ -f "$BE/$f" ]] || cp "$BE/.env.example" "$BE/$f"
done
[[ -f "$BE/google-credentials.json" ]] || echo '{}' >"$BE/google-credentials.json"
[[ -f "$FE/.env.dev" ]] || cp "$FE/.env.example" "$FE/.env.dev" 2>/dev/null || echo "VITE_API_URL=http://localhost:8090" >"$FE/.env.dev"
[[ -f "$ROOT/$SECRETS/deploy.env" ]] || cp "$ROOT/$SECRETS/deploy.env.example" "$ROOT/$SECRETS/deploy.env"

echo "[ci] Integration env ready under $SECRETS/"
