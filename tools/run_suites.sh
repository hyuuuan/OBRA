#!/bin/zsh
# Every pass/fail suite in the project, in one run.
#
# The list lived in one person's head and in a scratch file that is wiped between sessions,
# so "the suite passed" meant a different set of tests every time it was said -- and three
# pass/fail probes (run_rig_isolated, run_button_feedback_probe, run_underwater_appearance_probe)
# had never been run together with the rest at all. run_rig_isolated was failing on main when
# it was finally added.
#
#   tools/run_suites.sh            everything, to /tmp/obra_suites.log
#   tools/run_suites.sh quick      skips run_tests, which alone takes over ten minutes
#   tools/run_suites.sh only A B   just those suites ("python" for the Python tests): what a
#                                  change touches, which is what to run after most changes
#   tools/suite_watch.py [LOG]     a live bar for a run going somewhere else -- in the
#                                  background, in another terminal -- read off its log
#
# IN A TERMINAL IT SHOWS ITS OWN PROGRESS BAR. Kent: "can i have a tracker or progress bar for
# the running suites and also for the future". The bar fills by TIME, not by count -- run_tests
# alone is a quarter of the run -- with how long is left, what is running and for how long
# against its usual time, and every failure on its own line as it happens. Each suite's start
# and duration go in the log, and every duration in a history file the estimate is made from
# (OBRA_SUITE_TIMES, default ~/.cache/obra/suite_times.tsv). Not in a terminal (redirected, in
# the background) it prints a line per suite as before.
#
# ⚠ ONE GODOT AT A TIME. Every test run shares user://test_runs, and a second run started
# beside this one empties the first one's profile out from under it.
#
# ⚠ The four runners marked "window" below need a real viewport: the dummy display server
# delivers no mouse events and cannot capture the drawing canvas off a SubViewport. They are
# run WITHOUT --headless, so a window opens while they go.
#
# Diagnostics that print numbers and assert nothing (motion_probe, rig_probe,
# rig_motion_diagnostic, run_spider_probe, run_tension_probe, run_bank_probe, run_miss_probe,
# and every run_visual_*) are deliberately NOT here: a clean run from one is not evidence.

set -u
zmodload zsh/datetime
cd "$(dirname "$0")/.."
LOG=${OBRA_SUITE_LOG:-/tmp/obra_suites.log}
TIMES=${OBRA_SUITE_TIMES:-$HOME/.cache/obra/suite_times.tsv}
mkdir -p "$(dirname "$TIMES")"
PY=.venv/bin/python
[ -x "$PY" ] || PY=python3
print "started $EPOCHSECONDS" > "$LOG"

HEADLESS=(
  run_tests run_level_ready test_player_profile
  run_level1_audit run_walk_level1 run_nodraw_level1 run_level1_finish_probe
  run_ink_economy_probe run_morph_gate_probe run_book_probe run_tutorial_audit
  run_tutorial_popup_probe run_action_prompt_probe run_hint_probe run_dialogue_box_probe
  run_room_probe run_head_clear_probe
  run_locomotion_probe run_companion_pose_probe run_morph_reach_probe run_revert_probe run_placement_probe run_key_probe
  run_boarding_probe run_bag_probe run_python_lookup_probe run_unlock_reveal_probe run_import_guard_probe run_resize_probe run_backend_start_probe
  run_behaviour_audit run_roster_sweep
  run_level2_audit run_level2_scene_probe run_level2_chain_probe run_level2_finish_probe
  run_level2_systems_probe run_level2_alley_probe run_nodraw_level2 run_water_audit run_hub_audit
  run_assembly_probe run_dance_probe run_objective_probe run_tool_routes_probe
  run_play_level2 run_hud_layout_probe run_journey_probe run_backend_ownership_probe
  run_button_feedback_probe run_rig_isolated run_underwater_appearance_probe
  run_level3_audit run_nodraw_level3 run_bakunawa_probe run_level3_finish_probe
  run_swim_reach_probe run_level3_boat_probe run_level3_trouble_probe
  run_level3_play_probe run_level3_sea_probe run_opening_probe run_resume_probe
)
WINDOW=(run_click_ui run_hud_watch_level1 run_real_drawing_probe)

