$ErrorActionPreference = "Stop"
$raiz = $PSScriptRoot

Push-Location (Join-Path $raiz "server")
npm install
Pop-Location

Push-Location $raiz
flutter pub get
Pop-Location

Write-Host "Listo." -ForegroundColor Green
