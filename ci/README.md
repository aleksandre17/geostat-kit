# CI helpers (generic)

| Script | Role |
|--------|------|
| `wait-health.sh` | curl + grep until HTTP healthy |
| `prepare-integration-env.sh` | copy `.env.example` → dev/prod for CI |

Project-specific integration (which compose file, health URLs) stays in **`scripts/ci/`** at repo root.
