"""Driver registry, CLI aliases, stack-deploy plan."""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


def _run_api(repo: Path, pkg: Path, *args: str) -> str:
    env = {
        **dict(__import__("os").environ),
        "GEOSTAT_PROJECT_ROOT": str(repo),
        "GEOSTAT_KIT_ROOT": str(pkg),
    }
    cmd = [sys.executable, str(pkg / "lib" / "driver_api.py"), *args]
    r = subprocess.run(cmd, capture_output=True, text=True, env=env, check=True)
    return r.stdout.strip()


class TestJavaBootDriver:
    def test_commands_include_dev(self, registry: dict):
        cmds = set(registry["java-boot"]["commands"].keys())
        assert "deploy" in cmds
        assert "dev" in cmds
        assert "watch" not in cmds

    def test_dev_script_exists(self, pkg_root: Path):
        assert (pkg_root / "drivers" / "java-boot" / "sh" / "dev.sh").is_file()

    def test_dev_remote_toolkit_exists(self, pkg_root: Path):
        assert (pkg_root / "toolkit" / "deploy" / "dev-remote.sh").is_file()


class TestNodeViteDriver:
    def test_commands_include_dev_not_top_level_watch(self, registry: dict):
        cmds = set(registry["node-vite"]["commands"].keys())
        assert "deploy" in cmds
        assert "dev" in cmds
        assert "watch" not in cmds
        assert "manage" in cmds

    def test_deploy_script_exists(self, pkg_root: Path):
        assert (pkg_root / "drivers" / "node-vite" / "ps1" / "deploy.ps1").is_file()

    def test_dev_script_exists(self, pkg_root: Path):
        assert (pkg_root / "drivers" / "node-vite" / "ps1" / "dev.ps1").is_file()


class TestManifest:
    def test_frontend_type(self, manifest: dict):
        assert manifest["modules"]["frontend"]["type"] == "node-vite"

    def test_fe_alias(self, repo_root: Path, pkg_root: Path):
        assert _run_api(repo_root, pkg_root, "alias", "fe") == "frontend"

    def test_stack_deploy_includes_frontend_dist(self, manifest: dict):
        steps = manifest["stackDeploy"]["steps"]
        fe = [s for s in steps if s["module"] == "frontend"]
        assert len(fe) == 1
        assert fe[0]["command"] == "deploy"
        assert "dist" in fe[0]["args"]


class TestDriverPaths:
    def test_deploy_path_resolves(self, repo_root: Path, pkg_root: Path):
        p = _run_api(repo_root, pkg_root, "path", "frontend", "deploy")
        assert p.endswith("deploy.ps1")

    def test_dev_path_resolves(self, repo_root: Path, pkg_root: Path):
        p = _run_api(repo_root, pkg_root, "path", "frontend", "dev")
        assert p.endswith("dev.ps1")

    def test_backend_dev_path_resolves(self, repo_root: Path, pkg_root: Path):
        p = _run_api(repo_root, pkg_root, "path", "backend", "dev")
        assert p.endswith("dev.sh")
