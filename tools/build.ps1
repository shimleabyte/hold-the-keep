# Build rilis Windows + Linux. Butuh Godot 4.3 dan export template 4.3 terpasang.
# Pemakaian: $env:GODOT = "C:\path\godot.exe"; .\tools\build.ps1
$ErrorActionPreference = "Stop"
$godot = if ($env:GODOT) { $env:GODOT } else { "godot" }
Set-Location (Join-Path $PSScriptRoot "..")
New-Item -ItemType Directory -Force build/windows, build/linux | Out-Null
& $godot --headless --import
& $godot --headless --export-release "Windows Desktop" build/windows/HoldTheKeep.exe
& $godot --headless --export-release "Linux" build/linux/HoldTheKeep.x86_64
Write-Host "Selesai: build/windows/HoldTheKeep.exe  build/linux/HoldTheKeep.x86_64"
