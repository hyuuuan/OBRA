@echo off
rem OBRA on Windows: get the drawing recogniser ready, bring Godot's import up to date, play.
rem
rem RUN THIS AFTER EVERY GIT PULL. It is safe to run every time: the Python packages are only
rem installed when .venv is missing or backend\requirements.txt has changed, and the import
rem only redoes what changed. Skipping the import after a pull that brought new art or new
rem scripts is what makes the game come up on an "ARE YOU SURE?" screen nothing closes.
rem
rem   play_windows.bat                                  finds Godot 4.7 by itself
rem   play_windows.bat "C:\path\Godot_v4.7-stable_win64.exe"   or use this one, and remember it
rem   drag Godot_v4.7-stable_win64.exe onto this file    same thing
rem   set GODOT=C:\path\Godot_v4.7-stable_win64.exe      or say it for the window
setlocal EnableExtensions
cd /d "%~dp0"

rem ---- Python 3.10 or newer, for the recogniser ---------------------------------------
set "PY="
py -3 -c "import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)" >nul 2>&1 && set "PY=py -3"
if not defined PY (
  python -c "import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)" >nul 2>&1 && set "PY=python"
)
if not defined PY (
  echo.
  echo  Python 3.10 or newer is needed for the drawing recogniser, and none was found.
  echo  Install it from https://www.python.org/downloads/ and tick "Add python.exe to PATH",
  echo  then run this again.
  goto :fail
)

if not exist ".venv\Scripts\python.exe" (
  echo Making the Python environment in .venv ...
  %PY% -m venv .venv
  if errorlevel 1 goto :fail
)

fc /b "backend\requirements.txt" ".venv\obra-requirements.txt" >nul 2>&1
if errorlevel 1 (
  echo Installing the recogniser's packages - the first time takes a few minutes ...
  ".venv\Scripts\python.exe" -m pip install --disable-pip-version-check -r "backend\requirements.txt"
  if errorlevel 1 goto :fail
  copy /y "backend\requirements.txt" ".venv\obra-requirements.txt" >nul
)

rem ---- Godot 4.7 -------------------------------------------------------------------------
rem The last Godot that worked is remembered in .venv, so dragging it on once is enough.
set "GODOT_EXE=%~1"
set "STORED="
if not defined GODOT_EXE if defined GODOT set "GODOT_EXE=%GODOT:"=%"
if not defined GODOT_EXE if exist ".venv\obra-godot.txt" (
  set /p STORED=<".venv\obra-godot.txt"
)
if not defined GODOT_EXE if defined STORED if exist "%STORED%" set "GODOT_EXE=%STORED%"
if not defined GODOT_EXE (
  for /f "delims=" %%G in ('where godot 2^>nul') do if not defined GODOT_EXE set "GODOT_EXE=%%G"
)
if not defined GODOT_EXE (
  for %%D in ("%CD%" "%USERPROFILE%\Downloads" "%USERPROFILE%\Desktop" "%USERPROFILE%\Documents") do (
    if not defined GODOT_EXE (
      for /f "delims=" %%G in ('dir /b /s "%%~D\Godot_v4.7*_win64.exe" 2^>nul') do if not defined GODOT_EXE set "GODOT_EXE=%%G"
    )
  )
)
if not defined GODOT_EXE (
  echo.
  echo  Godot 4.7 was not found. Drag Godot_v4.7-stable_win64.exe onto this file, or run
  echo    play_windows.bat "C:\full\path\to\Godot_v4.7-stable_win64.exe"
  goto :fail
)
if not exist "%GODOT_EXE%" (
  echo.
  echo  There is no Godot at "%GODOT_EXE%".
  goto :fail
)
echo Using Godot at "%GODOT_EXE%"
>".venv\obra-godot.txt" echo %GODOT_EXE%

rem ---- Import, then play --------------------------------------------------------------
echo Bringing Godot's import up to date - the first time takes a few minutes ...
"%GODOT_EXE%" --headless --path game --import
echo Starting OBRA ...
start "" "%GODOT_EXE%" --path game
exit /b 0

:fail
echo.
echo  Stopped. The lines above say what went wrong.
pause
exit /b 1
