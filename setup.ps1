$ErrorActionPreference = "Stop"
$raiz = $PSScriptRoot

Push-Location (Join-Path $raiz "server")
dart pub get
Pop-Location

Push-Location $raiz
flutter pub get
Pop-Location

Write-Host "Listo." -ForegroundColor Green
