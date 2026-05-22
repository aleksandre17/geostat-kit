#!/usr/bin/env python3
"""Sync ops.modules from manifest modules + catalog features."""
from __future__ import annotations

import json
import sys
from pathlib import Path

PACKAGE_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PACKAGE_ROOT / "compose"))
from build import find_project_root, global_fmt, load_catalog  # noqa: E402
from manifest_compose import ops_modules_lines  # noqa: E402

HEADER = "# GENERATED — do not edit. Run: geostat compose-gen\n"
SHARED = "|shared|library||yes\n"


def main() -> int:
    root = find_project_root()
    manifest_path = root / "geostat.ops.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8")) if manifest_path.is_file() else {}
    out_rel = manifest.get("compose", {}).get("syncModules", "apps/backend/ops.modules")
    out = root / out_rel

    from lib.project_context import ProjectContext

    ctx = ProjectContext(root=root, manifest=manifest)
    fmt = global_fmt(root)
    _, _, features = load_catalog(root)
    lines = [HEADER.rstrip(), "# Format: compose_service|gradle_module|type|dockerfile|enabled"]
    lines.extend(ops_modules_lines(ctx, fmt, features))
    lines.append(SHARED.rstrip())
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
    print(f"  wrote {out.relative_to(root)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
