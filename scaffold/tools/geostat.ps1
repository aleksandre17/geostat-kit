# Shim — canonical entry: ops/cli/geostat.ps1
param(
    [Parameter(Position = 0)]
    [string]$Command = "help",
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)
$Root = Split-Path $PSScriptRoot -Parent
& (Join-Path $Root "ops\cli\geostat.ps1") -Command $Command -Args $Args
exit $LASTEXITCODE
