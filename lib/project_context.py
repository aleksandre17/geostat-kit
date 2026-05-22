"""Manifest-driven project paths — package boundary (no app brands or fixed tree)."""
from __future__ import annotations

import json
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any

DEFAULTS = {
    "package": "kits/geostat-kit",
    "secrets": "ops/config",
    "compose.catalog": "ops/compose/catalog.json",
    "compose.syncModules": "apps/backend/ops.modules",
    "stack.composeDir": "ops/compose/stack",
}


def _read_nested(data: dict[str, Any], dotted: str, default: str = "") -> str:
    cur: Any = data
    for key in dotted.split("."):
        if not isinstance(cur, dict) or key not in cur:
            return default
        cur = cur[key]
    return str(cur) if cur is not None else default


def find_project_root(start: Path | None = None) -> Path:
    if os.environ.get("GEOSTAT_PROJECT_ROOT"):
        return Path(os.environ["GEOSTAT_PROJECT_ROOT"]).resolve()
    start = (start or Path.cwd()).resolve()
    for p in [start, *start.parents]:
        if (p / "geostat.ops.json").is_file():
            return p
        if (p / "ops" / "config").is_dir() or (p / "secrets").is_dir():
            if (p / "kits" / "geostat-kit").is_dir() or (p / "packages" / "geostat-kit").is_dir():
                return p
    raise FileNotFoundError("project root not found (geostat.ops.json or ops/config/)")


def load_manifest(root: Path) -> dict[str, Any]:
    mf = root / "geostat.ops.json"
    if mf.is_file():
        return json.loads(mf.read_text(encoding="utf-8"))
    return {}


@dataclass(frozen=True)
class ProjectContext:
    root: Path
    manifest: dict[str, Any]

    @classmethod
    def discover(cls, start: Path | None = None) -> ProjectContext:
        root = find_project_root(start)
        return cls(root=root, manifest=load_manifest(root))

    def field(self, dotted: str, default: str | None = None) -> str:
        d = default if default is not None else DEFAULTS.get(dotted, "")
        return _read_nested(self.manifest, dotted, d)

    @property
    def secrets_root(self) -> Path:
        return self.root / self.field("secrets")

    @property
    def package_root(self) -> Path:
        return (self.root / self.field("package")).resolve()

    def module_path(self, module_id: str) -> Path:
        rel = _read_nested(self.manifest, f"modules.{module_id}.path", "")
        if not rel:
            raise KeyError(f"manifest modules.{module_id}.path missing")
        return self.root / rel

    def secrets_module_dir(self, module_id: str) -> Path:
        sm = _read_nested(self.manifest, f"modules.{module_id}.secretsModule", module_id)
        return self.secrets_root / sm

    def secrets_module_dirs(self) -> dict[str, Path]:
        mods = self.manifest.get("modules") or {}
        out: dict[str, Path] = {}
        for mid, cfg in mods.items():
            if isinstance(cfg, dict):
                sm = str(cfg.get("secretsModule", mid))
                out[mid] = self.secrets_root / sm
        return out

    @property
    def stack_compose_dir(self) -> Path:
        return self.root / self.field("stack.composeDir")

    @property
    def catalog_path(self) -> Path:
        return self.root / self.field("compose.catalog")

    def feature_enabled(self, name: str) -> bool:
        feats = self.manifest.get("features") or {}
        val = feats.get(name)
        if isinstance(val, bool):
            return val
        return False

    def gcp_credentials_filename(self) -> str | None:
        """Optional backend secret file; only when feature + adapter configured."""
        if not self.feature_enabled("gcpCredentials"):
            return None
        gcp = (self.manifest.get("adapters") or {}).get("gcp") or {}
        if isinstance(gcp, dict) and gcp.get("enabled") is False:
            return None
        fn = "google-credentials.json"
        if isinstance(gcp, dict) and gcp.get("credentialsFile"):
            fn = str(gcp["credentialsFile"])
        return fn

    def secrets_module_folder(self, module_id: str) -> str:
        """Subdir under secrets root (manifest modules.<id>.secretsModule)."""
        cfg = (self.manifest.get("modules") or {}).get(module_id)
        if isinstance(cfg, dict) and cfg.get("secretsModule"):
            return str(cfg["secretsModule"])
        return module_id

    def default_remote_deploy_base(
        self, secrets_folder: str, *, server_base: str = "", project_slug: str = ""
    ) -> str:
        """Fallback DEPLOY_PATH when unset: {server_base}/{slug}/{secrets_folder}."""
        slug = project_slug or self.root.name
        deploy = self.secrets_root / "deploy.env"
        if deploy.is_file():
            for line in deploy.read_text(encoding="utf-8").splitlines():
                line = line.strip()
                if line.startswith("#") or "=" not in line:
                    continue
                k, _, v = line.partition("=")
                if k.strip() == "DEPLOY_PROJECT" and v.strip():
                    slug = v.strip().strip("\"'").lower().replace("_", "-")
                    break
        base = server_base or "/home/deploy"
        return f"{base.rstrip('/')}/{slug}/{secrets_folder}"

    def list_secrets_module_folders(self) -> list[str]:
        seen: set[str] = set()
        out: list[str] = []
        for mid in (self.manifest.get("modules") or {}):
            folder = self.secrets_module_folder(str(mid))
            if folder not in seen:
                seen.add(folder)
                out.append(folder)
        return out

    def compose_service_names(self) -> dict[str, str]:
        """Logical roles → container/service names from deploy.env contract (not brands)."""
        deploy = self.secrets_root / "deploy.env"
        env: dict[str, str] = {}
        if deploy.is_file():
            for line in deploy.read_text(encoding="utf-8").splitlines():
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, _, v = line.partition("=")
                env[k.strip()] = v.strip().strip("\"'")
        slug = env.get("COMPOSE_PROJECT_NAME") or env.get("DEPLOY_PROJECT") or self.root.name
        slug = slug.lower().replace("_", "-")
        return {
            "api": env.get("COMPOSE_API_SERVICE") or f"{slug}-api",
            "app": env.get("COMPOSE_APP_SERVICE") or f"{slug}-app",
            "worker": env.get("COMPOSE_WORKER_SERVICE") or f"{slug}-worker",
        }
