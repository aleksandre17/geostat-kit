#!/usr/bin/env bash
# Local backend ops smoke — manifest paths, no branded container names
set -euo pipefail
PKG="$(cd "$(dirname "$0")/.." && pwd)"
export PYTHONPATH="${PKG}${PYTHONPATH:+:$PYTHONPATH}"
export GEOSTAT_KIT_ROOT="$PKG"
if [[ -z "${GEOSTAT_PROJECT_ROOT:-}" ]]; then
  export GEOSTAT_PROJECT_ROOT="$(cd "$PKG/../.." && pwd)"
fi

python3 - <<'PY'
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lib.project_context import ProjectContext
from lib.deploy_paths import resolve_backend_deploy_path

ctx = ProjectContext.discover()
deploy = ctx.secrets_module_dir("backend") / ".env.deploy"
if not deploy.is_file():
    raise SystemExit("FAIL: missing backend .env.deploy at " + str(deploy))
text = deploy.read_text(encoding="utf-8")
if "DEPLOY_LAYOUT=structured" not in text:
    raise SystemExit("FAIL: DEPLOY_LAYOUT=structured required")
names = ctx.compose_service_names()
api = names["api"]
base = "/home/example/my-app/" + ctx.module_path("backend").name
assert "runtime" in resolve_backend_deploy_path(base=base, container_name=api, kind="runtime", layout="structured")
assert "workspace" in resolve_backend_deploy_path(base=base, container_name=api, kind="workspace", layout="structured")
print("  OK manifest paths + deploy path resolution")
PY

cd "$PKG"
python3 -m pytest tests/ -q --tb=line -k "backend" 2>/dev/null || python -m pytest tests/ -q --tb=line -k "backend"

echo ""
echo "  Backend ops smoke passed (local)."
echo ""
