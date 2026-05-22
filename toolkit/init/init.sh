#!/usr/bin/env bash
# geostat init — bash entry (calls PowerShell implementation when available)
set -euo pipefail
PKG="$(cd "$(dirname "$0")/../.." && pwd)"
TARGET="${1:-}"
INIT_PS1="$PKG/toolkit/init/Invoke-ProjectInit.ps1"
shift || true

if command -v powershell.exe >/dev/null 2>&1; then
  args=(-ExecutionPolicy Bypass -File "$INIT_PS1")
  [[ -n "$TARGET" ]] && args+=(-ProjectRoot "$(cd "$TARGET" && pwd)")
  args+=("$@")
  exec powershell.exe "${args[@]}"
fi

# Fallback: scaffold + seed + compose (no nginx / gitignore merge)
SCAFFOLD="$PKG/scaffold"
ROOT="${TARGET:-$(pwd)}"
while [[ -n "$ROOT" && "$ROOT" != "/" ]]; do
  [[ -f "$ROOT/geostat.ops.json" ]] && break
  ROOT="$(dirname "$ROOT")"
done
[[ -f "$ROOT/geostat.ops.json" ]] || ROOT="$(cd "$PKG/../.." && pwd)"

export GEOSTAT_PROJECT_ROOT="$ROOT"
export GEOSTAT_KIT_ROOT="$PKG"

echo ""
echo "  geostat init (bash) → $ROOT"
bash "$SCAFFOLD/apply-scaffold.sh" "$ROOT"

copy_seed() {
  local ex="$1" tg="$2"
  [[ -f "$ROOT/$ex" ]] || return 0
  [[ -f "$ROOT/$tg" ]] && return 0
  mkdir -p "$(dirname "$ROOT/$tg")"
  cp "$ROOT/$ex" "$ROOT/$tg"
  echo "  [OK]   $tg ← $ex"
}

echo ""
echo "  ▸ Seed secrets"
copy_seed ops/config/deploy.env.example ops/config/deploy.env
copy_seed ops/config/frontend/.env.example ops/config/frontend/.env.dev
copy_seed ops/config/frontend/.env.example ops/config/frontend/.env.prod
copy_seed ops/config/frontend/.env.deploy.example ops/config/frontend/.env.deploy
copy_seed ops/config/backend/.env.example ops/config/backend/.env.dev
copy_seed ops/config/backend/.env.example ops/config/backend/.env.prod
copy_seed ops/config/backend/.env.deploy.example ops/config/backend/.env.deploy

if [[ ! -f "$ROOT/infra/compose/catalog.json" && -f "$SCAFFOLD/infra/compose/catalog.full.json" ]]; then
  mkdir -p "$ROOT/infra/compose"
  cp "$SCAFFOLD/infra/compose/catalog.full.json" "$ROOT/infra/compose/catalog.json"
  echo "  [OK]   infra/compose/catalog.json (full)"
fi

echo ""
echo "  ▸ compose-gen"
python3 "$PKG/compose/build.py" || echo "  [warn] compose-gen failed"

echo ""
echo "  Next: edit ops/config/deploy.env, then: ./tools/geostat.sh compose-gen"
echo ""
