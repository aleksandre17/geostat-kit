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

# --- Module / secrets paths (manifest modules.*) ---

geostat_module_path() {
  local module_id="$1" proj rel
  proj="$(geostat_find_project_root)" || return 1
  rel="$(geostat_read_manifest_field "modules.${module_id}.path" "")"
  [[ -n "$rel" ]] || return 1
  echo "$proj/$rel"
}

geostat_secrets_module_name() {
  local module_id="$1" sm
  sm="$(geostat_read_manifest_field "modules.${module_id}.secretsModule" "$module_id")"
  echo "$sm"
}

geostat_secrets_dir_for_module() {
  local module_id="$1"
  echo "$(geostat_secrets_root)/$(geostat_secrets_module_name "$module_id")"
}

geostat_stack_compose_dir() {
  local proj rel
  proj="$(geostat_find_project_root)" || return 1
  rel="$(geostat_read_manifest_field stack.composeDir ops/compose/stack)"
  echo "$proj/$rel"
}

geostat_manifest_feature_enabled() {
  local name="$1" mf
  mf="$(_geostat_manifest_file 2>/dev/null)" || { echo "false"; return; }
  python3 -c "
import json, sys
m = json.load(open(sys.argv[1], encoding='utf-8'))
f = (m.get('features') or {}).get(sys.argv[2])
print('true' if f is True else 'false')
" "$mf" "$name" 2>/dev/null || echo "false"
}

# Secrets folder names from manifest modules (one per line)
geostat_list_secrets_module_folders() {
  local mf
  mf="$(_geostat_manifest_file 2>/dev/null)" || return 0
  python3 -c "
import json, sys
m = json.load(open(sys.argv[1], encoding='utf-8'))
seen = []
for mid, cfg in (m.get('modules') or {}).items():
    if not isinstance(cfg, dict):
        continue
    folder = str(cfg.get('secretsModule', mid))
    if folder not in seen:
        seen.append(folder)
        print(folder)
" "$mf" 2>/dev/null
}

# Fallback remote DEPLOY_PATH base: {server_base}/{project_slug}/{secrets_folder}
geostat_default_remote_deploy_base() {
  local secrets_folder="$1" base proj
  base="$(geostat_env_value "$secrets_folder" DEPLOY_PATH "")"
  if [[ -n "$base" ]]; then
    echo "${base%/}"
    return 0
  fi
  proj="$(geostat_project_slug)"
  base="$(geostat_server_base)/$proj/$secrets_folder"
  echo "${base%/}"
}
