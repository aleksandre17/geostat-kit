"""Backend structured deploy paths (runtime / workspace)."""
from __future__ import annotations

import pytest

from lib.deploy_paths import (
    backend_deploy_path_candidates,
    resolve_backend_deploy_path,
)

BASE = "/home/administrator/geostat/backend"
API = "geostat-chat-bot-api"
WORKER = "geostat-chat-bot-worker"


class TestBackendStructuredLayout:
    def test_runtime(self):
        assert (
            resolve_backend_deploy_path(
                base=BASE, container_name=API, kind="runtime", layout="structured"
            )
            == f"{BASE}/runtime/{API}"
        )

    def test_workspace(self):
        assert (
            resolve_backend_deploy_path(
                base=BASE, container_name=API, kind="workspace", layout="structured"
            )
            == f"{BASE}/workspace/{API}"
        )

    def test_runtime_and_workspace_differ(self):
        rt = resolve_backend_deploy_path(
            base=BASE, container_name=API, kind="runtime", layout="structured"
        )
        ws = resolve_backend_deploy_path(
            base=BASE, container_name=API, kind="workspace", layout="structured"
        )
        assert rt != ws

    def test_flat_layout(self):
        assert (
            resolve_backend_deploy_path(
                base=BASE, container_name=API, kind="runtime", layout="flat"
            )
            == f"{BASE}/{API}"
        )


class TestBackendCandidates:
    def test_three_candidates(self):
        c = backend_deploy_path_candidates(base=BASE, container_name=API)
        assert len(c) == 3
        assert f"{BASE}/runtime/{API}" in c
        assert f"{BASE}/workspace/{API}" in c
        assert f"{BASE}/{API}" in c


@pytest.mark.parametrize("container", [API, WORKER])
def test_multi_module_paths(container: str):
    p = resolve_backend_deploy_path(
        base=BASE, container_name=container, kind="runtime", layout="structured"
    )
    assert p.endswith(container)
    assert "/runtime/" in p
