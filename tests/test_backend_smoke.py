"""Backend ops smoke — local config + script contracts (no SSH)."""
from __future__ import annotations

import re
from pathlib import Path

def test_backend_env_deploy_exists_and_structured(secrets_root: Path) -> None:
    p = secrets_root / "backend" / ".env.deploy"
    assert p.is_file(), "ops/config/backend/.env.deploy missing — copy from .env.deploy.example"
    text = p.read_text(encoding="utf-8")
    assert "DEPLOY_LAYOUT=structured" in text
    assert "DEPLOY_PATH=" in text
    m = re.search(r"DEPLOY_PATH=(\S+)", text)
    assert m and "/backend" in m.group(1)


def test_backend_env_deploy_matches_deploy_env(secrets_root: Path) -> None:
    deploy = secrets_root / "deploy.env"
    be = secrets_root / "backend" / ".env.deploy"
    if not deploy.is_file():
        return
    proj = None
    for line in deploy.read_text(encoding="utf-8").splitlines():
        if line.startswith("DEPLOY_PROJECT="):
            proj = line.split("=", 1)[1].strip()
            break
    if proj:
        assert proj in be.read_text(encoding="utf-8")


def test_migrate_script_exists(pkg_root: Path) -> None:
    assert (pkg_root / "toolkit" / "deploy" / "migrate-backend-layout.sh").is_file()


def test_devtools_in_root_gradle(backend_dir: Path) -> None:
    g = (backend_dir / "build.gradle.kts").read_text(encoding="utf-8")
    assert "spring-boot-devtools" in g


def test_simulate_backend_layout_script(pkg_root: Path) -> None:
    assert (pkg_root / "toolkit" / "layout" / "simulate-backend-layout.ps1").is_file()


def test_backend_layout_simulation_doc(repo_root: Path) -> None:
    p = repo_root / "docs" / "BACKEND-LAYOUT-SIMULATION-FULL.md"
    assert p.is_file()
    text = p.read_text(encoding="utf-8")
    assert "runtime/" in text
    assert "workspace/" in text
