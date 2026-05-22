#!/bin/bash
# Project manifest (geostat.ops.json) — package boundary resolution

_geostat_manifest_file() {
  local root="${GEOSTAT_PROJECT_ROOT:-}"
  if [[ -z "$root" ]]; then
    local dir="${1:-$(pwd)}"
    while [[ -n "$dir" && "$dir" != "/" ]]; do
      if [[ -f "$dir/geostat.ops.json" ]]; then
        echo "$dir/geostat.ops.json"
        return 0
      fi
      dir="$(dirname "$dir")"
    done
    return 1
  fi
  echo "$root/geostat.ops.json"
}

geostat_find_project_root() {
  if [[ -n "${GEOSTAT_PROJECT_ROOT:-}" ]]; then
    echo "$GEOSTAT_PROJECT_ROOT"
    return 0
  fi
  local dir="${1:-$(pwd)}" mf
  while [[ -n "$dir" && "$dir" != "/" ]]; do
    if [[ -f "$dir/geostat.ops.json" ]]; then
      echo "$dir"
      return 0
    fi
    if [[ -d "$dir/secrets" ]] || [[ -d "$dir/ops/config" ]]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

geostat_read_manifest_field() {
  local field="$1" default="${2:-}"
  local mf root
  mf="$(_geostat_manifest_file 2>/dev/null)" || { echo "$default"; return; }
  root="$(dirname "$mf")"
  python3 -c "
import json, sys
p = sys.argv[1]
f = sys.argv[2]
d = sys.argv[3]
with open(p, encoding='utf-8') as fh:
    m = json.load(fh)
keys = f.split('.')
v = m
for k in keys:
    if not isinstance(v, dict) or k not in v:
        print(d)
        sys.exit(0)
    v = v[k]
print(v if v is not None else d)
" "$mf" "$field" "$default" 2>/dev/null || echo "$default"
}

geostat_kit_package_root() {
  if [[ -n "${OPS_PACKAGE_ROOT:-}" ]]; then
    echo "$OPS_PACKAGE_ROOT"
    return 0
  fi
  if [[ -n "${GEOSTAT_KIT_ROOT:-}" ]]; then
    echo "$GEOSTAT_KIT_ROOT"
    return 0
  fi
  local proj rel pkg
  proj="$(geostat_find_project_root)" || return 1
  rel="$(geostat_read_manifest_field package "kits/geostat-kit")"
  pkg="$(cd "$proj" && cd "$rel" 2>/dev/null && pwd)"
  echo "$pkg"
}

geostat_kit_toolkit_bash() {
  echo "$(geostat_kit_package_root)/toolkit/bash"
}

geostat_kit_deploy_lib() {
  echo "$(geostat_kit_package_root)/toolkit/deploy"
}

geostat_kit_compose_catalog() {
  local proj
  proj="$(geostat_find_project_root)" || return 1
  echo "$proj/$(geostat_read_manifest_field compose.catalog ops/compose/catalog.json)"
}

geostat_kit_sync_modules_path() {
  local proj
  proj="$(geostat_find_project_root)" || return 1
  echo "$proj/$(geostat_read_manifest_field compose.syncModules apps/backend/ops.modules)"
}
