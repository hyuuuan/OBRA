@echo off
rem Start O.B.R.A. from its game folder. The game looks for its drawing recogniser (backend,
rem model and .venv) one folder up from where it is started, so it must start inside game\.
cd /d "%~dp0game" 2>nul || goto :missing
if not exist "OBRA.exe" goto :missing
start "" "OBRA.exe"
exit /b 0

:missing
echo.
echo  OBRA.exe is not in the game folder beside this file. Unzip the whole package again,
echo  keeping its folders together.
pause
exit /b 1
