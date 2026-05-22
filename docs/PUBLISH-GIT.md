# Publish geostat-kit — standalone package only

ამ გზამკვლევით **მხოლოდ** `geostat-kit` repo ადის GitHub-ზე. Consumer პროექტი (`geostat-chat-bot`) ამ ეტაპზე არ სჭირდება.

## Before push (maintainer checklist)

```powershell
cd path\to\geostat-kit   #=this repo root

$env:PYTHONPATH = (Get-Location).Path
python -m pytest tests -q

.\scripts\dev-modes-verify.ps1 -SkipDocker
```

- [ ] `VERSION` = `1.0.0`
- [ ] `CHANGELOG.md` updated
- [ ] No `deploy.env`, keys, `google-credentials.json` (only `.example` in scaffold)
- [ ] `README.md` + `docs/INSTALL.md` — GitHub URL შეცვლილი `YOUR_USER` → შენი org
- [ ] License chosen (add `LICENSE` file or GitHub license on create)

## 1. GitHub — empty repository

1. https://github.com/new
2. Name: **`geostat-kit`**
3. Public (or private, then grant access)
4. **Do not** add README, .gitignore, license (you already have them locally)

## 2. Commit everything (if pending)

```powershell
cd C:\Users\Test-User\CursorProjects\geostat-chat-bot\kits\geostat-kit

git add -A
git status
git commit -m "release: geostat-kit v1.0.0 — manifest-driven monorepo ops"
```

If first time in this folder only:

```powershell
git init
git add -A
git commit -m "release: geostat-kit v1.0.0 — manifest-driven monorepo ops"
```

## 3. Push to GitHub

Replace `YOUR_USER` with your GitHub username or org.

```powershell
git branch -M main
git remote add origin https://github.com/YOUR_USER/geostat-kit.git
git push -u origin main
```

SSH:

```powershell
git remote add origin git@github.com:YOUR_USER/geostat-kit.git
git push -u origin main
```

If `remote origin` already exists:

```powershell
git remote set-url origin https://github.com/YOUR_USER/geostat-kit.git
git push -u origin main
```

## 4. Release tag (how others pin version)

```powershell
git tag -a v1.0.0 -m "geostat-kit 1.0.0 — first public release"
git push origin v1.0.0
```

On GitHub: **Releases** → **Draft new release** → choose tag `v1.0.0`, paste `CHANGELOG.md` section.

## 5. GitHub repository settings (discovery)

| Field | Suggested text |
|-------|----------------|
| **About** | Manifest-driven ops for SaaS monorepos — compose, SSH deploy, multi-module CLI. v1.0.0 |
| **Website** | link to `docs/INSTALL.md` on GitHub |
| **Topics** | `devops`, `docker-compose`, `monorepo`, `spring-boot`, `vite`, `cli`, `devtools` |

## 6. How others install (share this)

Send them:

```bash
git submodule add https://github.com/YOUR_USER/geostat-kit.git kits/geostat-kit
cd kits/geostat-kit && git checkout v1.0.0
```

Doc link: `https://github.com/YOUR_USER/geostat-kit/blob/main/docs/INSTALL.md`

## 7. What NOT to push

- Consumer `apps/`, `ops/config` with real secrets
- `.pytest_cache/`, `__pycache__/`
- Personal `deploy.env` / SSH private keys

`.gitignore` in this repo already excludes these.

## 8. Later (optional)

- npm / PyPI — **not** required; this package is **git-based** (submodule/copy), like many internal ops kits
- Consumer monorepo submodule — separate step when you want `geostat-chat-bot` to point at this URL
