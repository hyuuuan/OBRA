O.B.R.A. - Windows playtest build

PLAYING
1. Copy OBRA-windows.zip onto the PC (Desktop or Documents) and unzip it there.
   Do not play from the USB stick, and not from inside the zip.
2. Double-click "Play OBRA.bat" (or game\OBRA.exe).
   If Windows says "Windows protected your PC": More info, then Run anyway.
3. The first start on a PC can take a minute or two before a drawing is recognised;
   the game says so while it waits. Later starts are quick.

Nothing needs installing, and no internet is needed. Python and the drawing
recogniser are in the .venv, backend, model and shared folders: keep every folder
beside the others.

PLAYTEST DATA
Saved on each PC in:  %APPDATA%\Godot\app_userdata\O.B.R.A\telemetry
After each player: quit the game, then double-click "Collect playtest data.bat".
It copies the data into playtest-data\<participant code> beside it, then offers to
clear the PC for the next player.

The full guide is docs/PLAYTEST_WINDOWS.md in the project.
