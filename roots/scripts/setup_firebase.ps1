# Roots Firebase one-shot setup (run AFTER `firebase login` succeeds)
# Usage: powershell -ExecutionPolicy Bypass -File .\scripts\setup_firebase.ps1

$ErrorActionPreference = "Stop"
$env:Path = "$env:LOCALAPPDATA\Pub\Cache\bin;$env:Path"

Set-Location $PSScriptRoot\..

Write-Host "==> Checking Firebase login..." -ForegroundColor Cyan
firebase login:list
if ($LASTEXITCODE -ne 0) { throw "Not logged in. Run: firebase login" }

Write-Host ""
Write-Host "==> Create a Firebase project in the browser if you do not have one yet:" -ForegroundColor Yellow
Write-Host "    https://console.firebase.google.com/ -> Add project -> name it e.g. roots-farm"
Write-Host "    Then enable: Authentication (Email/Password + Google), Firestore, Storage, Messaging"
Write-Host ""
$projectId = Read-Host "Enter your Firebase project ID (e.g. roots-farm)"

Write-Host "==> Configuring FlutterFire for all platforms..." -ForegroundColor Cyan
flutterfire configure --project=$projectId --yes --platforms=android,ios,web,windows,macos

Write-Host "==> Done. Next the agent will flip firebaseConfigured=true and build APK + Windows." -ForegroundColor Green
