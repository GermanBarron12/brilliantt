$ErrorActionPreference = "Stop"
$raiz = $PSScriptRoot

# El servidor vive en un repo aparte (brilliant-server): este script ya no
# instala sus dependencias. Clonarlo y correr `dart pub get` ahi.
Push-Location $raiz
flutter pub get
Pop-Location

Write-Host "Listo." -ForegroundColor Green
