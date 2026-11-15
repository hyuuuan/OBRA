#!/bin/zsh
# A listening MP3 of a WAV, for Kent (Claude cannot hear: every render goes to him as an MP3).
# Uses the ffmpeg already on this Mac (Homebrew); run fenced like everything else.
#     tools/audio_lab/mp3.sh build/listen/x_listen.wav build/listen/obra-x.mp3 "Title"
set -e
HERE=${0:A:h}
FFMPEG=${FFMPEG:-/opt/homebrew/bin/ffmpeg}
$HERE/sb.sh $FFMPEG -hide_banner -loglevel error -y -i "$1" -ar 44100 -ac 2 -c:a libmp3lame \
  -b:a 192k -metadata title="${3:-O.B.R.A.}" "$2"
echo "wrote $2"
