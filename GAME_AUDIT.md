# Game audit

## 2026-10-31 — Home screen and level selection

Scope: the title screen, Settings, Controls, confirmations, and the house's painting
selection. Gameplay inside Levels 1–4 is still pending. Level 5 is excluded.

### Fixed

- Scene requests now reserve navigation immediately. Previously two requests in one
  frame could both succeed, opening the first scene with the second level's id.
  The incoming scene receives its id before `_ready`; a failed change restores the old id.
- Arrow keys can leave the main title action and reach the secondary buttons.
  Closing Settings, Controls, or a confirmation restores focus to its opening button.
- Reduce Motion stops both the default vista and the saved-level backdrop's mouse drift.
  Resizing no longer folds a backdrop's current drift into its resting position.
- The carried-brush HUD stays against the right margin on resize and clears DEV MODE.
- Locked and unfinished paintings show their actual availability in the interaction
  prompt. Painting selection waits until the unlock reveal finishes, including its
  initial pause before the camera moves.

### Optimizations

- The hidden legacy card selector loads its thumbnail only when opened.
- The house reuses its static painting list instead of fetching a group and building
  temporary arrays every frame.
- The title card skips mouse-drift updates for its hidden vista when level art is shown.

### Verification

37/37 focused native Godot checks passed, with no script or engine errors. Checked fresh
and saved title states, arrow-key navigation, modal pause/focus, both confirmation
cancellations, New Game reset with settings retained, brush pickup, HUD resizing,
backdrops 1–4, dev unlocks, ordinary progression locks, reveal input blocking, and the
animated scene wipe. Inspected screenshots at 1600×900 and 1920×1080.

Level paths 1–4 were checked against the catalog. Routing checks used temporary lightweight
destination scenes to verify the selected id during `_ready`, without starting gameplay.
The temporary capture/check files were removed. No full suite or `run_tests.gd` was run.

## Remaining order

1. Level 1 — Payyo: arrival, tutorials, obstacles, checkpoints, completion and return.
2. Level 2 — Piyesta: rooms, routes, scraps, assembly and return.
3. Level 3 — Dagat: both travel routes, supplies, encounters, completion and return.
4. Level 4 — Dilim: encounters, tool/supply exhaustion, checkpoint recovery and finale.

For each level, check player input and feedback alongside the underlying state, then
review the relevant code and remove unnecessary work. These steps have not been audited
as part of this home-screen pass.
