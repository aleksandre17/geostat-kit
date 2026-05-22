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
    if ($env:GEOSTAT_LEGACY_ROOT_DISCOVERY -match '^(1|true|yes|on)$') {
        $dir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
        while ($dir) {
            if ((Test-Path (Join-Path $dir "ops\config")) -or (Test-Path (Join-Path $dir "secrets"))) { return $dir }
            $parent = Split-Path $dir -Parent
            if ($parent -eq $dir) { break }
            $dir = $parent
        }
    }
    return $null
}

function Get-ScaffoldManifestPath {
    if ($env:GEOSTAT_KIT_ROOT) {
        return Join-Path $env:GEOSTAT_KIT_ROOT "scaffold\geostat.ops.json"
    }
    Join-Path (Get-OpsPackageRoot) "scaffold\geostat.ops.json"
}

function Get-ScaffoldManifestField {
    param([string]$Field)
    $path = Get-ScaffoldManifestPath
    if (-not (Test-Path $path)) { return "" }
    $m = Get-Content $path -Raw | ConvertFrom-Json
    $v = $m
    foreach ($p in ($Field -split '\.')) {
        if ($null -eq $v) { return "" }
        $prop = $v.PSObject.Properties[$p]
        if (-not $prop) { return "" }
        $v = $prop.Value
    }
    if ($null -eq $v) { return "" }
    return [string]$v
}

function Get-ManifestField {
    param([string]$Field, [string]$Default = $null)
    if ($null -eq $Default) { $Default = Get-ScaffoldManifestField $Field }
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
    $rel = Get-ManifestField "package"
    return (Resolve-Path (Join-Path $proj $rel)).Path
}

function Get-OpsToolkitPowerShellRoot {
    Join-Path (Get-OpsPackageRoot) "toolkit\powershell"
}

function Get-ManifestModulePath {
    param([Parameter(Mandatory = $true)][string]$ModuleId)
    $proj = Get-ProjectRootFromManifest
    if (-not $proj) { throw "geostat.ops.json not found" }
    $rel = Get-ManifestField "modules.$ModuleId.path"
    if (-not $rel) { throw "manifest modules.$ModuleId.path missing" }
    Join-Path $proj ($rel -replace '/', '\')
}

function Get-ModuleSecretsFolder {
    param([Parameter(Mandatory = $true)][string]$ModuleId)
    $sm = Get-ManifestField "modules.$ModuleId.secretsModule"
    if (-not $sm) { $sm = $ModuleId }
    return $sm
}

function Get-ModuleIdByDriverType {
    param([Parameter(Mandatory = $true)][string]$DriverType)
    $mf = Get-ProjectManifestPath
    if (-not $mf) { return $null }
    $data = Get-Content $mf -Raw | ConvertFrom-Json
    foreach ($p in $data.modules.PSObject.Properties) {
        if ($p.Value.type -eq $DriverType) { return [string]$p.Name }
    }
    return $null
}

function Get-SecretsConfigRel {
    (Get-ManifestField "secrets") -replace '\\', '/'
}

function Get-ModuleEnvPathLabels {
    param(
        [Parameter(Mandatory = $true)][string]$ModuleId,
        [Parameter(Mandatory = $true)][string[]]$FileNames
    )
    $base = "$(Get-SecretsConfigRel)/$(Get-ModuleSecretsFolder $ModuleId)"
    foreach ($name in $FileNames) { "$base/$name" }
}

function Get-DeployEnvPathLabel {
    "$(Get-SecretsConfigRel)/deploy.env"
}

function Get-ListedSecretsModuleFolders {
    $mf = Get-ProjectManifestPath
    if (-not $mf) {
        $sc = Get-ScaffoldManifestPath
        if (-not (Test-Path $sc)) { return @() }
        $data = Get-Content $sc -Raw | ConvertFrom-Json
        $seen = @{}
        $out = [System.Collections.ArrayList]@()
        foreach ($p in $data.modules.PSObject.Properties) {
            $folder = if ($p.Value.secretsModule) { [string]$p.Value.secretsModule } else { [string]$p.Name }
            if (-not $seen[$folder]) { $seen[$folder] = $true; [void]$out.Add($folder) }
        }
        return $out.ToArray()
    }
    $data = Get-Content $mf -Raw | ConvertFrom-Json
    $seen = @{}
    $out = [System.Collections.ArrayList]@()
    foreach ($p in $data.modules.PSObject.Properties) {
        $folder = if ($p.Value.secretsModule) { [string]$p.Value.secretsModule } else { [string]$p.Name }
        if (-not $seen[$folder]) {
            $seen[$folder] = $true
            [void]$out.Add($folder)
        }
    }
    return $out.ToArray()
}

function Get-StackComposeDirFromManifest {
    $proj = Get-ProjectRootFromManifest
    if (-not $proj) { throw "geostat.ops.json not found" }
    $rel = Get-ManifestField "stack.composeDir"
    Join-Path $proj ($rel -replace '/', '\')
}

function Get-ComposeAppServiceName {
    $app = Get-DeployEnvValue "COMPOSE_APP_SERVICE"
    if ($app) { return $app }
    "$(Get-ComposeSlug)-app"
}

function Get-DefaultRemoteDeployPathBase {
    param([Parameter(Mandatory = $true)][string]$SecretsFolder)
    $base = Get-SecretsEnvValue -Module $SecretsFolder -Key "DEPLOY_PATH"
    if ($base) { return $base.Trim().TrimEnd('/') }
    $sb = Get-DeployServerBase
    if ($sb) {
        return "$sb/$(Get-ProjectSlug)/$SecretsFolder"
    }
    return $null
}
