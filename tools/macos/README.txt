O.B.R.A. macOS playtest

Double-click "Play OBRA.command" to start the game. Always start it this way,
not by opening OBRA.app.

The first time, macOS blocks it, because the package has no paid Apple developer
signature. Approve it once:
- macOS 15 or later: click Done, open System Settings > Privacy & Security,
  scroll to Security, click Open Anyway beside "Play OBRA.command", enter the
  Mac's password, then click Open.
- macOS 14 or earlier: Control-click "Play OBRA.command", choose Open, then
  click Open.
The launcher then removes the downloaded-file mark from this folder only, which
macOS would otherwise use to stop the game's own Python from running.

Double-click "Collect playtest data.command" after quitting the game to copy
anonymous telemetry and profile.json into playtest-data/<participant-code>.

The game creates gamesession/ beside this file. Each extracted copy keeps its
own progress and telemetry there.

Keep the game, backend, model, shared, and .venv folders together. The .venv
folder is the game's own Python: nothing needs to be installed. It needs an Apple
Silicon Mac (M1 or later).
