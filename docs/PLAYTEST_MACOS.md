# macOS playtest: the build and telemetry

The macOS package is `OBRA-macos.zip`. It contains the universal Godot app, the
local drawing recogniser, the model, and its own Python (3.12, in `.venv`), so it
runs on a Mac with no Python installed. The recogniser needs an Apple Silicon Mac
(M1 or later); on an Intel Mac the game opens but drawings are not recognised.

1. Unzip the package.
2. Double-click `Play OBRA.command`. The first time, macOS blocks it, because the
   package has no paid Apple developer signature. Approve it once:
   - **macOS 15 (Sequoia) or later:** click **Done**, open **System Settings >
     Privacy & Security**, scroll to **Security**, click **Open Anyway** beside
     `Play OBRA.command`, enter the Mac's password, then click **Open**.
   - **macOS 14 or earlier:** Control-click `Play OBRA.command`, choose **Open**,
     then click **Open**.

   After that, a double-click starts it. Start the game with this launcher, not by
   opening `OBRA.app`. A downloaded zip marks every file as downloaded, and macOS
   stops the game's own Python from running while that mark is there. The
   launcher removes the mark from the OBRA folder, and only that folder.
3. Quit the game from its pause menu when the session is finished.
4. Double-click `Collect playtest data.command`.
5. Enter an anonymous participant code. The script copies telemetry and
   `profile.json` into `playtest-data/<code>/`.
6. Confirm the clear prompt to prepare this copy for the next participant.

The first launch creates `gamesession/` next to `Play OBRA.command`. It holds
the profile, drawings, checkpoints, and anonymous game and recogniser telemetry.
Each extracted copy has its own folder. The collector reads from that folder
and clears its telemetry, drawings, checkpoints and profile when confirmed.
