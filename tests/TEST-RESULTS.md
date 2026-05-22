# geostat-kit package tests — last run

| Field | Value |
|-------|--------|
| Date | 2026-05-21 |
| Host | Windows (`win32`) |
| Python | 3.13.3 |
| pytest | 9.0.3 |
| **Result** | **69 passed, 0 failed** |
| Duration | ~0.5s |
| Fixes this run | `node-vite` check/compose `_init` path; `Deploy-Path.ps1` em-dash in `.Add()` |

## Command

```powershell
cd kits\geostat-kit
$env:PYTHONPATH = (Get-Location).Path
python -m pytest tests -v --tb=short
```

```bash
bash kits/geostat-kit/tests/run-kit-tests.sh
```

## Summary by suite

| Module | Tests | Status |
|--------|-------|--------|
| `test_deploy_paths.py` | 10 | PASSED |
| `test_driver_api.py` | 8 | PASSED |
| `test_frontend_contracts.py` | 11 | PASSED |
| `test_golden_path_matrix.py` | 11 | PASSED |
| `test_registry_integrity.py` | 1 | PASSED |
| **Total** | **41** | **PASSED** |

## Golden-path scenarios verified (path logic)

| ID | Kind on server |
|----|----------------|
| B1 / B2 / B3 (`deploy dist`, `sync`, `deploy watch`) | `.../static/geostat-chat-bot-app/` |
| C1 (`deploy remote` dev) | `.../compose/dev/geostat-chat-bot-app/` |
| C2 (`deploy remote` prod) | `.../compose/prod/geostat-chat-bot-app/` |
| D1 / D2 / D3 (`dev bootstrap`, `watch`, `sync`) | `.../compose/dev/geostat-chat-bot-app/` |

Base used in tests: `/home/administrator/geostat/frontend` (structured layout).

## Contracts verified

- Registry: `node-vite` has `deploy`, `dev` — **no** top-level `watch`
- `geostat.ps1`: `fe watch` redirects to `deploy watch`
- `deploy.ps1`: mode `watch` + `Static-Deploy-Watch.ps1`
- `dev.ps1`: `bootstrap`, `sync`, `watch`, `restart` + `Dev-Remote.ps1`
- Dockerfile: production `EXPOSE 80` (not 5177)
- `docker-compose.prod.yml`: host port maps to container **80**

## Full verbose log

See [LAST-RUN.txt](./LAST-RUN.txt) (pytest `-v` output).

## Not run in this suite

SSH, rsync, Docker, live `fe dev bootstrap` on server.
