# Resolves boot JAR and runs java -jar (Windows-safe vs Gradle includeBuild lock)
function Get-GeostatHybridBootJar {
    param(
        [string]$Root,
        [string]$ModuleId,
        [string]$ModPath
    )
    $explicit = Get-ManifestField "modules.$ModuleId.hybrid.bootJar"
    if ($explicit) {
        return Join-Path $Root ($explicit -replace '/', '\')
    }
    $libsDir = Join-Path $ModPath "build\libs"
    if (-not (Test-Path $libsDir)) { return $null }
    $candidates = Get-ChildItem $libsDir -Filter "*.jar" |
        Where-Object { $_.Name -notmatch 'plain' -and $_.Name -match 'SNAPSHOT' } |
        Sort-Object LastWriteTime -Descending
    if ($candidates) { return $candidates[0].FullName }
    return $null
}

function Test-GeostatPreferHybridJar {
    param([string]$ModuleId)
    if ($env:GEOSTAT_HYBRID_GRADLE -eq '1') { return $false }
    if ($env:GEOSTAT_HYBRID_JAR -eq '1') { return $true }
    $pref = Get-ManifestField "modules.$ModuleId.hybrid.preferJar"
    if ($pref -eq 'true') { return $true }
    if ($pref -eq 'false') { return $false }
    return $IsWindows
}

function Invoke-GeostatHybridJarBoot {
    param(
        [string]$Root,
        [string]$ModuleId,
        [string]$ModPath
    )
    $jar = Get-GeostatHybridBootJar -Root $Root -ModuleId $ModuleId -ModPath $ModPath
    if (-not $jar -or -not (Test-Path $jar)) {
        return
    }

    $profiles = Get-ManifestField "modules.$ModuleId.hybrid.springProfiles"
    if ($profiles) { $env:SPRING_PROFILES_ACTIVE = $profiles }

    if ($ModuleId -eq 'chat-api') {
        $env:SPRING_FLYWAY_ENABLED = 'false'
        $env:SPRING_AUTOCONFIGURE_EXCLUDE =
            'org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration,org.springframework.boot.flyway.autoconfigure.FlywayAutoConfiguration'
    }

    Write-Host "[hybrid] jar boot $ModuleId -> $jar" -ForegroundColor Cyan
    Set-Location $ModPath
    & java -jar $jar
    exit $LASTEXITCODE
}
