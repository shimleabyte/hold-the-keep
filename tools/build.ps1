# Build rilis Windows + Linux. Butuh Godot 4.3 dan export template 4.3 terpasang.
# Pemakaian: $env:GODOT = "C:\path\godot.exe"; .\tools\build.ps1
$ErrorActionPreference = "Stop"
$godot = if ($env:GODOT) { $env:GODOT } else { "godot" }
$godotVersion = & $godot --version
if ($LASTEXITCODE -ne 0) {
    throw "Could not execute Godot: $godot"
}
if ($godotVersion -notmatch '^4\.7(\.|$)') {
    throw "Hold the Keep requires Godot 4.7; detected: $godotVersion"
}
Set-Location (Join-Path $PSScriptRoot "..")
New-Item -ItemType Directory -Force build/windows, build/linux | Out-Null
& $godot --headless --import
& $godot --headless --export-release "Windows Desktop" build/windows/HoldTheKeep.exe
& $godot --headless --export-release "Linux" build/linux/HoldTheKeep.x86_64
foreach ($artifact in @("build/windows/HoldTheKeep.exe", "build/linux/HoldTheKeep.x86_64")) {
    if (-not (Test-Path $artifact) -or (Get-Item $artifact).Length -le 0) {
        throw "Export did not produce a non-empty artifact: $artifact"
    }
}
Write-Host "Selesai: build/windows/HoldTheKeep.exe  build/linux/HoldTheKeep.x86_64"
