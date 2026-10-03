#!/bin/sh
# Double-click this on a Mac: it opens Terminal and runs play.sh, which sets the game up
# and starts it. See play.sh.
exec "$(dirname "$0")/play.sh" "$@"
