#!/bin/zsh
# Run one command inside tools/famirender.sb, from the repo root (Kent, 2026-11-14: anything that
# loads the renderer's native code runs fenced). It may write only the game's audio, audio.json,
# build/famirender, the temp folder and build/listen -- the lab's output, which git ignores.
#     tools/audio_lab/sb.sh .venv/bin/python tools/audio_lab/render.py audio/music/x.txt build/listen/x.wav
set -e
ROOT=${0:A:h:h:h}
cd $ROOT
mkdir -p build/listen build/famirender
PY=$ROOT/.venv/bin/python
[[ -x $PY ]] || PY=python3
TMPD=$($PY -c "import tempfile, os; print(os.path.realpath(tempfile.gettempdir()))")
PYTHONDONTWRITEBYTECODE=1 exec sandbox-exec -f tools/famirender.sb -D HOME=$HOME \
  -D AUDIO_OUT=$ROOT/game/assets/audio -D CATALOG=$ROOT/game/config/audio.json \
  -D BUILD=$ROOT/build/famirender -D TMP=$TMPD -D SCRATCH=$ROOT/build/listen "$@"
