# SSH helpers for geostat deploy — optional ops/config/ssh/ keys

function Resolve-GeostatRepoPath {
    param([string]$Path)
    if (-not $Path) { return $null }
    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    Join-Path (Get-MonorepoRoot) ($Path -replace '/', '\')
}

function Get-GeostatSshExtraArgs {
    $args = [System.Collections.ArrayList]@()
    $cfg = Get-DeployEnvValue "DEPLOY_SSH_CONFIG_FILE"
    $id  = Get-DeployEnvValue "DEPLOY_SSH_IDENTITY_FILE"
    if ($cfg) {
        $cfgPath = Resolve-GeostatRepoPath $cfg
        if (Test-Path $cfgPath) {
            [void]$args.Add("-F")
            [void]$args.Add($cfgPath)
        }
    }
    if ($id) {
        $idPath = Resolve-GeostatRepoPath $id
        if (Test-Path $idPath) {
            [void]$args.Add("-i")
            [void]$args.Add($idPath)
        }
    }
    $extra = Get-DeployEnvValue "DEPLOY_SSH_OPTIONS"
    if ($extra) {
        $extra -split '\s+' | ForEach-Object { if ($_) { [void]$args.Add($_) } }
    }
    return $args
}

function Invoke-GeostatRemoteBash {
    param([string]$Script)
    $server = Get-DeployEnvValue "DEPLOY_SERVER"
    if (-not $server) { throw "DEPLOY_SERVER not set in ops/config/deploy.env" }
    $sshExtra = @(Get-GeostatSshExtraArgs)
    $oneLine = (($Script -replace "`r", "") -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }) -join ' '
    $escaped = $oneLine -replace '\\', '\\\\' -replace '"', '\"'
    & ssh @sshExtra $server "bash -lc `"$escaped`"" 2>&1 | ForEach-Object {
        Write-Host "[ssh] $_" -ForegroundColor DarkGray
    }
    return $LASTEXITCODE
}

function Invoke-GeostatScp {
    param([string]$LocalPath, [string]$RemoteDest)
    $server = Get-DeployEnvValue "DEPLOY_SERVER"
    if (-not $server) { throw "DEPLOY_SERVER not set" }
    $sshExtra = @(Get-GeostatSshExtraArgs)
    & scp @sshExtra $LocalPath "${server}:${RemoteDest}" 2>&1 | ForEach-Object {
        Write-Host "[scp] $_" -ForegroundColor DarkGray
    }
    return $LASTEXITCODE
}
