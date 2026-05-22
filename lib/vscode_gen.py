#!/usr/bin/env python3
"""Generate .vscode/launch.json and tasks.json from geostat.ops.json (manifest-driven)."""
from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any

from lib.manifest_defaults import default_field, read_nested
from lib.modules import infer_cli_aliases, modules_by_role
from lib.project_context import ProjectContext


def _posix_rel(root: Path, path: Path) -> str:
    return path.resolve().relative_to(root.resolve()).as_posix()


def _gradle_project_name(module_dir: Path) -> str | None:
    for name in ("settings.gradle.kts", "settings.gradle"):
        f = module_dir / name
        if not f.is_file():
            continue
        text = f.read_text(encoding="utf-8", errors="replace")
        m = re.search(r'rootProject\.name\s*=\s*["\']([^"\']+)["\']', text)
        if m:
            return m.group(1)
    return None


def _detect_spring_main_class(module_dir: Path) -> str | None:
    java_root = module_dir / "src" / "main" / "java"
    if not java_root.is_dir():
        return None
    candidates: list[Path] = []
    for p in java_root.rglob("*Application.java"):
        if p.is_file():
            candidates.append(p)
    if not candidates:
        return None
    # Prefer shortest path / typical Spring Boot entry
    pick = sorted(candidates, key=lambda x: (len(x.parts), x.name))[0]
    rel = pick.relative_to(java_root)
    return ".".join(rel.with_suffix("").parts)


def _module_debug_cfg(manifest: dict[str, Any], module_id: str) -> dict[str, Any]:
    cfg = (manifest.get("modules") or {}).get(module_id) or {}
    if not isinstance(cfg, dict):
        return {}
    dbg = cfg.get("debug")
    return dbg if isinstance(dbg, dict) else {}


def _launch_node_vite(
    ctx: ProjectContext, module_id: str, aliases: dict[str, str]
) -> dict[str, Any]:
    rel = _posix_rel(ctx.root, ctx.module_path(module_id))
    dbg = _module_debug_cfg(ctx.manifest, module_id)
    script = str(dbg.get("npmScript") or dbg.get("script") or "dev")
    label = str(dbg.get("label") or f"{module_id}: npm run {script}")
    return {
        "name": label,
        "type": "node-terminal",
        "request": "launch",
        "command": f"npm run {script}",
        "cwd": "${workspaceFolder}/" + rel,
    }


def _launch_java(
    ctx: ProjectContext, module_id: str, aliases: dict[str, str]
) -> dict[str, Any] | None:
    mod_dir = ctx.module_path(module_id)
    dbg = _module_debug_cfg(ctx.manifest, module_id)
    java_dbg = dbg.get("java") if isinstance(dbg.get("java"), dict) else dbg
    main = None
    project = None
    if isinstance(java_dbg, dict):
        main = java_dbg.get("mainClass")
        project = java_dbg.get("projectName")
    if not main:
        main = dbg.get("mainClass")
    if not project:
        project = dbg.get("projectName")
    if not main:
        main = _detect_spring_main_class(mod_dir)
    if not project:
        project = _gradle_project_name(mod_dir)
    if not main:
        return None
    rel = _posix_rel(ctx.root, mod_dir)
    label = str(dbg.get("label") or f"{module_id}: Spring Boot")
    cfg: dict[str, Any] = {
        "name": label,
        "type": "java",
        "request": "launch",
        "mainClass": main,
        "cwd": "${workspaceFolder}/" + rel,
    }
    if project:
        cfg["projectName"] = project
    env_file = dbg.get("envFile")
    if env_file:
        cfg["envFile"] = "${workspaceFolder}/" + str(env_file).replace("\\", "/")
    return cfg


def _geostat_script_rel(ctx: ProjectContext) -> str:
    custom = read_nested(ctx.manifest, "vscode.geostatScript", "")
    if custom:
        return custom.replace("\\", "/")
    return default_field("vscode.geostatScript") or "tools/geostat.ps1"


