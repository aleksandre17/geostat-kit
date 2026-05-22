# geostat-kit

Reusable **operations package** for monorepos: env contract, compose generation, SSH deploy, manage CLI.

No application code. No production secrets. No generated compose files.

## სად ჯდება პროექტში

**v2 layout:** `kits/geostat-kit/` (არა `packages/`).

```bash
git submodule add <repo-url> kits/geostat-kit
```

`geostat.ops.json`: `"package": "kits/geostat-kit"`.

სრული ინსტრუქცია (ამ monorepo-ში): [../../docs/KITS-PACKAGE.md](../../docs/KITS-PACKAGE.md)  
**Git-ზე ატვირთვა (standalone repo):** [docs/PUBLISH-GIT.md](docs/PUBLISH-GIT.md)  
**Package architecture:** [docs/PACKAGE-ARCHITECTURE.md](docs/PACKAGE-ARCHITECTURE.md)

## სახელმძღვანოები

| Doc | Topic |
|-----|--------|
| [../../docs/GEOSTAT-KIT-SETUP.md](../../docs/GEOSTAT-KIT-SETUP.md) | პალეტი + პროექტი ერთად |
| [../../docs/GEOSTAT-INIT.md](../../docs/GEOSTAT-INIT.md) | `geostat init` |
| [docs/ADOPTION-LINE.md](docs/ADOPTION-LINE.md) | ახალი repo — ნაბიჯ-ნაბიჯ |
| [docs/GOLDEN-PATHS.md](docs/GOLDEN-PATHS.md) | frontend golden paths |
| [docs/GOLDEN-PATHS-BACKEND.md](docs/GOLDEN-PATHS-BACKEND.md) | backend golden paths |

## Layout (პაკეტის შიგნით)

```text
kits/geostat-kit/
├── lib/                 # env, manifest, driver_api.py
├── compose/             # catalog → docker-compose engine
├── adapters/            # nginx CSP render
├── drivers/             # java-boot | node-vite | …
├── toolkit/             # deploy, stack, init, …
├── cli/                 # geostat router
├── scaffold/            # project tree templates (v2: apps/, ops/)
├── ci/
└── docs/
```

## Quick start (ახალი პროექტი)

1. ჩააყენე პაკეტი → `kits/geostat-kit/` ([KITS-PACKAGE.md](../../docs/KITS-PACKAGE.md))
2. `.\tools\geostat.ps1 init`
3. [ADOPTION-LINE.md](docs/ADOPTION-LINE.md) §4–§11

## Tests

```powershell
cd kits\geostat-kit
$env:PYTHONPATH = (Get-Location).Path
py -3 -m pytest tests -q
```

ან: `bash kits/geostat-kit/tests/run-kit-tests.sh`

## Version

[VERSION](VERSION)
