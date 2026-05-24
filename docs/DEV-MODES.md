# დეველოპმენტის რეჟიმები — რომელი ვარიანტი როდის

ეს არის **მთავარი გზამკვლევი**: ლოკალური (Docker-ის გარეშე), ლოკალური Docker, remote სერვერი + Docker.  
Run and Debug (`launch.json`) — იხ. [LOCAL-DEBUG.md](LOCAL-DEBUG.md). Golden paths — [GOLDEN-PATHS.md](GOLDEN-PATHS.md).

---

##  ცხრილი

| რეჟიმი | სად მუშაობს | Docker | VS Code Run and Debug |
|--------|-------------|--------|------------------------|
| **① ლოკალური, host** | შენი Windows/Mac — Node/Java პირდაპირ | **არა** | **კი** — `npm run dev`, `Spring Boot`, `Full stack (local)` |
| **② ლოკალური Docker** | იგივე მანქანა, `localhost` | **კი** | Task / launch: `geostat stack`, `fe/be compose up` |
| **③ Remote + Docker** | Linux სერვერი (SSH) | **კი** (სერვერზე) | **არა** — `geostat fe/be dev watch` |
| **④ Hybrid** | Apps host-ზე, infra remote + tunnel | **კი** (remote) | **კი** — `Hybrid: infra tunnel + API + UI`, `geostat hybrid boot` |

---

## ① ლოკალური — Docker-ის გარეშე (ყველაფერი host-ზე)

ჩვეულებრივი დეველოპმენტი **შენს კომპიუტერზე**, პირდაპირ Node და Java-თი.

### Run and Debug (Cursor / VS Code)

| კონფიგურაცია | რა ხდება |
|---------------|----------|
| **frontend: npm run dev** | Vite — `modules.<ui>.path` (მაგ. `apps/frontend`), პორტი ~5173 |
| **backend: Spring Boot** | Gradle/Java ლოკალურად, breakpoints |
| **Full stack (local)** | UI + API ერთად (compound) |

### ტერმინალი (იგივე რეჟიმი)

```powershell
cd apps/frontend; npm run dev
cd apps/backend; .\gradlew bootRun
```

**Docker არ გჭირდება.** API შეიძლება იყოს ლოკალური ან remote URL — `ops/config/<ui>/env.dev` (`VITE_API_URL`).

---

## ② ლოკალური — Docker-ით (compose შენს მანქანაზე)

კონტეინერები **`localhost`**-ზე; remote SSH არაა.

### Run and Debug / Tasks

| სახელი | რა ხდება |
|--------|----------|
| **geostat: stack (compose dev)** | მთელი stack — `geostat stack up -d --build` |
| Task: **geostat: fe compose up** | მხოლოდ UI კონტეინერი |
| Task: **geostat: be compose up** | მხოლოდ API კონტეინერი |

### ტერმინალი

```powershell
.\tools\geostat.ps1 fe compose up -d --build
.\tools\geostat.ps1 be compose up -d --build
.\tools\geostat.ps1 stack up -d --build
```

**Docker კი, remote არა.**

---

## ③ Remote სერვერი + Docker (Linux / SSH)

კოდი იწერება **ლოკალურად** (Windows), გაშვება **სერვერზე** Docker compose-ით.  
**Run and Debug launch-ში არ არის** — მხოლოდ `geostat` CLI.

### Frontend (Vite კონტეინერში)

| მიზანი | ბრძანება | სერვერზე |
|--------|----------|----------|
| Remote dev | `geostat fe dev bootstrap` → **`geostat fe dev watch`** | `{DEPLOY_PATH}/compose/dev/{container}/` + Docker |
| Prod-like static | `geostat fe deploy dist` → **`geostat fe deploy watch`** | `static/` + nginx |

### Backend (Gradle bootRun კონტეინერში)

| მიზანი | ბრძანება | სერვერზე |
|--------|----------|----------|
| Remote dev | `geostat be dev bootstrap` → **`geostat be dev watch`** | workspace + Docker |
| Prod JAR | `geostat be deploy all` | `runtime/` |

### Full stack prod (remote)

```powershell
.\tools\geostat.ps1 stack-deploy --prod
```

### პირობები

- `ops/config/*/deploy.env` — `DEPLOY_SERVER`, `DEPLOY_LAYOUT=structured`
- SSH: `ops/config/ssh/`

დეტალი: [REMOTE-DEV-DOCKERFILE-FLOW.md](REMOTE-DEV-DOCKERFILE-FLOW.md), [GOLDEN-PATHS.md](GOLDEN-PATHS.md), პროექტი `docs/DEV-REMOTE.md`, `docs/FE-WATCH.md`.

---

## ④ Hybrid — apps ლოკალურად (Windows), infra remote Linux

