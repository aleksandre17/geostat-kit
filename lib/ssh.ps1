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
