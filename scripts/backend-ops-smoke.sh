#!/usr/bin/env bash
# Local backend ops smoke — pytest + optional dry-run path checks (no SSH deploy)
set -euo pipefail
PKG="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$PKG/../.." && pwd)"
export PYTHONPATH="${PKG}${PYTHONPATH:+:$PYTHONPATH}"
export GEOSTAT_PROJECT_ROOT="$REPO"
export GEOSTAT_KIT_ROOT="$PKG"

echo "  [1/3] ops/config/backend/.env.deploy"
if [[ ! -f "$REPO/ops/config/backend/.env.deploy" ]]; then
  echo "  FAIL: missing ops/config/backend/.env.deploy"
  exit 1
fi
grep -q 'DEPLOY_LAYOUT=structured' "$REPO/ops/config/backend/.env.deploy" || {
  echo "  FAIL: DEPLOY_LAYOUT=structured required"
  exit 1
}
echo "  OK"

echo "  [2/3] pytest (geostat-kit)"
cd "$PKG"
python3 -m pytest tests/ -q --tb=line -k "backend" 2>/dev/null || python -m pytest tests/ -q --tb=line -k "backend"
echo "  OK"

echo "  [3/3] path resolution (python)"
python3 - <<'PY' 2>/dev/null || python - <<'PY'
from lib.deploy_paths import resolve_backend_deploy_path
base = "/home/administrator/geostat/backend"
api = "geostat-chat-bot-api"
assert "runtime" in resolve_backend_deploy_path(base=base, container_name=api, kind="runtime", layout="structured")
assert "workspace" in resolve_backend_deploy_path(base=base, container_name=api, kind="workspace", layout="structured")
print("  OK paths")
PY

echo ""
echo "  Backend ops smoke passed (local)."
echo "  Server checks: geostat be check  |  migrate: migrate-backend-layout.sh --dry-run"
echo ""
