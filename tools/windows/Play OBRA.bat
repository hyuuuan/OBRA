@echo off
rem Start the O.B.R.A. executable in this package's game folder.
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
