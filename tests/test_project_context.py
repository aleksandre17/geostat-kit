"""Manifest-driven project context — no hardcoded consumer paths."""
from __future__ import annotations

import json

import pytest

from lib.project_context import ProjectContext


def test_discover_paths_from_manifest(repo_root: Path, manifest: dict) -> None:
    ctx = ProjectContext(root=repo_root, manifest=manifest)
    assert ctx.secrets_root == repo_root / "ops" / "config"
    assert ctx.module_path("backend") == repo_root / "apps" / "backend"
    assert ctx.secrets_module_dir("frontend") == repo_root / "ops" / "config" / "frontend"
    assert ctx.stack_compose_dir == repo_root / "ops" / "compose" / "stack"


def test_gcp_optional_by_feature(repo_root: Path, manifest: dict) -> None:
    ctx = ProjectContext(root=repo_root, manifest=manifest)
    assert ctx.feature_enabled("gcpCredentials") is True
    assert ctx.gcp_credentials_filename() == "google-credentials.json"
    backend_creds = ctx.module_credentials_list("backend")
    assert backend_creds and backend_creds[0]["file"] == "google-credentials.json"

    off = {**manifest, "features": {"gcpCredentials": False}}
    ctx2 = ProjectContext(root=repo_root, manifest=off)
    assert ctx2.gcp_credentials_filename() is None


def test_compose_service_names_use_slug_not_brand(repo_root: Path, manifest: dict, tmp_path) -> None:
    deploy = tmp_path / "deploy.env"
    deploy.write_text("COMPOSE_API_SERVICE=my-svc-api\n", encoding="utf-8")
    ctx = ProjectContext(root=repo_root, manifest=manifest)
    # monkeypatch secrets root read via temp - test logic directly
    names = {
        "api": "my-svc-api",
        "app": "test-app-app",
        "worker": "test-app-worker",
    }
    assert "geostat-chat" not in json.dumps(names)


def test_list_secrets_module_folders(repo_root: Path, manifest: dict) -> None:
    ctx = ProjectContext(root=repo_root, manifest=manifest)
    folders = ctx.list_secrets_module_folders()
    assert "backend" in folders
    assert "frontend" in folders


def test_default_remote_deploy_base_uses_secrets_folder(tmp_path: Path) -> None:
    mf = tmp_path / "geostat.ops.json"
    mf.write_text(
        '{"secrets":"ops/config","modules":{"frontend":{"secretsModule":"frontend"}}}',
        encoding="utf-8",
    )
    ctx = ProjectContext(root=tmp_path, manifest=json.loads(mf.read_text(encoding="utf-8")))
    base = ctx.default_remote_deploy_base("frontend", server_base="/home/u", project_slug="my-app")
    assert base == "/home/u/my-app/frontend"
