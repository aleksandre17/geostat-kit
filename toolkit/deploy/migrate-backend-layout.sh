#!/bin/bash
# Migrate flat backend deploy dirs → structured runtime/ (server-side via SSH)
#
# Usage:
#   geostat toolkit ...  OR from repo:
#   bash kits/geostat-kit/toolkit/deploy/migrate-backend-layout.sh [--dry-run] [--dev|--prod]
#
# Requires: api module .env.deploy (DEPLOY_LAYOUT=structured), ops/config/deploy.env

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
export GEOSTAT_KIT_ROOT="$PKG_ROOT"

# shellcheck source=../../lib/project.sh
source "$PKG_ROOT/lib/project.sh"
# shellcheck source=../../lib/env.sh
source "$PKG_ROOT/lib/env.sh"

GEOSTAT_PROJECT_ROOT="$(geostat_find_project_root "$(pwd)" 2>/dev/null || echo "$(cd "$PKG_ROOT/../../.." && pwd)")"
export GEOSTAT_PROJECT_ROOT

OPS_MODULE_ID="$(geostat_module_id_for_role api)"
[[ -n "$OPS_MODULE_ID" ]] || OPS_MODULE_ID="$(geostat_module_id_for_type java-boot)"
[[ -n "$OPS_MODULE_ID" ]] || { echo "  ERROR: no api/java-boot module in geostat.ops.json" >&2; exit 1; }
OPS_SECRETS_MODULE="$(geostat_secrets_module_name "$OPS_MODULE_ID")"
SECRETS_DIR="$(geostat_secrets_dir_for_module "$OPS_MODULE_ID")"
SERVER="$(geostat_env_value "$OPS_SECRETS_MODULE" DEPLOY_SERVER "$(geostat_deploy_env_value DEPLOY_SERVER "")")"
PROJECT="$(geostat_env_value "$OPS_SECRETS_MODULE" DEPLOY_PROJECT "")"
[[ -n "$PROJECT" ]] || PROJECT="$(geostat_project_slug)"
DEPLOY_PATH_BASE="$(geostat_env_value "$OPS_SECRETS_MODULE" DEPLOY_PATH "")"
[[ -n "$DEPLOY_PATH_BASE" ]] || DEPLOY_PATH_BASE="$(geostat_default_remote_deploy_base "$OPS_SECRETS_MODULE")"
DEPLOY_PATH_BASE="${DEPLOY_PATH_BASE%/}"
LAYOUT="$(geostat_env_value "$OPS_SECRETS_MODULE" DEPLOY_LAYOUT "flat")"

DRY_RUN=0
ENVIRONMENT="prod"
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --dev) ENVIRONMENT="dev" ;;
    --prod) ENVIRONMENT="prod" ;;
  esac
done

COMPOSE_FILE="docker-compose.${ENVIRONMENT}.yml"

if [[ "$LAYOUT" != "structured" ]]; then
  echo "  ERROR: DEPLOY_LAYOUT must be structured in ${SECRETS_DIR}/.env.deploy" >&2
  exit 1
fi
[[ -n "$SERVER" ]] || { echo "  ERROR: DEPLOY_SERVER not set" >&2; exit 1; }

echo ""
echo "  Backend layout migration (flat → runtime/)"
echo "  Server: $SERVER"
echo "  Base:   $DEPLOY_PATH_BASE"
echo "  Mode:   $(if [[ $DRY_RUN -eq 1 ]]; then echo 'dry-run'; else echo 'apply'; fi)"
echo ""

ssh -n "$SERVER" "bash -s" -- "$DEPLOY_PATH_BASE" "$COMPOSE_FILE" "$DRY_RUN" <<'REMOTE'
set -euo pipefail
BASE="$1"
COMPOSE_FILE="$2"
DRY="$3"

for old in "$BASE"/*; do
  [[ -d "$old" ]] || continue
  name="$(basename "$old")"
  [[ "$name" == "runtime" || "$name" == "workspace" ]] && continue
  [[ -f "$old/$COMPOSE_FILE" || -f "$old/app.jar" || -f "$old/Dockerfile" ]] || continue
  new="$BASE/runtime/$name"
  if [[ -d "$new" ]]; then
    echo "  [skip] $name — runtime already exists: $new"
    continue
  fi
  if [[ "$DRY" == "1" ]]; then
    echo "  [dry-run] mv $old → $new"
  else
    mkdir -p "$BASE/runtime"
    mv "$old" "$new"
    echo "  [OK] mv $old → $new"
  fi
done
REMOTE

echo ""
echo "  Done. Verify: geostat be manage <service> status --$ENVIRONMENT"
echo ""
