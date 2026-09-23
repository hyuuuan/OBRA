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
cd "$(dirname "$0")/.."
LOG=${OBRA_SUITE_LOG:-/tmp/obra_suites.log}
: > "$LOG"

HEADLESS=(
  run_tests run_level_ready test_player_profile
  run_level1_audit run_walk_level1 run_nodraw_level1 run_level1_finish_probe
  run_ink_economy_probe run_morph_gate_probe run_book_probe run_tutorial_audit
  run_tutorial_popup_probe run_action_prompt_probe run_hint_probe run_room_probe
  run_companion_pose_probe run_morph_reach_probe run_behaviour_audit run_roster_sweep
  run_level2_audit run_level2_scene_probe run_level2_chain_probe run_level2_finish_probe
  run_level2_systems_probe run_nodraw_level2 run_water_audit run_hub_audit
  run_assembly_probe run_dance_probe run_objective_probe run_tool_routes_probe
  run_play_level2 run_hud_layout_probe run_journey_probe run_backend_ownership_probe
  run_button_feedback_probe run_rig_isolated run_underwater_appearance_probe
  run_level3_audit run_nodraw_level3 run_bakunawa_probe run_level3_finish_probe
  run_swim_reach_probe run_level3_boat_probe run_level3_trouble_probe
)
WINDOW=(run_click_ui run_hud_watch_level1 run_real_drawing_probe)

if [ "${1:-}" = "quick" ]; then
  HEADLESS=("${(@)HEADLESS:#run_tests}")
fi

failed=()
run_one () {  # name, extra godot args
  local name=$1; shift
  print "########## $name" >> "$LOG"
  godot "$@" --path game --script "res://tests/$name.gd" >> "$LOG" 2>&1
  local code=$?
  print "[exit $code]" >> "$LOG"
  if [ $code -ne 0 ]; then failed+=("$name"); print "  FAILED  $name"; else print "  ok      $name"; fi
}

for s in $HEADLESS; do run_one "$s" --headless; done
for s in $WINDOW; do run_one "$s"; done

print "########## python" >> "$LOG"
PY=.venv/bin/python
[ -x "$PY" ] || PY=python3
"$PY" -m unittest tests.test_backend_lifecycle tests.test_preprocess_paper \
  tests.test_backend_telemetry tests.test_manifest_contract >> "$LOG" 2>&1
code=$?
print "[exit $code]" >> "$LOG"
if [ $code -ne 0 ]; then failed+=("python"); print "  FAILED  python"; else print "  ok      python"; fi

print ""
if [ ${#failed[@]} -eq 0 ]; then
  print "ALL SUITES PASSED  ($(( ${#HEADLESS[@]} + ${#WINDOW[@]} + 1 )) runs)  log: $LOG"
  exit 0
fi
print "FAILED: ${failed[*]}"
print "log: $LOG"
exit 1
