# Windows playtest: the build, and the telemetry

The playtest build is one zip, `OBRA-windows.zip`. It holds the game, the drawing recogniser,
the model and a private copy of Python. School PCs need nothing installed, no admin rights
and no internet.

## What is in the zip

| Folder | What it is |
|---|---|
| `Play OBRA.bat` | Starts the game. Double-clicking `game\OBRA.exe` works too. |
| `Collect playtest data.bat` | Copies one player's data off the PC, then clears the PC for the next player. |
| `game\` | `OBRA.exe` and `OBRA.pck`, the release export. Development mode is off, so progression is normal. |
| `backend\`, `shared\`, `model\` | The recogniser and the CNN. |
| `.venv\` | Python 3.12 (python.org's build) with the recogniser's packages already installed, plus Microsoft's C++ runtime DLLs. |

Keep the folders together. The game finds the recogniser one folder up from `game\`, so
**always start it from `game\`**. Both launch methods above do this.

## Building it (on the Mac)

1. Install the **Godot 4.7.stable export templates**, once. In the Godot 4.7 editor, open
   *Editor → Manage Export Templates → Download and Install*. Or download
   `Godot_v4.7-stable_export_templates.tpz` from <https://godotengine.org/download/> and use
   *Install from File*. They end up in
   `~/Library/Application Support/Godot/export_templates/4.7.stable/`.
2. Fetch what the zip carries, once (online), into `build/windows-cache/`:
   - python.org's NuGet Python 3.12;
   - the Windows wheels of `backend/requirements.txt`, from PyPI;
   - Microsoft's Visual C++ Redistributable, from which 7-Zip takes the four runtime DLLs.
   ```bash
   brew install sevenzip
   .venv/bin/python tools/build_windows.py --fetch
   ```
3. Build the zip. Rebuild after every merge you want playtested:
   ```bash
   .venv/bin/python tools/build_windows.py
   ```
   The output is `build/windows/OBRA-windows.zip`. `build/` is gitignored, so never commit it.

## Before the class: a 5-minute check on one school PC

Use the PC and the account the class will use.

1. Copy the zip to the PC's **Desktop** (or Documents) and unzip it there, not on the USB stick.
2. Double-click `Play OBRA.bat`. If **"Windows protected your PC"** appears, click *More info*,
   then *Run anyway*. If nothing opens at all, the school blocks programs (see *Known risks*).
3. The title screen should show "Getting the drawing recogniser ready…". On a PC's first start
   this can take a minute or two while Windows Defender scans Python. Wait for it to go away.
4. Choose **New Game**, then draw anything at the first canvas. It should be recognised
   (named, or turned into something) within a second or two. If the game says the recogniser
   could not start, its message names the cause (see *Known risks*).
5. Solve the first obstacle, the beat, then quit from the pause menu.
6. Press **Win+R**, paste `%APPDATA%\Godot\app_userdata\O.B.R.A\telemetry` and press Enter.
   It should hold one `session_….jsonl` and one `backend_….jsonl`.
7. Run `Collect playtest data.bat` with the code `TEST` and answer **Y** to clear the PC.
   Delete the `TEST` folder afterwards.
8. Log off, log back on, and look at step 6's folder again. If it is gone, the PC resets
   itself (Deep Freeze or a roaming profile). **Collect before anyone logs off.**

## On the day

**Set up each PC:** copy and unzip the zip, start the game once, and wait out the first start
(check step 3).

**For each player:**

1. Give them a participant code that is unique across every PC, such as `PC03-01`. Write the
   code down; never their name.
2. They choose **New Game** and play.
3. When they finish, quit the game from its menu. Closing the window also works.
4. Double-click `Collect playtest data.bat`, type the code and answer **Y** to clear the PC.
   - The data lands in `playtest-data\<code>\` beside the `.bat`. Run a copy of the `.bat`
     from the USB stick and the data lands straight on the stick.
   - Clearing removes the progress, the kept drawings, the checkpoints and the telemetry, so the
     next player starts fresh, and their data never mixes with anyone else's.

**At the end:** copy every PC's `playtest-data` folder onto the USB stick before logging off.

### Where the files are, and copying them by hand

Use this if the `.bat` files are blocked.

| On each PC | What |
|---|---|
| `%APPDATA%\Godot\app_userdata\O.B.R.A\telemetry\session_<UTC time>_<id>.jsonl` | One per launch of the game |
| `%APPDATA%\Godot\app_userdata\O.B.R.A\telemetry\backend_<UTC date>.jsonl` | The recogniser's, one per day, appended across launches |
| `%APPDATA%\Godot\app_userdata\O.B.R.A\profile.json` | The save's progress counts |

`%APPDATA%` is `C:\Users\<account>\AppData\Roaming`. To collect by hand after each player:

1. Quit the game.
2. Open the folder with **Win+R**.
3. Copy the `telemetry` folder and `profile.json` into `<USB>\playtest-data\<code>\`.
4. Delete the `telemetry`, `drawings` and `checkpoints` folders and `profile.json`.

The backend file is shared by every launch that day, so clearing after each player is what
keeps the players apart. You can also choose New Game at the title screen, which resets the
progress, but it **does not** clear the telemetry.

## Afterwards: aggregating

Put every `playtest-data` folder in one place, outside the repo, then run:

```bash
.venv/bin/python tools/aggregate_telemetry.py ~/obra-playtest/ --out ~/obra-playtest/report.json
.venv/bin/python tools/aggregate_telemetry.py ~/obra-playtest/PC03-01/
```

The tool reads every `.jsonl` under a folder. The first command reports the whole class, and the
second reports one player. It gives:

- **Recognition:**
  - the redraw rate, also at the fixed 0.60 floor;
  - class diversity;
  - per-class precision and recall where the intended class is known;
  - how often drawings at obstacles met the tag asked for.
- **Table 14:** end-to-end and inference latency, frame rate, CPU and memory.
- **Beats:** each beat's solves by the hint tier they took (T0 none, T1 the tags, T2 the
  Ability Book, T3 the widened accept-set), how many were assisted, failed attempts per solve,
  and the routes taken. These count solves: a beat played twice counts twice.
- **Levels:** visits by outcome, and the time to complete, counting completed visits only.
- **Routes:** the routes at solves, the route rewards, the endings reached and the final
  tallies.

`--out report.json` holds all of it, beat by beat.

## What is recorded, and what is not

The telemetry is **anonymous and local**. Nothing is uploaded, and the recogniser only listens
on `127.0.0.1`.

- **Recorded:**
  - level start, end and outcome;
  - every recognition: the class, confidence, margin, runner-up, accepted or declined and why,
    latency, and the obstacle with its tags and hint tier (from the third hint, the intended
    class);
  - spawn timing, hint tiers, obstacles solved, routes, collectibles, fragments and the ending
    path;
  - frame rate and memory every second, and both processes' CPU and memory every second;
  - UTC timestamps.
- **Not recorded:** names, accounts, PC names, IP addresses, the drawings themselves. A scan
  of 86 existing session logs found no file paths or user names.
- **Left on the PC:**
  - `drawings\`: each class's kept sketch, which the thesis does not need;
  - `logs\godot.log` and `backend.log`: their file paths contain the Windows account name.

  Collect the logs only to debug a failure, and check them first.

The participant code is the only link between a person and their data. Keep any list that
pairs codes with names, such as consent forms, on paper or separately, never in
`playtest-data`.

## Known risks on school PCs

These can only be checked on a real PC:

- **Programs blocked:** AppLocker, or no running from Desktop/USB. Ask IT to allow the folder,
  or try Documents.
- **The recogniser's first start:** Defender scanning it can take minutes on a slow PC. The
  game waits and says so; later starts are fast.
- **Microsoft's C++ runtime:** onnxruntime needs `MSVCP140.dll` and `MSVCP140_1.dll`. The zip
  carries them, with the matching `vcruntime140`, in `.venv\Scripts`, so the PC needs no
  Visual C++ Redistributable. If a drawing still fails with "…DLL load failed…", the PC is
  probably older than Windows 10.
- **Graphics:** an old GPU without Vulkan or D3D12 falls back to OpenGL (Compatibility). If the
  game does not open, try another PC.
- **Ports:** the recogniser uses 127.0.0.1:8000, or 8765–8774 when 8000 is taken. It is loopback
  only, so there should be no firewall prompt. If one appears, *Cancel* is fine.
- **Reset on log-off:** see check step 8.
