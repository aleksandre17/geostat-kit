#!/usr/bin/env python3
"""Compose generator engine — reads project manifest + catalog (no app logic)."""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

PACKAGE_ROOT = Path(__file__).resolve().parents[1]
HEADER = "# GENERATED — do not edit. Run: geostat compose-gen\n\n"

DEPLOY_KEYS = (
    "DEPLOY_PROJECT",
    "COMPOSE_PROJECT_NAME",
    "COMPOSE_API_SERVICE",
    "COMPOSE_APP_SERVICE",
    "COMPOSE_WORKER_SERVICE",
    "DOCKER_NETWORK",
    "GEOSTAT_DOCKER_NETWORK",
    "API_PORT",
    "WORKER_PORT",
    "DEPLOY_HOST_PORT",
    "APP_DEV_CONTAINER_PORT",
)


def find_project_root() -> Path:
    if os.environ.get("GEOSTAT_PROJECT_ROOT"):
        return Path(os.environ["GEOSTAT_PROJECT_ROOT"]).resolve()
    start = Path.cwd().resolve()
    for p in [start, *start.parents]:
        if (p / "geostat.ops.json").is_file():
            return p
        if ((p / "ops" / "config").is_dir() or (p / "secrets").is_dir()) and (
            (p / "kits" / "geostat-kit").is_dir() or (p / "packages" / "geostat-kit").is_dir()
        ):
            return p
    raise SystemExit("ERROR: project root not found (geostat.ops.json or secrets/)")


def load_manifest(root: Path) -> dict:
    mf = root / "geostat.ops.json"
    if mf.is_file():
        return json.loads(mf.read_text(encoding="utf-8"))
    return {}


def catalog_path(root: Path, manifest: dict) -> Path:
    rel = manifest.get("compose", {}).get("catalog", "infra/compose/catalog.json")
    return root / rel


def slugify(text: str) -> str:
    s = re.sub(r"[^a-zA-Z0-9._-]+", "-", text.strip()).strip("-").lower()
    return s or "app"


def parse_env_file(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    if not path.is_file():
        return out
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, val = line.partition("=")
        key = key.strip()
        val = val.strip()
        if len(val) >= 2 and val[0] == val[-1] and val[0] in "\"'":
            val = val[1:-1]
        if key and val:
            out[key] = val
    return out


def load_deploy_overrides(root: Path) -> dict[str, str]:
    secrets = root / load_manifest(root).get("secrets", "secrets")
    deploy = parse_env_file(secrets / "deploy.env")
    for key in DEPLOY_KEYS:
        if key in os.environ and os.environ[key]:
            deploy[key] = os.environ[key]
    return deploy


def global_fmt(root: Path) -> dict[str, str]:
    deploy = load_deploy_overrides(root)
    repo_name = root.name
    compose_slug = slugify(deploy.get("COMPOSE_PROJECT_NAME") or repo_name)
    api_svc = deploy.get("COMPOSE_API_SERVICE") or f"{compose_slug}-api"
    app_svc = deploy.get("COMPOSE_APP_SERVICE") or f"{compose_slug}-app"
    network = (
        deploy.get("DOCKER_NETWORK")
        or deploy.get("GEOSTAT_DOCKER_NETWORK")
        or f"{compose_slug}-net"
    )
    worker_svc = deploy.get("COMPOSE_WORKER_SERVICE") or f"{compose_slug}-worker"
    compose_name = deploy.get("COMPOSE_PROJECT_NAME") or repo_name
    return {
        "compose_project_name": compose_name,
        "api_service": api_svc,
        "api_image": api_svc,
        "app_service": app_svc,
        "app_image": app_svc,
        "worker_service": worker_svc,
        "worker_image": worker_svc,
        "network_key": network.replace(".", "-"),
        "network_name": network,
        "api_storage_vol": f"{api_svc}-storage",
        "api_uploads_vol": f"{api_svc}-uploads",
    }


def load_catalog(root: Path) -> tuple[dict, dict, dict]:
    path = catalog_path(root, load_manifest(root))
    if not path.is_file():
        print(f"ERROR: missing {path}", file=sys.stderr)
        sys.exit(1)
    data = json.loads(path.read_text(encoding="utf-8"))
    templates = data["templates"]
    features = data.get("features", {})
    targets = {root / rel: spec for rel, spec in data["targets"].items()}
    return templates, targets, features


def resolve_services(spec: dict, features: dict) -> list[str]:
    services = list(spec.get("services", []))
    services_if: dict = spec.get("services_if") or {}
    out: list[str] = []
    for key in services:
        flag = services_if.get(key)
        if flag and not features.get(flag, False):
            continue
        out.append(key)
    return out


def render(templates: dict, services: list[str], fmt: dict) -> str:
    return "services:\n" + "".join(templates[key].format(**fmt) for key in services)


def build_target(templates: dict, spec: dict, fmt_global: dict, features: dict) -> str:
    fmt = {**fmt_global, **spec.get("fmt", {})}
    services = resolve_services(spec, features)
    body = render(templates, services, fmt)
    comment = spec.get("comment", "")
    if comment:
        comment = comment.format(**fmt)
    out = HEADER + comment + body
    if spec.get("networks"):
        out += "\n" + templates[spec["networks"]].format(**fmt)
    if spec.get("volumes"):
        out += "\n" + templates[spec["volumes"]].format(**fmt)
    return out + "\n"


def main() -> int:
    root = find_project_root()
    os.environ.setdefault("GEOSTAT_PROJECT_ROOT", str(root))
    fmt_global = global_fmt(root)
    templates, targets, features = load_catalog(root)
    for path, spec in targets.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            build_target(templates, spec, fmt_global, features),
            encoding="utf-8",
            newline="\n",
        )
        print(f"  wrote {path.relative_to(root)}")
    sync = PACKAGE_ROOT / "compose/sync_ops_modules.py"
    if sync.is_file():
        r = subprocess.run([sys.executable, str(sync)], cwd=root, check=False, env=os.environ.copy())
        if r.returncode != 0:
            return r.returncode
    print("OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
