#!/bin/bash
# Project CI: backend compose smoke (uses geostat-kit package)
# Customize API_PORT / WORKER_PORT / compose file if your stack differs.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PKG="$ROOT/kits/geostat-kit"
BE="$ROOT/apps/backend"
API_PORT="${API_PORT:-8090}"
WORKER_PORT="${WORKER_PORT:-8091}"

export GEOSTAT_PROJECT_ROOT="$ROOT"
bash "$PKG/ci/prepare-integration-env.sh"
python3 "$PKG/compose/build.py"

cd "$BE"
export API_PORT WORKER_PORT
ENV_ARGS=(--env-file "$ROOT/ops/config/backend/.env.dev")
[[ -f "$ROOT/ops/config/deploy.env" ]] && ENV_ARGS+=(--env-file "$ROOT/ops/config/deploy.env")

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.dev.yml}"
echo "[ci] docker compose up (API + optional worker)..."
docker compose "${ENV_ARGS[@]}" -f "$COMPOSE_FILE" up -d --build

bash "$PKG/ci/wait-health.sh" "http://127.0.0.1:${API_PORT}/health" "UP" 120

if docker compose "${ENV_ARGS[@]}" -f "$COMPOSE_FILE" ps --format json 2>/dev/null | grep -q worker; then
  bash "$PKG/ci/wait-health.sh" "http://127.0.0.1:${WORKER_PORT}/actuator/health" "UP" 120
fi

echo "[ci] docker compose down..."
docker compose "${ENV_ARGS[@]}" -f "$COMPOSE_FILE" down -v
echo "[ci] Integration stack passed."
