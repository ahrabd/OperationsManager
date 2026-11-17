$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$packageRoot = Split-Path -Parent $scriptDir
$appDir = Join-Path $packageRoot 'app'

if (Test-Path -LiteralPath $appDir) {
    $bat = Join-Path $appDir 'operationsmanager.bat'
    $outDir = $packageRoot
} else {
    $bat = Join-Path $scriptDir 'operationsmanager.bat'
    $outDir = $scriptDir
}

$uiSource = Join-Path $scriptDir 'Installer.cs'
$cliSource = Join-Path $scriptDir 'InstallerCLI.cs'
$uiOutput = Join-Path $outDir 'OperationsManagerInstaller.exe'
$cliOutput = Join-Path $outDir 'OperationsManagerInstallerCLI.exe'

foreach ($required in @($bat, $uiSource, $cliSource)) {
    if (-not (Test-Path -LiteralPath $required)) { throw "Missing: $required" }
}

$candidates = @(
    (Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'),
    (Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe'),
    (Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v3.5\csc.exe'),
    (Join-Path $env:WINDIR 'Microsoft.NET\Framework\v3.5\csc.exe')
)
$csc = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if (-not $csc) { throw 'Could not find csc.exe (.NET Framework C# compiler).' }

Write-Host "Using compiler: $csc"
Write-Host ""

Write-Host "Building GUI installer (no console window)..."
& $csc /nologo /target:winexe /platform:anycpu /optimize+ `
    /resource:"$bat,OperationsManager.bat" `
    /out:"$uiOutput" `
    "$uiSource"
if ($LASTEXITCODE -ne 0) { throw "GUI installer compilation failed with exit code $LASTEXITCODE" }

Write-Host "Building CLI installer (console)..."
& $csc /nologo /target:exe /platform:anycpu /optimize+ `
    /resource:"$bat,OperationsManager.bat" `
    /out:"$cliOutput" `
    "$cliSource"
if ($LASTEXITCODE -ne 0) { throw "CLI installer compilation failed with exit code $LASTEXITCODE" }

Write-Host ""
foreach ($item in @((Get-Item -LiteralPath $uiOutput), (Get-Item -LiteralPath $cliOutput))) {
    Write-Host ("Built: {0}  ({1:N1} KB)" -f $item.FullName, ($item.Length / 1KB))
}
Write-Host ""
Write-Host "Main installer (double-click): OperationsManagerInstaller.exe"
Write-Host "Silent/scripting installer:    OperationsManagerInstallerCLI.exe"
