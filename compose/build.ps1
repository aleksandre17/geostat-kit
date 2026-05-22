# Regenerate compose from project catalog via geostat-kit package
$ErrorActionPreference = "Stop"
$PackageCompose = Join-Path $PSScriptRoot "build.py"
$py = if (Get-Command python3 -ErrorAction SilentlyContinue) { "python3" } else { "python" }
& $py $PackageCompose
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
