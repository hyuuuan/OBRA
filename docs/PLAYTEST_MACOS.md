# macOS playtest: the build and telemetry

The macOS package is `OBRA-macos.zip`. It contains the universal Godot app, the
local drawing recogniser, the model, and a bundled Python environment.

1. Unzip the package.
2. Double-click `Play OBRA.command`.
3. Quit the game from its pause menu when the session is finished.
4. Double-click `Collect playtest data.command`.
5. Enter an anonymous participant code. The script copies telemetry and
   `profile.json` into `playtest-data/<code>/`.
6. Confirm the clear prompt to prepare this copy for the next participant.

The first launch creates `gamesession/` next to `Play OBRA.command`. It holds
the profile, drawings, checkpoints, and anonymous game and recogniser telemetry.
Each extracted copy has its own folder. The collector reads from that folder
and clears its telemetry, drawings, checkpoints and profile when confirmed.
