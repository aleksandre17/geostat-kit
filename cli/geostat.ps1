# geostat-kit CLI — module drivers by stack type (java-boot, node-vite, node-api, …)

param(

    [Parameter(Position = 0)]

    [string]$Command = "help",

    [Parameter(ValueFromRemainingArguments = $true)]

    [string[]]$CliRest = @()

)



$PackageRoot = Split-Path $PSScriptRoot -Parent

if ($Command -eq "init") {
    & (Join-Path $PackageRoot "toolkit\init\Invoke-ProjectInit.ps1") -PackageRoot $PackageRoot @Args
    exit $LASTEXITCODE
}

. (Join-Path $PackageRoot "lib\project.ps1")

. (Join-Path $PackageRoot "lib\drivers.ps1")
. (Join-Path $PackageRoot "lib\modules.ps1")

$Root = Get-ProjectRootFromManifest

if (-not $Root) {

    Write-Host "  [ERROR] geostat.ops.json not found (run: geostat init)" -ForegroundColor Red

    exit 1

}

$env:GEOSTAT_PROJECT_ROOT = $Root

$env:GEOSTAT_KIT_ROOT = $PackageRoot



function Show-Help {
    $aliases = Get-CliAliasesFromManifest
    $aliasLine = '(none)'
    if ($aliases -and $aliases.Count -gt 0) {
        $aliasLine = ($aliases.GetEnumerator() | ForEach-Object { "$($_.Key)->$($_.Value)" }) -join ', '
    }

    Write-Host @"

  geostat - geostat-kit (kits/geostat-kit)

    init | validate | migrate | vscode-gen | stack | stack-deploy | compose-gen | nginx-gen | infra | layout

    mod <moduleId> deploy|manage|compose|check|modules  ...

    init  - full bootstrap (scaffold + seed secrets + compose-gen)

    Shortcuts (cli.aliases): $aliasLine

  Stack types (drivers/registry.json):

"@

    $py = if (Get-Command python3 -ErrorAction SilentlyContinue) { "python3" } else { "python" }

    & $py (Join-Path $PackageRoot "lib\driver_api.py") list-types 2>$null

    Write-Host ""

    Write-Host "  Project modules:"

    foreach ($mid in Get-ProjectModules) {

        $typ = Get-ModuleType $mid

        $caps = (Get-DriverCapabilities $mid) -join ", "

        $role = (Get-ModuleRole $mid)

        Write-Host "    $mid  role=$role  type=$typ  [$caps]"

    }

    $aliasMap = Get-CliAliasesFromManifest
    if ($aliasMap.Count -gt 0) {
        Write-Host ""
        Write-Host "  CLI aliases:"
        foreach ($k in ($aliasMap.Keys | Sort-Object)) {
            Write-Host "    $k -> $($aliasMap[$k])"
        }
    }

    Write-Host ""

}



$bash = "${env:ProgramFiles}\Git\bin\bash.exe"

if (-not (Test-Path $bash)) { $bash = "${env:ProgramFiles}\Git\usr\bin\bash.exe" }



