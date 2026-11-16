#!/bin/sh
set -eu
cd "$(dirname "$0")"
# Only ever the package's own folder: a copy of this file moved elsewhere must not touch what
# is around it.
if [ ! -d "game/OBRA.app" ] || [ ! -d ".venv" ]; then
	echo "Keep Play OBRA.command in the OBRA folder, beside game and .venv."
	exit 1
fi
# ⚠ A DOWNLOADED COPY IS FLAGGED, AND THE FLAG KILLS ITS PYTHON. Safari, AirDrop and chat apps
# mark a download as quarantined, and unzipping copies the mark onto every file inside. The game
# and its Python carry no Apple developer signature (that needs a paid account), so macOS killed
# the flagged Python the moment the game started it, and the game, finding no Python that ran,
# said none was installed. A flagged app is also run from a hidden temporary copy, away from the
# .venv beside it. Opening this file once from Privacy & Security is the tester's approval; the
# mark comes off this folder only, and the game then opens from where it is.
xattr -dr com.apple.quarantine . 2>/dev/null || true
exec open "game/OBRA.app"
