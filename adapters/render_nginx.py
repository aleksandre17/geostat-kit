#!/usr/bin/env python3
"""Render nginx.conf from geostat.ops.json adapters.nginx + secrets (manifest-driven)."""
from __future__ import annotations

import json
import sys
from pathlib import Path

PLACEHOLDER = "__NGINX_FRAME_ANCESTORS__"
DEFAULT_ANCESTORS = "'self' http://localhost:5173 http://localhost:5174 http://localhost:5177 http://127.0.0.1:5177"


def find_project_root() -> Path:
    if __import__("os").environ.get("GEOSTAT_PROJECT_ROOT"):
        return Path(__import__("os").environ["GEOSTAT_PROJECT_ROOT"]).resolve()
    start = Path.cwd().resolve()
    for p in [start, *start.parents]:
        if (p / "geostat.ops.json").is_file():
            return p
    print("ERROR: geostat.ops.json not found", file=sys.stderr)
    sys.exit(1)


def parse_env(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    if not path.is_file():
        return out
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, val = line.partition("=")
        val = val.strip()
        if len(val) >= 2 and val[0] == val[-1] and val[0] in "\"'":
            val = val[1:-1]
        if key.strip():
            out[key.strip()] = val
    return out


def main() -> int:
    root = find_project_root()
    mf = root / "geostat.ops.json"
    manifest = json.loads(mf.read_text(encoding="utf-8")) if mf.is_file() else {}
    nginx = manifest.get("adapters", {}).get("nginx", {})
    template = root / nginx.get("template", "frontend/nginx.conf.template")
    output = root / nginx.get("output", "frontend/nginx.conf")
    env_example = root / nginx.get("envExample", "secrets/frontend/nginx.env.example")
    env_file = root / nginx.get("env", "secrets/frontend/nginx.env")
    secrets = root / manifest.get("secrets", "secrets")

    if not template.is_file():
        print(f"ERROR: missing {template}", file=sys.stderr)
        return 1

    env: dict[str, str] = {}
    for path in (env_example, env_file, secrets / "deploy.env"):
        env.update(parse_env(path))

    ancestors = env.get("NGINX_FRAME_ANCESTORS", DEFAULT_ANCESTORS).strip() or DEFAULT_ANCESTORS
    text = template.read_text(encoding="utf-8")
    if PLACEHOLDER not in text:
        print(f"ERROR: template missing {PLACEHOLDER}", file=sys.stderr)
        return 1

    output.write_text(text.replace(PLACEHOLDER, ancestors), encoding="utf-8", newline="\n")
    print(f"  wrote {output.relative_to(root)}")
    print(f"  frame-ancestors: {ancestors[:80]}{'...' if len(ancestors) > 80 else ''}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
