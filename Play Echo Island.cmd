@echo off
setlocal
set "ECHO_ENGINE=%USERPROFILE%\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
if exist "%ECHO_ENGINE%" (
    start "Echo Island" "%ECHO_ENGINE%" --path "%~dp0."
    exit /b 0
)
where godot >nul 2>nul
if not errorlevel 1 (
    start "Echo Island" godot --path "%~dp0."
    exit /b 0
)
echo Open project.godot with Godot 4.7.2 and press F5 to play.
pause