def build_launch_json(ctx: ProjectContext) -> dict[str, Any]:
    aliases = infer_cli_aliases(ctx.manifest)
    configs: list[dict[str, Any]] = []
    compounds_members: list[str] = []

    for mid in ctx.list_module_ids():
        typ = read_nested(ctx.manifest, f"modules.{mid}.type", "")
        if typ == "node-vite":
            cfg = _launch_node_vite(ctx, mid, aliases)
            configs.append(cfg)
            if read_nested(ctx.manifest, f"modules.{mid}.role", "") == "ui":
                compounds_members.append(cfg["name"])
        elif typ == "java-boot":
            cfg = _launch_java(ctx, mid, aliases)
            if cfg:
                configs.append(cfg)
                role = read_nested(ctx.manifest, f"modules.{mid}.role", "")
                if role in ("api", "worker"):
                    compounds_members.append(cfg["name"])

    gs = _geostat_script_rel(ctx)
    configs.extend(
        [
            {
                "name": "geostat: stack (compose dev)",
                "type": "node-terminal",
                "request": "launch",
                "command": f'powershell -ExecutionPolicy Bypass -File "${{workspaceFolder}}/{gs}" stack up -d --build',
                "cwd": "${workspaceFolder}",
            },
        ]
    )
    for alias, target in sorted(aliases.items()):
        if alias in ("fe", "be", "ui", "api", "worker") or len(alias) <= 3:
            configs.append(
                {
                    "name": f"geostat: {alias} check",
                    "type": "node-terminal",
                    "request": "launch",
                    "command": f'powershell -ExecutionPolicy Bypass -File "${{workspaceFolder}}/{gs}" {alias} check',
                    "cwd": "${workspaceFolder}",
                }
            )

    out: dict[str, Any] = {"version": "0.2.0", "configurations": configs}
    if len(compounds_members) >= 2:
        ui_names = [
            c["name"]
            for c in configs
            if c.get("type") == "node-terminal" and "npm run" in c.get("command", "")
        ]
        api_names = [
            c["name"]
            for c in configs
            if c.get("type") == "java"
        ]
        pick = (api_names[:1] + ui_names[:1]) or compounds_members[:2]
        out["compounds"] = [
            {
                "name": "Full stack (local)",
                "configurations": pick,
                "stopAll": True,
            }
        ]
    return out


def build_tasks_json(ctx: ProjectContext) -> dict[str, Any]:
    gs = _geostat_script_rel(ctx)
    wf = "${workspaceFolder}"
    ps = "powershell"
    aliases = infer_cli_aliases(ctx.manifest)

    def _task(label: str, args: list[str]) -> dict[str, Any]:
        return {
            "label": label,
            "type": "shell",
            "command": ps,
            "args": ["-ExecutionPolicy", "Bypass", "-File", f"{wf}/{gs}", *args],
            "options": {"cwd": wf},
            "problemMatcher": [],
        }

    tasks: list[dict[str, Any]] = [
        _task("geostat: stack dev", ["stack", "up", "-d", "--build"]),
        _task("geostat: stack prod", ["stack", "-Prod", "up", "-d", "--build"]),
        _task("geostat: stack down", ["stack", "down"]),
        _task("geostat: compose-gen", ["compose-gen"]),
        _task("geostat: validate", ["validate"]),
    ]
    for alias in sorted(set(aliases.values()), key=lambda x: aliases.get(x, x)):
        short = next((k for k, v in aliases.items() if v == alias), alias)
        tasks.append(_task(f"geostat: {short} check", [short, "check"]))
        tasks.append(
            _task(
                f"geostat: {short} compose up",
                [short, "compose", "up", "-d", "--build"],
            )
        )

    return {"version": "2.0.0", "tasks": tasks}


def write_vscode(ctx: ProjectContext, *, force: bool = False) -> list[str]:
    folder = read_nested(ctx.manifest, "vscode.folder", "") or default_field("vscode.folder") or ".vscode"
    out_dir = ctx.root / folder.replace("\\", "/")
    out_dir.mkdir(parents=True, exist_ok=True)
    written: list[str] = []
    for name, builder in (("launch.json", build_launch_json), ("tasks.json", build_tasks_json)):
        path = out_dir / name
        if path.is_file() and not force:
            continue
        data = builder(ctx)
        path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
        written.append(_posix_rel(ctx.root, path))
    return written


def main() -> int:
    import sys

    force = "--force" in sys.argv
    ctx = ProjectContext.discover()
    paths = write_vscode(ctx, force=force)
    if not paths:
        print("[vscode-gen] .vscode files exist (use --force to overwrite)")
        return 0
    for p in paths:
        print(f"[vscode-gen] wrote {p}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
