"""
Deploy path resolution — single source for tests and tooling.
Mirrors packages/geostat-kit/toolkit/powershell/Deploy-Path.ps1
"""
from __future__ import annotations

import re
from typing import Literal

FrontendDeployKind = Literal["static", "compose-dev", "compose-prod"]
BackendDeployKind = Literal["runtime", "workspace"]
DeployKind = FrontendDeployKind
VALID_LAYOUTS = frozenset({"structured", "flat", "legacy"})
VALID_PATH_MODES = frozenset({"base", "full"})

RSYNC_DEFAULT_EXCLUDES = (
    "node_modules/",
    "dist/",
    "build/",
    ".git/",
    ".idea/",
    ".vscode/",
    "logs/",
    "coverage/",
    ".angular/",
    "tmp/",
    ".turbo/",
    ".next/",
    "deploy-staging/",
    ".cache/",
    "*.log",
)


def normalize_base(base: str) -> str:
    return base.strip().rstrip("/")


def resolve_module_deploy_path(
    *,
    base: str,
    container_name: str,
    kind: DeployKind,
    layout: str = "structured",
    path_mode: str = "base",
) -> str:
    if not base:
        raise ValueError("DEPLOY_PATH or DEPLOY_SERVER_BASE required")
    base = normalize_base(base)
    if path_mode not in VALID_PATH_MODES:
        path_mode = "base"
    if layout not in VALID_LAYOUTS:
        layout = "structured"

    if path_mode == "full":
        if base.endswith(f"/{container_name}"):
            return base
        return base

    if layout == "structured":
        if kind == "static":
            return f"{base}/static/{container_name}"
        if kind == "compose-dev":
            return f"{base}/compose/dev/{container_name}"
        return f"{base}/compose/prod/{container_name}"

    if base.endswith(f"/{container_name}"):
        return base
    return f"{base}/{container_name}"


def resolve_backend_deploy_path(
    *,
    base: str,
    container_name: str,
    kind: BackendDeployKind = "runtime",
    layout: str = "structured",
    path_mode: str = "base",
) -> str:
    if not base:
        raise ValueError("DEPLOY_PATH or DEPLOY_SERVER_BASE required")
    base = normalize_base(base)
    if path_mode not in VALID_PATH_MODES:
        path_mode = "base"
    if layout not in VALID_LAYOUTS:
        layout = "flat"

    if path_mode == "full":
        if base.endswith(f"/{container_name}"):
            return base
        return base

    if layout == "structured":
        if kind == "workspace":
            return f"{base}/workspace/{container_name}"
        return f"{base}/runtime/{container_name}"

    if base.endswith(f"/{container_name}"):
        return base
    return f"{base}/{container_name}"


def backend_deploy_path_candidates(*, base: str, container_name: str) -> list[str]:
    base = normalize_base(base)
    if not base:
        return []
    return [
        f"{base}/runtime/{container_name}",
        f"{base}/workspace/{container_name}",
        f"{base}/{container_name}",
    ]


def deploy_path_candidates(*, base: str, container_name: str) -> list[str]:
    base = normalize_base(base)
    if not base:
        return []
    return [
        f"{base}/static/{container_name}",
        f"{base}/compose/prod/{container_name}",
        f"{base}/compose/dev/{container_name}",
        f"{base}/{container_name}",
    ]


def infer_server_base_from_ssh(server: str) -> str | None:
    m = re.match(r"^[^@]+@(.+)$", server.strip())
    if not m:
        return None
    user = server.split("@", 1)[0]
    return f"/home/{user}"
