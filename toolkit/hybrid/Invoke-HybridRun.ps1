# Local app run: host process + manifest secrets (.env.dev); optional remote infra via tunnel
param(
    [Parameter(Mandatory = $true)]
    [string]$ModuleId
)

$ErrorActionPreference = "Stop"

$PackageRoot = if ($env:GEOSTAT_KIT_ROOT) { $env:GEOSTAT_KIT_ROOT } else {
    Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
}
. (Join-Path $PackageRoot "lib\project.ps1")
. (Join-Path $PackageRoot "lib\env.ps1")
. (Join-Path $PackageRoot "lib\drivers.ps1")

$root = Get-ProjectRootFromManifest
if (-not $root) { throw "geostat.ops.json not found" }

$entry = Get-ModuleManifestEntry $ModuleId
if (-not $entry) { throw "Unknown module: $ModuleId" }

$modPath = Get-ModuleProjectPath $ModuleId
$secretsModule = Get-ModuleSecretsFolder $ModuleId
$envDev = Join-Path (Get-SecretsModuleDir $secretsModule) ".env.dev"

function Import-GeostatDotEnv([string]$Path, [switch]$SkipEmptyValues) {
    if (-not (Test-Path $Path)) { return }
    Get-Content $Path | ForEach-Object {
        if ($_ -match '^\s*#' -or $_ -notmatch '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') { return }
        $value = $Matches[2].Trim().Trim('"').Trim("'")
        if ($SkipEmptyValues -and [string]::IsNullOrWhiteSpace($value)) { return }
        Set-Item -Path "env:$($Matches[1])" -Value $value
    }
}

$envProd = Join-Path (Get-SecretsModuleDir $secretsModule) ".env.prod"
Import-GeostatDotEnv $envProd
Import-GeostatDotEnv $envDev -SkipEmptyValues

$driverType = Get-ModuleType $ModuleId
Write-Host "[hybrid] boot $ModuleId ($driverType) env=$envDev" -ForegroundColor Cyan

switch ($driverType) {
    "java-boot" {
        . (Join-Path $PSScriptRoot "Invoke-HybridJarBoot.ps1")
        if (Test-GeostatPreferHybridJar -ModuleId $ModuleId) {
            $jar = Get-GeostatHybridBootJar -Root $root -ModuleId $ModuleId -ModPath $modPath
            if ($jar -and (Test-Path $jar)) {
                Invoke-GeostatHybridJarBoot -Root $root -ModuleId $ModuleId -ModPath $modPath
            } else {
                Write-Host "[hybrid] boot JAR missing — falling back to gradle bootRun (build first or set hybrid.bootJar)" -ForegroundColor Yellow
            }
        }

        $profiles = Get-ManifestField "modules.$ModuleId.hybrid.springProfiles"
        if ($profiles) { $env:SPRING_PROFILES_ACTIVE = $profiles }

        $wrapperRel = Get-ManifestField "modules.$ModuleId.hybrid.gradleWrapper"
        if (-not $wrapperRel) {
            if (Test-Path (Join-Path $modPath "gradlew.bat")) {
                $wrapperRel = (Join-Path (Get-ManifestField "modules.$ModuleId.path") "gradlew.bat") -replace '\\', '/'
            } elseif (Test-Path (Join-Path $modPath "gradlew")) {
                $wrapperRel = (Join-Path (Get-ManifestField "modules.$ModuleId.path") "gradlew") -replace '\\', '/'
            }
        }
        if (-not $wrapperRel) {
            throw "No gradlew in module path; set modules.$ModuleId.hybrid.gradleWrapper in geostat.ops.json"
        }

        $wrapper = Join-Path $root ($wrapperRel -replace '/', '\')
        if (-not (Test-Path $wrapper)) { throw "Gradle wrapper not found: $wrapper" }

        $gradleProject = Get-ManifestField "modules.$ModuleId.hybrid.gradleProject"
        $bootTask = if ($gradleProject) { ":${gradleProject}:bootRun" } else { "bootRun" }

        Set-Location $modPath
        & $wrapper $bootTask -x test
        exit $LASTEXITCODE
    }
    "node-vite" {
        $npmScript = Get-ManifestField "modules.$ModuleId.debug.npmScript"
        if (-not $npmScript) { $npmScript = Get-ManifestField "modules.$ModuleId.hybrid.npmScript" }
        if (-not $npmScript) { $npmScript = "dev" }

        Set-Location $modPath
        npm run $npmScript
        exit $LASTEXITCODE
    }
    default {
        throw "Hybrid run not supported for driver type '$driverType' (module $ModuleId)"
    }
}
