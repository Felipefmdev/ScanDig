@echo off
rem Executa um ou todos os roteiros de pacing em headless com --fixed-fps 60.
rem Uso: tools\bot\run_pacing.bat [praia|campo|ruinas|geleira|cratera|all] ["<godot_exe>"]
setlocal
set MAP=%~1
if "%MAP%"=="" set MAP=praia
set GODOT=%~2
if "%GODOT%"=="" set GODOT=C:\Users\felip\Downloads\Godot_v4.3-stable_win64.exe\Godot_v4.3-stable_win64_console.exe

if "%MAP%"=="all" (
    for %%M in (praia campo ruinas geleira cratera) do (
        echo === Executando pacing_%%M.json ===
        "%GODOT%" --headless --fixed-fps 60 --path . -- --bot=tools/bot/pacing_%%M.json
    )
) else (
    echo === Executando pacing_%MAP%.json ===
    "%GODOT%" --headless --fixed-fps 60 --path . -- --bot=tools/bot/pacing_%MAP%.json
)
