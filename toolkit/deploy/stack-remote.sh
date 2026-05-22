#!/bin/bash
# Full-stack remote deploy — steps from geostat.ops.json stackDeploy (or defaults)
# Usage: geostat stack-deploy [--dev|--prod] [--no-build] [--skip-checks]

set -euo pipefail
PKG="$(cd "$(dirname "$0")/../.." && pwd)"
ROOT="$(cd "$PKG/../.." && pwd)"
export GEOSTAT_PROJECT_ROOT="$ROOT"
export GEOSTAT_KIT_ROOT="$PKG"

ENV_FLAG="--prod"
EXTRA=()
for arg in "$@"; do
  case "$arg" in
    --dev)  ENV_FLAG="--dev" ;;
    --prod) ENV_FLAG="--prod" ;;
    *)      EXTRA+=("$arg") ;;
  esac
done

ENV_NAME="prod"
[[ "$ENV_FLAG" == "--dev" ]] && ENV_NAME="dev"

echo ""
echo "  Stack remote deploy [$ENV_FLAG]"
echo ""

step=0
geostat_python() {
  if command -v python3 &>/dev/null; then python3 "$@"
  elif command -v py &>/dev/null; then py -3 "$@"
  else python "$@"
  fi
}

mapfile -t LINES < <(geostat_python "$PKG/lib/driver_api.py" stack-steps $([[ "$ENV_FLAG" == "--dev" ]] && echo --dev))
total="${#LINES[@]}"

for line in "${LINES[@]}"; do
  step=$((step + 1))
  IFS=$'\t' read -r module_id subcmd args_rest <<< "$line"
  args=()
  if [[ -n "${args_rest:-}" ]]; then
    # shellcheck disable=SC2206
    args=($args_rest)
  fi
  if [[ "$subcmd" == "deploy" ]]; then
    args+=("$ENV_FLAG")
    args+=("${EXTRA[@]}")
  fi
  echo "  $step/$total  module=$module_id  $subcmd ${args[*]}"
  echo ""
  # shellcheck disable=SC2086
  powershell.exe -ExecutionPolicy Bypass -NoProfile -File \
    "$ROOT/tools/geostat.ps1" mod "$module_id" "$subcmd" "${args[@]}"
  echo ""
done

echo "  Stack deploy finished."
echo ""
