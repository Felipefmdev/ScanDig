@echo off
rem Teste manual das salas online (#30): sobe o noray local (se preciso) e abre
rem N janelas do jogo. Uso: play_online.bat [janelas]  (padrao 2, maximo 4)
setlocal EnableExtensions
set "GODOT=C:\Godot\Godot_v4.3-stable_win64.exe"
set "GODOT_CONSOLE=C:\Godot\Godot_v4.3-stable_win64_console.exe"
set "NORAY_DIR=%~dp0..\..\_ext\noray"
set "NORAY_PORT=8890"

cd /d "%~dp0.."
set "REPO=%CD%"
for %%I in ("%NORAY_DIR%") do set "NORAY_DIR=%%~fI"
if not exist "%GODOT%" set "GODOT=%GODOT_CONSOLE%"
if not exist "%GODOT%" (
	echo Godot nao encontrado em C:\Godot. Ajuste GODOT no topo deste arquivo.
	pause
	exit /b 1
)

set "WINDOWS=2"
if not "%~1"=="" set /a "WINDOWS=%~1" 2>nul
if %WINDOWS% LSS 1 set "WINDOWS=1"
if %WINDOWS% GTR 4 set "WINDOWS=4"

netstat -ano | findstr ":%NORAY_PORT%" | findstr LISTENING >nul && goto noray_ok
if not exist "%NORAY_DIR%\bin\noray.mjs" (
	echo noray nao encontrado em %NORAY_DIR%. Veja docs\CORE_AND_NETWORK.md, "Salas online".
	pause
	exit /b 1
)
where node >nul 2>nul || (
	echo node nao encontrado. Instale o Node.js.
	pause
	exit /b 1
)
rem A janela do noray herda estas variaveis (codigo de 6 caracteres; vencem o .env).
set "NORAY_OID_LENGTH=6"
set "NORAY_OID_CHARSET=23456789ABCDEFGHJKLMNPQRSTUVWXYZ"
echo Subindo o noray em %NORAY_DIR% ...
rem npm start formata o log com pino-pretty (dev); sem ele, node direto.
set "NORAY_CMD=node bin/noray.mjs"
if exist "%NORAY_DIR%\node_modules\.bin\pino-pretty.cmd" set "NORAY_CMD=npm start"
start "noray" /D "%NORAY_DIR%" cmd /k %NORAY_CMD%
set /a "TRIES=0"
:wait_noray
netstat -ano | findstr ":%NORAY_PORT%" | findstr LISTENING >nul && goto noray_ok
set /a "TRIES+=1"
if %TRIES% GEQ 15 (
	echo O noray nao abriu a porta %NORAY_PORT% em 15 s. Veja a janela "noray".
	pause
	exit /b 1
)
rem ~1 s; ping em vez de timeout (que falha sem console e e sombreado pelo do Git)
"%SystemRoot%\System32\ping.exe" -n 2 127.0.0.1 >nul
goto wait_noray

:noray_ok
echo noray no ar na porta %NORAY_PORT%.
for /l %%N in (1,1,%WINDOWS%) do start "" "%GODOT%" --path "%REPO%"

echo.
echo Abertas %WINDOWS% janelas do jogo.
echo  1. Na primeira janela: aba "Online (codigo)" ^> "Criar sala online".
echo     O codigo (ex.: K7Q-3MX) aparece na caixa "Mande este codigo para o seu amigo".
echo  2. Nas outras: digite o codigo na mesma aba e clique "Entrar".
echo Para desligar o noray, feche a janela "noray".
endlocal
