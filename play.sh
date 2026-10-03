#!/bin/sh
# OBRA on macOS and Linux: get the drawing recogniser ready, bring Godot's import up to date,
# play. The same steps play_windows.bat takes on Windows.
#
# RUN THIS AFTER EVERY GIT PULL. It is safe to run every time: the Python packages are only
# installed when .venv is missing or backend/requirements.txt has changed, and the import only
# redoes what changed.
#
#   ./play.sh                                   finds Godot 4.7 by itself
#   ./play.sh /path/to/Godot                    or use this one, and remember it
#   GODOT=/path/to/Godot ./play.sh              or say it for this shell
#
# On a Mac, double-clicking play_mac.command runs this in a Terminal window.
set -u
cd "$(dirname "$0")" || exit 1

fail() {
  echo
  echo " $1"
  echo " Stopped. The lines above say what went wrong."
  exit 1
}

# ---- Python 3.10 or newer, for the recogniser -------------------------------------------
PY=""
for candidate in python3.12 python3.11 python3.13 python3.14 python3.10 python3; do
  if command -v "$candidate" >/dev/null 2>&1 && \
      "$candidate" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)' 2>/dev/null; then
    PY="$candidate"
    break
  fi
done
if ! .venv/bin/python -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)' 2>/dev/null; then
  [ -n "$PY" ] || fail "Python 3.10 or newer is needed for the drawing recogniser, and none was found. Install it (https://www.python.org/downloads/, or 'brew install python'), then run this again."
  # An existing environment may still point at macOS's Python 3.9. Recreating it
  # keeps old packages out of the new interpreter; retain the old files for recovery.
  if [ -e .venv ]; then
    mkdir -p venv || fail "Could not create the environment backup folder."
    BACKUP="$(mktemp -d venv/previous.XXXXXX)" || fail "Could not create an environment backup."
    mv .venv "$BACKUP/.venv" || fail "Could not back up the old .venv."
    echo "Saved the incompatible Python environment in $BACKUP/.venv"
  fi
  echo "Making the Python environment in .venv ..."
  "$PY" -m venv .venv || fail "Could not make .venv with $PY."
fi
if ! cmp -s backend/requirements.txt .venv/obra-requirements.txt; then
  echo "Installing the recogniser's packages - the first time takes a few minutes ..."
  .venv/bin/python -m pip install --disable-pip-version-check -r backend/requirements.txt \
    || fail "Installing the packages failed."
  cp backend/requirements.txt .venv/obra-requirements.txt
fi

# ---- Wake the recogniser once, here ---------------------------------------------------
# Its first start on a computer is the slow one; done here it is a line in this window rather
# than a drawing that will not be recognised. It also says plainly what is wrong if the
# recogniser cannot load at all.
echo "Getting the drawing recogniser ready - the first time on a computer can take a minute ..."
.venv/bin/python backend/serve.py --check \
  || fail "The drawing recogniser cannot start. The line above that says OBRA_BACKEND_FAILED says why."

# ---- Godot 4.7 -------------------------------------------------------------------------
# The last Godot that worked is remembered in .venv, so naming it once is enough.
GODOT_EXE="${1:-${GODOT:-}}"
if [ -z "$GODOT_EXE" ] && [ -f .venv/obra-godot.txt ]; then
  STORED="$(cat .venv/obra-godot.txt)"
  [ -x "$STORED" ] && GODOT_EXE="$STORED"
fi
if [ -z "$GODOT_EXE" ]; then
  for candidate in godot godot4 /Applications/Godot.app/Contents/MacOS/Godot \
      "$HOME/Applications/Godot.app/Contents/MacOS/Godot"; do
    if command -v "$candidate" >/dev/null 2>&1 || [ -x "$candidate" ]; then
      GODOT_EXE="$(command -v "$candidate" 2>/dev/null || echo "$candidate")"
      break
    fi
  done
fi
if [ -z "$GODOT_EXE" ]; then
  for found in "$HOME"/Downloads/Godot*.app/Contents/MacOS/Godot "$HOME"/Downloads/Godot_v4.7*; do
    if [ -x "$found" ] && [ ! -d "$found" ]; then
      GODOT_EXE="$found"
      break
    fi
  done
fi
[ -n "$GODOT_EXE" ] || fail "Godot 4.7 was not found. Run: ./play.sh /full/path/to/Godot"
[ -x "$GODOT_EXE" ] || fail "There is no Godot at \"$GODOT_EXE\"."
echo "Using Godot at \"$GODOT_EXE\""
echo "$GODOT_EXE" > .venv/obra-godot.txt

# ---- Import, then play --------------------------------------------------------------
echo "Bringing Godot's import up to date - the first time takes a few minutes ..."
"$GODOT_EXE" --headless --path game --import >/dev/null 2>&1
echo "Starting OBRA ..."
exec "$GODOT_EXE" --path game