**Apps** — `gradlew bootRun` / `npm run dev` შენს მანქანაზე; **Postgres / Redis / Qdrant / RabbitMQ** — მხოლოდ Linux სერვერზე Docker-ით; კავშირი **SSH tunnel** → `localhost`.

| ნაბიჯი | ბრძანება |
|--------|----------|
| 1. Infra remote | `geostat infra remote up` |
| 2. Tunnel | `geostat infra tunnel` (ან VS Code compound preLaunch) |
| 3. Apps | `geostat hybrid boot <alias>` ან `geostat <alias> run` |
| 4. F5 compound | Run and Debug → **Hybrid: infra tunnel + API + UI** |

**Env:** `ops/config/<module>/.env.dev` — `INFRA_HOST=127.0.0.1`, peer URLs (`RETRIEVAL_BASE_URL`, …). Spring profile — manifest `modules.*.hybrid.springProfiles`.

**არ აურიო:** legacy `apps/backend/worker` — worker = `ingestion-service`.

სრული არქიტექტურა: consumer [HYBRID-DEV-ARCHITECTURE.md](../../../docs/plan/HYBRID-DEV-ARCHITECTURE.md).

---

## სქემა

```text
                    ┌─────────────────────────────────────┐
                    │  შენი ლეპტოპი (Windows / Mac)        │
                    └─────────────────────────────────────┘
         │                              │
         │ ① ლოკალური, NO Docker         │ ② ლოკალური Docker
         │    Run and Debug:            │    stack / fe|be compose
         │    npm + Java                │    localhost
         │    Full stack (local)        │
         │                              │
         └──────────────┬───────────────┘
                        │ SSH + rsync
                        ▼
                    ┌─────────────────────────────────────┐
                    │  Linux სერვერი                        │
                    │  ③ geostat fe|be dev watch            │
                    │     Docker on server                  │
                    └─────────────────────────────────────┘
```

---

## რას აირჩიო (სწრაფი)

| მინდა… | აირჩიე |
|--------|--------|
| F5, breakpoints, UI+API სწრაფად ლოკალურად | **Full stack (local)** |
| მხოლოდ UI ლოკალურად | **frontend: npm run dev** |
| ყველაფერი Docker-ში ლაპტოპზე | **geostat: stack** ან tasks `fe/be compose up` |
| ვწერ Windows-ზე, ვიღებ Linux+Docker-ზე | **`geostat fe dev watch`** / **`geostat be dev watch`** |
| Prod UI სერვერზე | **`geostat fe deploy watch`** |
| Prod API სერვერზე | **`geostat be deploy all`** |

---

## `deploy watch` vs `dev watch` (remote)

| ბრძანება | რას აკეთებს | path სერვერზე |
|----------|-------------|----------------|
| **`fe deploy watch`** | build → static + nginx | `.../static/{service}/` |
| **`fe dev watch`** | rsync სორსი, Vite კონტეინერში | `.../compose/dev/{service}/` |
| **`be dev watch`** | rsync + Gradle bootRun კონტეინერში | workspace |

**წესი:** `deploy` = artifact; `dev` = სორსი + compose dev.

---

## ტესტირება (ყველა რეჟიმი — smoke)

ავტომატური შემოწმება (არ იწყებს ხანგრძლივ სერვისებს mode ①-ში):

```powershell
.\kits\geostat-kit\scripts\dev-modes-verify.ps1
```

```bash
bash kits/geostat-kit/scripts/dev-modes-verify.sh
# სრული Docker integration (თუ daemon ჩართულია):
bash kits/geostat-kit/scripts/dev-modes-verify.sh
# მხოლოდ პაკეტი + config, Docker-ის გარეშე:
bash kits/geostat-kit/scripts/dev-modes-verify.sh --skip-docker --skip-integration
```

რას ამოწმებს:

| რეჟიმი | ავტომატური | ხელით (E2E) |
|--------|------------|-------------|
| ① host | paths, gradlew, npm, launch.json | `npm run dev`, Java F5 |
| ② Docker | `fe/be check`, docker daemon | `stack up`, compose |
| ③ remote | `DEPLOY_LAYOUT`, module-ops-smoke | SSH + `fe/be dev watch` |

პაკეტის pytest: `tests/test_dev_modes_smoke.py`.

---

## დაკავშირებული

- [LOCAL-DEBUG.md](LOCAL-DEBUG.md) — `.vscode` გენერაცია
- [GOLDEN-PATHS.md](GOLDEN-PATHS.md) / [GOLDEN-PATHS-BACKEND.md](GOLDEN-PATHS-BACKEND.md)
- [REMOTE-DEV-DOCKERFILE-FLOW.md](REMOTE-DEV-DOCKERFILE-FLOW.md)
- Consumer: [../../docs/DEV-REMOTE.md](../../docs/DEV-REMOTE.md), [../../docs/FE-WATCH.md](../../docs/FE-WATCH.md)
