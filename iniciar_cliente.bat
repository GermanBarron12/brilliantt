@echo off
rem Levanta el cliente con un solo comando: instala dependencias y corre
rem la app.
rem
rem Uso:
rem   iniciar_cliente.bat
rem   iniciar_cliente.bat http://192.168.1.50:3000
rem   iniciar_cliente.bat http://192.168.1.50:3000 RFCW11KC04X
rem
rem Primer parametro opcional: API_BASE_URL del servidor (por defecto
rem http://localhost:3000, que sirve si el cliente corre en la misma
rem maquina que el servidor).
rem Segundo parametro opcional: id del dispositivo (ver "flutter devices").
rem Si no se pasa, corre en Chrome en el puerto 5173.

setlocal
cd /d "%~dp0"

set API_BASE_URL=%1
if "%API_BASE_URL%"=="" set API_BASE_URL=http://localhost:3000

set DISPOSITIVO=%2
if "%DISPOSITIVO%"=="" set DISPOSITIVO=chrome

echo Usando API_BASE_URL=%API_BASE_URL%
echo Dispositivo: %DISPOSITIVO%

call flutter pub get
if errorlevel 1 goto :error

if "%DISPOSITIVO%"=="chrome" (
    flutter run -d chrome --web-port=5173 --dart-define=API_BASE_URL=%API_BASE_URL%
) else (
    flutter run -d %DISPOSITIVO% --dart-define=API_BASE_URL=%API_BASE_URL%
)
goto :fin

:error
echo.
echo Algo fallo antes de correr la app. Revisa el mensaje de arriba.
exit /b 1

:fin
endlocal
