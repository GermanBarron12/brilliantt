# Levanta el cliente con un solo comando: instala dependencias y corre la
# app.
#
# Uso:
#   .\iniciar_cliente.ps1
#   .\iniciar_cliente.ps1 -ApiBaseUrl "http://192.168.1.50:3000"
#   .\iniciar_cliente.ps1 -ApiBaseUrl "http://192.168.1.50:3000" -Dispositivo "RFCW11KC04X"
#
# -ApiBaseUrl: URL del servidor (por defecto http://localhost:3000, que
# sirve si el cliente corre en la misma maquina que el servidor).
# -Dispositivo: id del dispositivo (ver "flutter devices"). Si no se pasa,
# corre en Chrome en el puerto 5173.

param(
    [string]$ApiBaseUrl = "http://localhost:3000",
    [string]$Dispositivo = "chrome"
)

$ErrorActionPreference = "Stop"
Push-Location $PSScriptRoot

Write-Host "Usando API_BASE_URL=$ApiBaseUrl" -ForegroundColor Cyan
Write-Host "Dispositivo: $Dispositivo" -ForegroundColor Cyan

flutter pub get

if ($Dispositivo -eq "chrome") {
    flutter run -d chrome --web-port=5173 --dart-define=API_BASE_URL=$ApiBaseUrl
} else {
    flutter run -d $Dispositivo --dart-define=API_BASE_URL=$ApiBaseUrl
}

Pop-Location
