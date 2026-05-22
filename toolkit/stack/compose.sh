#!/bin/bash
# Full stack compose runner (manifest: stack.composeDir)
set -euo pipefail
PKG="$(cd "$(dirname "$0")/../.." && pwd)"
ROOT="$(cd "$PKG/../.." && pwd)"
export GEOSTAT_PROJECT_ROOT="$ROOT"
# shellcheck source=../../lib/env.sh
source "$PKG/lib/env.sh"

COMPOSE_REL="$(geostat_read_manifest_field stack.composeDir deploy/compose)"
COMPOSE_DIR="$ROOT/$COMPOSE_REL"

PROD=0
REMAIN=()
for arg in "$@"; do
  case "$arg" in
    -Prod|--prod) PROD=1 ;;
    *) REMAIN+=("$arg") ;;
  esac
done

if [[ "$PROD" -eq 1 ]]; then
  PROFILE=prod
  COMPOSE_FILE=docker-compose.prod.yml
else
  PROFILE=dev
  COMPOSE_FILE=docker-compose.yml
fi

ENV_ARGS=()
while IFS= read -r f; do
  [[ -n "$f" ]] && ENV_ARGS+=(--env-file "$f")
done < <(geostat_stack_env_files "$PROFILE")

cd "$COMPOSE_DIR"
STACK_NAME="$(geostat_deploy_env_value COMPOSE_PROJECT_NAME "$(basename "$ROOT")")"
UI_PORT="$(geostat_env_value frontend DEPLOY_HOST_PORT "5177")"
API_PORT_VAL="$(geostat_env_value backend API_PORT "8090")"
echo ""
echo "  $STACK_NAME stack ($PROFILE)"
echo "  UI  -> http://localhost:${UI_PORT}"
echo "  API -> http://localhost:${API_PORT_VAL}"
echo ""

exec docker compose "${ENV_ARGS[@]}" -f "$COMPOSE_FILE" "${REMAIN[@]}"
