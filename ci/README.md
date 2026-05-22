# CI helpers (generic)

| Script | Role |
|--------|------|
| `wait-health.sh` | curl + grep until HTTP healthy |
| `prepare-integration-env.sh` | manifest-driven seed (`lib/ci_prepare.py`) — modules + optional GCP |

Project-specific integration (which compose file, health URLs) stays in **`scripts/ci/`** at repo root.
