@echo off
rem Copy one player's playtest data off this PC, then (if you say so) clear it for the next.
rem
rem The data goes into a "playtest-data" folder beside this file, one folder per participant
rem code. Run this copy from the USB stick and the data lands on the stick.
rem
rem It copies only the anonymous telemetry and the save's progress counts (profile.json). Not
rem the kept drawings, and not the logs, whose paths can contain the Windows user name.
setlocal EnableExtensions
set "DATA=%APPDATA%\Godot\app_userdata\O.B.R.A"

tasklist /FI "IMAGENAME eq OBRA.exe" /NH 2>nul | find /I "OBRA.exe" >nul
if not errorlevel 1 (
  echo.
  echo  O.B.R.A. is still running. Quit it from its menu first, then run this again.
  goto :end
)
if not exist "%DATA%\telemetry\session_*.jsonl" (
  echo.
  echo  There is no playtest data on this PC yet. It would be in:
  echo    %DATA%\telemetry
  goto :end
)

:ask
echo.
set "CODE="
set /p "CODE=Participant code for this player (letters, digits and -, e.g. PC03-01): "
if not defined CODE goto :ask
echo %CODE%| findstr /R /X "[A-Za-z0-9-]*" >nul || (echo  Only letters, digits and - please. & goto :ask)
set "DEST=%~dp0playtest-data\%CODE%"
if exist "%DEST%" (
  echo  %CODE% is already used in "%~dp0playtest-data". Pick another code.
  goto :ask
)

mkdir "%DEST%" || goto :failed
xcopy "%DATA%\telemetry" "%DEST%\telemetry\" /E /I /Q /Y >nul || goto :failed
if exist "%DATA%\profile.json" copy /Y "%DATA%\profile.json" "%DEST%\profile.json" >nul || goto :failed
if not exist "%DEST%\telemetry\session_*.jsonl" goto :failed
set "COUNT=0"
for %%F in ("%DEST%\telemetry\*.jsonl") do set /a COUNT+=1
echo.
echo  Copied %COUNT% telemetry file(s) to:
echo    %DEST%

echo.
choice /C YN /M "Clear this PC for the next player (progress, drawings and telemetry)"
if errorlevel 2 goto :end
rmdir /S /Q "%DATA%\telemetry" 2>nul
rmdir /S /Q "%DATA%\drawings" 2>nul
rmdir /S /Q "%DATA%\checkpoints" 2>nul
del /Q "%DATA%\profile.json" 2>nul
echo  Cleared. The next player starts from a new game.
goto :end

:failed
echo.
echo  Copying failed, so nothing on this PC was cleared. Copy this folder by hand instead:
echo    %DATA%\telemetry

:end
echo.
pause
