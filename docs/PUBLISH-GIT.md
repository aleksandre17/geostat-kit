# geostat-kit — Git-ზე ატვირთვა (standalone repo)

პაკეტი ცალკე repository-ად იწერება; პროექტები იღებენ **`kits/geostat-kit`** submodule-ით ან copy-ით.

## 1. ლოკალური repo (უკვე გაკეთებული ერთხელ)

```powershell
cd C:\Users\Test-User\CursorProjects\geostat-chat-bot\kits\geostat-kit
git init
git add .
git commit -m "chore: geostat-kit v1.0.0 — ops package (v2 layout scaffold)"
```

## 2. GitHub / GitLab — ცარიელი remote

1. შექმენი **ცარიელი** repo (სახელი მაგ. `geostat-kit`), README/license არ დაამატო.
2. დააკავშირე remote:

```powershell
cd kits\geostat-kit
git branch -M main
git remote add origin https://github.com/YOUR_USER/geostat-kit.git
git push -u origin main
```

SSH:

```powershell
git remote add origin git@github.com:YOUR_USER/geostat-kit.git
git push -u origin main
```

## 3. სხვა პროექტში გამოყენება

```bash
git submodule add https://github.com/YOUR_USER/geostat-kit.git kits/geostat-kit
```

`geostat.ops.json`:

```json
"package": "kits/geostat-kit"
```

## 4. ვერსია / tag

```powershell
git tag -a v1.0.0 -m "geostat-kit 1.0.0"
git push origin v1.0.0
```

`VERSION` ფაილი repo root-ში უნდა ემთხვეოდეს tag-ს.

## 5. რა **არ** უნდა ჩავიდეს პაკეტის repo-ში

- production `deploy.env`, API keys, SSH private keys
- პროექტის `apps/`, `ops/config` (მხოლოდ `scaffold/` examples)

## 6. geostat-chat-bot-ში submodule (ოფციული)

როცა `geostat-chat-bot`-ც git repo გახდება:

```bash
cd geostat-chat-bot
git submodule add <geostat-kit-url> kits/geostat-kit
```

ამ repo-ში პაკეტი ახლა ჩვეულებრივი ფოლდერია; submodule-ზე გადასვლა ცალკე commit-ს მოითხოვს.
