# geostat-kit architecture

## Boundaries

```
┌─────────────────────────────────────────────────────────┐
│  kits/geostat-kit  (this package — copy/submodule)   │
│  lib · compose · toolkit · adapters · contracts · ci     │
└───────────────────────────┬─────────────────────────────┘
                            │ geostat.ops.json
┌───────────────────────────▼─────────────────────────────┐
│  Project (geostat-chat-bot, your-app, …)                 │
│  secrets/ · infra/compose/catalog.json · generated yml   │
│  backend/ops.config.* · frontend/ops.config.*          │
│  scripts/ci/* (project integration only)               │
└───────────────────────────┬─────────────────────────────┘
                            │
┌───────────────────────────▼─────────────────────────────┐
│  Applications (Spring, Vite, …)                          │
└─────────────────────────────────────────────────────────┘
```

## What must never be added here

- Real `DEPLOY_SERVER`, API keys, CSP production domains
- `docker-compose*.yml` (generated in project)
- Java/TS business code
- Project-specific health check URLs (stay in `scripts/ci/`)

## Entry points

| Consumer calls | Package path |
|----------------|--------------|
| `geostat compose-gen` | `compose/build.py` |
| `geostat nginx-gen` | `adapters/render_nginx.py` |
| `geostat stack` | `toolkit/stack/compose.ps1` |
| `geostat infra` | `toolkit/infra/ensure-prereqs.sh` |
| `be deploy` | `toolkit/deploy/*.sh` via module `deploy.sh` |

## Manifest

`geostat.ops.json` at project root — see [manifest.schema.json](manifest.schema.json).

## Deploy golden paths

Which CLI to use (Windows vs Linux, static `dist/` vs `compose/dev/`, `deploy watch` vs `dev watch`, deprecated modes):

**[docs/GOLDEN-PATHS.md](docs/GOLDEN-PATHS.md)** — canonical policy for teams using this package.
