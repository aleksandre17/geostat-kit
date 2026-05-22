#!/usr/bin/env python3
"""CLI for PowerShell: module roles / lists (GEOSTAT_PROJECT_ROOT required)."""
from __future__ import annotations

import sys

from lib.project_context import ProjectContext


def main() -> int:
    if len(sys.argv) < 2:
        return 1
    op = sys.argv[1]
    try:
        ctx = ProjectContext.discover()
    except FileNotFoundError as e:
        print(str(e), file=sys.stderr)
        return 1
    if op == "role" and len(sys.argv) >= 3:
        print(ctx.get_module_role(sys.argv[2]))
        return 0
    if op == "by-role" and len(sys.argv) >= 3:
        for mid in ctx.module_ids_for_role(sys.argv[2]):
            print(mid)
        return 0
    if op == "aliases":
        for k, v in sorted(ctx.cli_aliases().items()):
            print(f"{k}\t{v}")
        return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