if [ "${1:-}" = "quick" ]; then
  HEADLESS=("${(@)HEADLESS:#run_tests}")
fi
WITH_PYTHON=1
if [ "${1:-}" = "only" ]; then
  shift
  want=("$@")
  unknown=(${want:|HEADLESS})
  unknown=(${unknown:|WINDOW})
  unknown=(${unknown:#python})
  if (( ${#unknown} )); then
    print "not a suite here: ${unknown[*]}"
    exit 2
  fi
  HEADLESS=(${HEADLESS:*want})
  WINDOW=(${WINDOW:*want})
  (( ${want[(Ie)python]} )) || WITH_PYTHON=0
fi
# What this run will make, for the bar: a run of a few suites is a bar of a few suites.
PLAN=($HEADLESS $WINDOW)
(( WITH_PYTHON )) && PLAN+=(python)
print "plan ${PLAN[*]}" >> "$LOG"

# Each suite's own output, to look for a script error in once it is done.
OUT=$(mktemp -t obra_suite)
WATCHER=""
trap '[ -n "$WATCHER" ] && kill $WATCHER 2>/dev/null; rm -f "$OUT"' EXIT

# The bar, when somebody is watching. It reads the log, so it shows exactly what is written.
if [ -t 1 ]; then
  "$PY" tools/suite_watch.py "$LOG" --times "$TIMES" &
  WATCHER=$!
else
  print "progress: tools/suite_watch.py $LOG"
fi

failed=()
# A suite's verdict and how long it took, into the log and into the history.
note_result () {  # name, exit code, seconds
  print "[exit $2 in ${3}s]" >> "$LOG"
  print "$1\t$3\t$2\t$EPOCHSECONDS" >> "$TIMES"
  if [ $2 -ne 0 ]; then failed+=("$1"); fi
  # With the bar up, it reports each result itself.
  if [ -z "$WATCHER" ]; then
    if [ $2 -ne 0 ]; then print "  FAILED  $1"; else print "  ok      $1"; fi
  fi
}

# ⚠ A SCRIPT THAT DOES NOT PARSE EXITS 0. Godot prints the error and runs nothing, and a runner
# that trusted the exit code called it passed -- seen with run_level3_trouble_probe. So a suite
# whose own output holds a GDScript "SCRIPT ERROR" or "Parse Error" has failed, whatever it
# exited with; the bar has always read it that way, and now the summary agrees with the bar.
# The output still reaches the log as it is written (tee), so the bar sees it live.
run_one () {  # name, extra godot args
  local name=$1; shift
  local began=$EPOCHSECONDS
  print "########## $name" >> "$LOG"
  print "[start $began]" >> "$LOG"
  godot "$@" --path game --script "res://tests/$name.gd" 2>&1 | tee "$OUT" >> "$LOG"
  local code=${pipestatus[1]}
  if [ $code -eq 0 ] && grep -q -E "SCRIPT ERROR|Parse Error" "$OUT"; then code=70; fi
  note_result "$name" $code $(( EPOCHSECONDS - began ))
}

for s in $HEADLESS; do run_one "$s" --headless; done
for s in $WINDOW; do run_one "$s"; done

if (( WITH_PYTHON )); then
  began=$EPOCHSECONDS
  print "########## python" >> "$LOG"
  print "[start $began]" >> "$LOG"
  "$PY" -m unittest tests.test_backend_lifecycle tests.test_preprocess_paper \
    tests.test_backend_telemetry tests.test_manifest_contract tests.test_backend_serve \
    tests.test_suite_watch >> "$LOG" 2>&1
  note_result python $? $(( EPOCHSECONDS - began ))
fi

# The bar finishes by itself once it reads the last result; let it, so its last line is drawn.
if [ -n "$WATCHER" ]; then
  wait $WATCHER 2>/dev/null
  WATCHER=""
fi
print ""
if [ ${#failed[@]} -eq 0 ]; then
  print "ALL SUITES PASSED  (${#PLAN[@]} runs)  log: $LOG"
  exit 0
fi
print "FAILED: ${failed[*]}"
print "log: $LOG"
exit 1
