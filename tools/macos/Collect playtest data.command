#!/bin/sh
set -eu
cd "$(dirname "$0")"

DATA="${HOME}/Library/Application Support/Godot/app_userdata/O.B.R.A"
if pgrep -x 'O.B.R.A' >/dev/null 2>&1; then
  echo "O.B.R.A. is still running. Quit it from the pause menu first."
  read -r _
  exit 1
fi
if ! ls "$DATA"/telemetry/session_*.jsonl >/dev/null 2>&1; then
  echo "No playtest telemetry was found in:"
  echo "  $DATA/telemetry"
  read -r _
  exit 1
fi

printf "Participant code (letters, digits and -): "
read -r code
case "$code" in
  ""|*[!A-Za-z0-9-]*)
    echo "Invalid participant code."
    exit 1
    ;;
esac
DEST="playtest-data/$code"
if [ -e "$DEST" ]; then
  echo "$DEST already exists; choose another code."
  exit 1
fi

mkdir -p "$DEST"
cp -R "$DATA/telemetry" "$DEST/"
[ ! -f "$DATA/profile.json" ] || cp "$DATA/profile.json" "$DEST/"
echo "Copied telemetry to $DEST."

printf "Clear this Mac for the next player? [y/N] "
read -r answer
case "$answer" in
  [Yy]*)
    rm -rf "$DATA/telemetry" "$DATA/drawings" "$DATA/checkpoints"
    rm -f "$DATA/profile.json"
    echo "Cleared."
    ;;
esac
read -r _