function Invoke-ModuleDriver {

    param([string]$ModuleId, [string[]]$DriverArgs)

    if (-not (Get-ModuleManifestEntry $ModuleId)) {

        Write-Host "  Unknown module: $ModuleId" -ForegroundColor Red

        Write-Host "  Defined in geostat.ops.json modules.*"

        exit 1

    }

    $sub = if ($DriverArgs.Count -gt 0) { $DriverArgs[0] } else { "deploy" }

    $rest = if ($DriverArgs.Count -gt 1) { $DriverArgs[1..($DriverArgs.Count - 1)] } else { @() }

    # node-vite: "fe watch" -> "fe deploy watch" (static dist); "fe dev watch" stays under dev.ps1
    $modType = Get-ModuleType $ModuleId
    if ($sub -eq "watch" -and $modType -eq "node-vite") {
        Write-Host ""
        Write-Host "  Hint: fe watch -> fe deploy watch (npm build + static dist on server)" -ForegroundColor Yellow
        Write-Host "        fe dev watch -> source rsync to Linux dev container (no npm build)" -ForegroundColor Yellow
        Write-Host ""
        $env:GEOSTAT_MODULE_ID = $ModuleId
        $deployScript = Get-DriverCommandPath -ModuleId $ModuleId -Command "deploy"
        & $deployScript watch @rest
        exit $LASTEXITCODE
    }
    if ($sub -eq "watch" -and $modType -eq "java-boot") {
        Write-Host ""
        Write-Host "  Hint: be watch -> be dev watch (rsync + bootRun in workspace/)" -ForegroundColor Yellow
        Write-Host "        be deploy watch -> Gradle bootJar + runtime/ (staging JAR loop)" -ForegroundColor Yellow
        Write-Host ""
        $env:GEOSTAT_MODULE_ID = $ModuleId
        $devScript = Get-DriverCommandPath -ModuleId $ModuleId -Command "dev"
        & $bash $devScript watch @rest
        exit $LASTEXITCODE
    }

    # java-boot: "be deploy watch" — JAR publish loop (subcommand under deploy)
    if ($sub -eq "deploy" -and $modType -eq "java-boot" -and $rest.Count -gt 0 -and $rest[0] -eq "watch") {
        $env:GEOSTAT_MODULE_ID = $ModuleId
        $deployScript = Get-DriverCommandPath -ModuleId $ModuleId -Command "deploy"
        & $bash $deployScript watch @($rest | Select-Object -Skip 1)
        exit $LASTEXITCODE
    }

    $valid = @{}

    foreach ($c in Get-DriverCapabilities $ModuleId) { $valid[$c] = 1 }

    if (-not $valid.ContainsKey($sub)) {

        Write-Host "  Unknown subcommand: $sub (module $ModuleId, type $modType)" -ForegroundColor Red

        Write-Host "  Valid: $($valid.Keys -join ' | ')"
        if ($modType -eq "node-vite") {
            Write-Host "  Frontend watch: deploy watch | dev watch  (see docs/FE-WATCH.md)" -ForegroundColor Gray
        }

        exit 1

    }

    $type = Get-ModuleType $ModuleId

    $reg = Get-Content (Get-DriverRegistryPath) -Raw | ConvertFrom-Json

    $runtime = $reg.$type.runtime

    $script = Get-DriverCommandPath -ModuleId $ModuleId -Command $sub

    $env:GEOSTAT_MODULE_ID = $ModuleId

    if ($runtime -eq "bash") {

        if (-not (Test-Path $bash)) { Write-Host "Git Bash required for driver $type"; exit 1 }

        & $bash $script @rest

    } else {

        & $script @rest

    }

    exit $LASTEXITCODE

}



