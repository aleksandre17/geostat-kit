#!/usr/bin/env python3
"""Render nginx.conf from geostat.ops.json adapters.nginx + ops/config (manifest-driven)."""
from __future__ import annotations

import sys
from pathlib import Path

# Package lib on PYTHONPATH or kit root
_PKG = Path(__file__).resolve().parents[1]
if str(_PKG) not in sys.path:
    sys.path.insert(0, str(_PKG))

from lib.project_context import ProjectContext  # noqa: E402

PLACEHOLDER = "__NGINX_FRAME_ANCESTORS__"
DEFAULT_ANCESTORS = "'self' http://localhost:5173 http://localhost:5174 http://localhost:5177 http://127.0.0.1:5177"


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
    try:
        ctx = ProjectContext.discover()
    except FileNotFoundError:
        print("ERROR: project root not found (geostat.ops.json)", file=sys.stderr)
        return 1

    root = ctx.root
    nginx = (ctx.manifest.get("adapters") or {}).get("nginx") or {}
    if not isinstance(nginx, dict):
        nginx = {}

    template = root / str(nginx.get("template", "apps/frontend/nginx.conf.template"))
    output = root / str(nginx.get("output", "apps/frontend/nginx.conf"))
    env_example = root / str(nginx.get("envExample", "ops/config/frontend/nginx.env.example"))
    env_file = root / str(nginx.get("env", "ops/config/frontend/nginx.env"))

    if not template.is_file():
        print(f"ERROR: missing {template}", file=sys.stderr)
        return 1

    env: dict[str, str] = {}
    for path in (env_example, env_file, ctx.secrets_root / "deploy.env"):
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
