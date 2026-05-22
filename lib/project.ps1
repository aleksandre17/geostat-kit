# Project manifest (geostat.ops.json) — package boundary resolution

function Get-ProjectManifestPath {
    if ($env:GEOSTAT_PROJECT_ROOT) {
        $mf = Join-Path $env:GEOSTAT_PROJECT_ROOT "geostat.ops.json"
        if (Test-Path $mf) { return $mf }
    }
    $dir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    while ($dir) {
        $mf = Join-Path $dir "geostat.ops.json"
        if (Test-Path $mf) { return $mf }
        $parent = Split-Path $dir -Parent
        if ($parent -eq $dir) { break }
        $dir = $parent
    }
    return $null
}

function Get-ProjectRootFromManifest {
    if ($env:GEOSTAT_PROJECT_ROOT) { return $env:GEOSTAT_PROJECT_ROOT }
    $mf = Get-ProjectManifestPath
    if ($mf) { return Split-Path $mf -Parent }
    $dir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
    while ($dir) {
        if (Test-Path (Join-Path $dir "secrets")) { return $dir }
        $parent = Split-Path $dir -Parent
        if ($parent -eq $dir) { break }
        $dir = $parent
    }
    return $null
}

function Get-ManifestField {
    param([string]$Field, [string]$Default = "")
    $mf = Get-ProjectManifestPath
    if (-not $mf -or -not (Test-Path $mf)) { return $Default }
    $m = Get-Content $mf -Raw | ConvertFrom-Json
    $v = $m
    foreach ($p in ($Field -split '\.')) {
        if ($null -eq $v) { return $Default }
        $prop = $v.PSObject.Properties[$p]
        if (-not $prop) { return $Default }
        $v = $prop.Value
    }
    if ($null -eq $v) { return $Default }
    return [string]$v
}

function Get-OpsPackageRoot {
    if ($env:OPS_PACKAGE_ROOT) { return $env:OPS_PACKAGE_ROOT }
    $proj = Get-ProjectRootFromManifest
    $rel = Get-ManifestField "package" "kits/geostat-kit"
    return (Resolve-Path (Join-Path $proj $rel)).Path
}

function Get-OpsToolkitPowerShellRoot {
    Join-Path (Get-OpsPackageRoot) "toolkit\powershell"
}
