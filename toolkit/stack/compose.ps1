# Full stack compose runner (manifest: stack.composeDir)
param([switch]$Prod)

$PackageRoot = $PSScriptRoot | Split-Path -Parent | Split-Path -Parent
. (Join-Path $PackageRoot "lib\project.ps1")
. (Join-Path $PackageRoot "lib\env.ps1")
$Root = Get-ProjectRootFromManifest
if (-not $Root) { throw "geostat.ops.json not found" }

$composeRel = Get-ManifestField "stack.composeDir" "ops/compose/stack"
$ComposeDir = Join-Path $Root $composeRel

$envArgs = Get-StackComposeEnvFileArgs -Environment $(if ($Prod) { "prod" } else { "dev" })
$fileArgs = if ($Prod) { @("-f", "docker-compose.prod.yml") } else { @("-f", "docker-compose.yml") }

Push-Location $ComposeDir
try {
    Write-Host ""
    $stackName = Get-DeployEnvValue "COMPOSE_PROJECT_NAME" (Split-Path $Root -Leaf)
    Write-Host "  $stackName stack ($(if ($Prod) { 'prod' } else { 'dev' }))" -ForegroundColor Cyan
    Write-Host "  UI  -> http://localhost:$(Get-SecretsEnvValue -Module frontend -Key DEPLOY_HOST_PORT -Default '5177')" -ForegroundColor Gray
    Write-Host "  API -> http://localhost:$(Get-SecretsEnvValue -Module backend -Key API_PORT -Default '8090')" -ForegroundColor Gray
    Write-Host ""
    & docker compose @envArgs @fileArgs @args
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
