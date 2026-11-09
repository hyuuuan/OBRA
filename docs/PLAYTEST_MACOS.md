# macOS playtest: the build and telemetry

The macOS package is `OBRA-macos.zip`. It contains the universal Godot app, the
local drawing recogniser, the model, and a bundled Python environment.

1. Unzip the package.
2. Double-click `Play OBRA.command`.
3. Quit the game from its pause menu when the session is finished.
4. Double-click `Collect playtest data.command`.
5. Enter an anonymous participant code. The script copies telemetry and
   `profile.json` into `playtest-data/<code>/`.
6. Confirm the clear prompt to prepare the Mac for the next participant.

Telemetry is local and anonymous. The game and recogniser write to:

`~/Library/Application Support/Godot/app_userdata/O.B.R.A/telemetry`

The collector copies the session and backend JSONL files, then removes the
telemetry, drawings, checkpoints, and profile from the Mac when confirmed.