$globalCommands = @{

    "help" = { Show-Help }

    "stack" = {

        & (Join-Path $PackageRoot "toolkit\stack\compose.ps1") @Args

        exit $LASTEXITCODE

    }

    "stack-deploy" = {

        if (-not (Test-Path $bash)) { Write-Host "Git Bash required"; exit 1 }

        & $bash (Join-Path $PackageRoot "toolkit\deploy\stack-remote.sh") @Args

        exit $LASTEXITCODE

    }

    "validate" = {
        $py = if (Get-Command python3 -ErrorAction SilentlyContinue) { "python3" } else { "python" }
        $env:PYTHONPATH = "$PackageRoot"
        & $py (Join-Path $PackageRoot "lib\validate_manifest.py")
        exit $LASTEXITCODE
    }

    "migrate" = {
        $py = if (Get-Command python3 -ErrorAction SilentlyContinue) { "python3" } else { "python" }
        $env:PYTHONPATH = "$PackageRoot"
        & $py (Join-Path $PackageRoot "lib\migrate_manifest.py") @Args
        exit $LASTEXITCODE
    }

    "vscode-gen" = {
        $py = if (Get-Command python3 -ErrorAction SilentlyContinue) { "python3" } else { "python" }
        $env:PYTHONPATH = "$PackageRoot"
        $vargs = @()
        if ($CliRest -contains "--force") { $vargs += "--force" }
        & $py (Join-Path $PackageRoot "lib\vscode_gen.py") @vargs
        exit $LASTEXITCODE
    }

    "compose-gen" = {

        & (Join-Path $PackageRoot "compose\build.ps1")

        exit $LASTEXITCODE

    }

    "nginx-gen" = {

        $py = if (Get-Command python3 -ErrorAction SilentlyContinue) { "python3" } else { "python" }

        & $py (Join-Path $PackageRoot "adapters\render_nginx.py")

        exit $LASTEXITCODE

    }

    "infra" = {

        $infraDriver = Join-Path $PackageRoot "toolkit\infra\Invoke-Infra.ps1"
        $infraPass = @($CliRest)
        if ($infraPass.Count -eq 0 -and $infraPass -isnot [string]) {
            $infraPass = @()
        }
        if ($infraPass.Count -gt 0 -and (Test-Path $infraDriver)) {
            & $infraDriver @infraPass
            exit $LASTEXITCODE
        }
        if (-not (Test-Path $bash)) { Write-Host "Git Bash required for: geostat infra (prereqs)"; exit 1 }
        & $bash (Join-Path $PackageRoot "toolkit\infra\ensure-prereqs.sh")
        exit $LASTEXITCODE

    }

    "layout" = {
        $layoutArgs = [System.Collections.ArrayList]@($CliRest)
        $roleFilter = $null
        $modFilter = $null
        $runAll = $false
        $runServer = $true
        $i = 0
        while ($i -lt $layoutArgs.Count) {
            $a = [string]$layoutArgs[$i]
            if ($a -in @("--all")) { $runAll = $true; $layoutArgs.RemoveAt($i); continue }
            if ($a -in @("--no-server")) { $runServer = $false; $layoutArgs.RemoveAt($i); continue }
            if ($a -in @("--frontend", "-Frontend")) {
                Write-Host "  [warn] --frontend deprecated; use --role ui" -ForegroundColor Yellow
                $roleFilter = "ui"; $layoutArgs.RemoveAt($i); continue
            }
            if ($a -in @("--backend", "-Backend")) {
                Write-Host "  [warn] --backend deprecated; use --role api" -ForegroundColor Yellow
                $roleFilter = "api"; $layoutArgs.RemoveAt($i); continue
            }
            if ($a -in @("--role", "-Role") -and ($i + 1) -lt $layoutArgs.Count) {
                $roleFilter = [string]$layoutArgs[$i + 1]
                $layoutArgs.RemoveAt($i + 1); $layoutArgs.RemoveAt($i); continue
            }
            if ($a -in @("--module", "-Module") -and ($i + 1) -lt $layoutArgs.Count) {
                $modFilter = [string]$layoutArgs[$i + 1]
                $layoutArgs.RemoveAt($i + 1); $layoutArgs.RemoveAt($i); continue
            }
            $i++
        }
        $targets = [System.Collections.ArrayList]@()
        if ($modFilter) {
            if (-not (Get-ModuleManifestEntry $modFilter)) {
                Write-Host "  Unknown module: $modFilter" -ForegroundColor Red; exit 1
            }
            [void]$targets.Add($modFilter)
        } elseif ($roleFilter) {
            foreach ($mid in (Get-ModuleIdsByRole $roleFilter)) { [void]$targets.Add($mid) }
            if ($targets.Count -eq 0) {
                Write-Host "  No modules with role=$roleFilter" -ForegroundColor Red; exit 1
            }
        } elseif ($runAll) {
            foreach ($mid in (Get-ProjectModules)) { [void]$targets.Add($mid) }
        } else {
            foreach ($mid in (Get-ProjectModules)) { [void]$targets.Add($mid) }
        }
        foreach ($mid in $targets) {
            Write-Host ""
            Write-Host "  === layout: module $mid (role $(Get-ModuleRole $mid), type $(Get-ModuleType $mid)) ===" -ForegroundColor Cyan
            Invoke-ModuleLayoutSimulator -ModuleId $mid @layoutArgs
        }
        if ($runServer -and -not $modFilter -and -not $roleFilter) {
            & (Join-Path $PackageRoot "toolkit\layout\simulate-server-layout.ps1") @layoutArgs
        }
        exit $LASTEXITCODE
    }

}



if ($globalCommands.ContainsKey($Command)) {

    & $globalCommands[$Command]

    exit $LASTEXITCODE

}



if ($Command -eq "mod") {

    if ($CliRest.Count -lt 1) {

        Write-Host "  Usage: geostat mod <moduleId> <deploy|manage|...> [args]" -ForegroundColor Red

        exit 1

    }

    $moduleId = $CliRest[0]

    $rest = if ($CliRest.Count -gt 1) { $CliRest[1..($CliRest.Count - 1)] } else { @() }

    Invoke-ModuleDriver -ModuleId $moduleId -DriverArgs $rest

}



$aliasTarget = Resolve-CliAlias $Command

if ($aliasTarget) {

    Invoke-ModuleDriver -ModuleId $aliasTarget -DriverArgs $CliRest

}



Write-Host "  Unknown command: $Command" -ForegroundColor Red

Write-Host "  Run: geostat help"

exit 1

