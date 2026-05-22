# Package architecture — manifest-driven boundary

`geostat-kit` is a **reusable ops package**. It must not embed:

- Project brand names (`geostat-chat-bot`, …)
- Fixed repo trees (`secrets/`, `packages/`, `frontend/`, `deploy/compose/`)
- Optional artifacts assumed universal (`google-credentials.json`)

Everything resolves through **`geostat.ops.json`** at the **consumer project root**.

## Layers

```text
┌─────────────────────────────────────────┐
│  geostat-kit (this package)             │
│  lib/project_context.py  ← single API   │
│  lib/project.sh / env.sh                │
│  drivers · toolkit · compose engine     │
└──────────────────┬──────────────────────┘
                   │ reads
┌──────────────────▼──────────────────────┐
│  Project root (consumer repo)          │
│  geostat.ops.json                       │
│  ops/config/  apps/*  ops/compose/     │
└─────────────────────────────────────────┘
```

## Manifest contract (required)

| Field | Purpose |
|-------|---------|
| `package` | Path to this kit (`kits/geostat-kit`) |
| `secrets` | Config root (`ops/config`) |
| `compose.catalog` | Compose generator input |
| `stack.composeDir` | Generated full-stack YAML |
| `modules.<id>.path` | App code directory |
| `modules.<id>.secretsModule` | Subdir under `secrets` for env files |

## Optional (features / adapters)

| Field | Purpose |
|-------|---------|
| `features.gcpCredentials` | If `true`, CI may seed `adapters.gcp.credentialsFile` |
| `adapters.gcp.credentialsFile` | Filename under backend secrets module (default `google-credentials.json`) |

Projects without GCP set `features.gcpCredentials: false` (scaffold default).

## Resolution API

**Python** (CI, compose-gen, tests):

```python
from lib.project_context import ProjectContext
ctx = ProjectContext.discover()
ctx.secrets_module_dir("backend")
ctx.module_path("frontend")
ctx.feature_enabled("gcpCredentials")
```

**Bash**:

```bash
source "$PKG/lib/project.sh"
geostat_secrets_dir_for_module backend
geostat_module_path frontend
geostat_stack_compose_dir
```

## CI & init seed

`ci/prepare-integration-env.sh` and `geostat init` (bash fallback) → `lib/ci_prepare.py` — loops `manifest.modules`, seeds `.example` → working copies; GCP file **only** if `features.gcpCredentials`.

## Remote deploy path fallback

When `DEPLOY_PATH` is unset: `{DEPLOY_SERVER_BASE}/{DEPLOY_PROJECT}/{secretsModule}/` via `geostat_default_remote_deploy_base` / `Get-DefaultRemoteDeployPathBase` (uses manifest `modules.*.secretsModule`, not hardcoded `frontend`/`backend` folder names).

## Compose catalog

Service **names** and **paths** come from project `catalog.json` + `deploy.env` (`COMPOSE_*`), not from the package. Package templates use placeholders `{api_service}`, `{secrets_backend}`, etc.

## Tests

Package tests use abstract names (`test-app-api`, `/home/example/...`) — never consumer project brands.
