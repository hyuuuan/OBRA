# Lola's diary

**Status: PRs 1–5 built (the book, the DIARY tab, a page in every painting, Mayon's lines). PR 6, the ending in the house, is the plan.**

Every painting hides a page of Lola's diary, each a little further into her forgetting, so that by
Mayon the player already knows why the painting is coming apart. The pages are kept in the bag
under a fourth tab, **DIARY**, and read as a book whose pages turn.

## Why

Mayon is the forgetting made into a level: the ash takes what she has lost, Lolo thins because
she is losing him, and the summit is the apo drawing the places back. A player who has only met
Lola through four bright paintings reaches it without the one fact that makes it land. The diary
says it from her side and in her hand, a page a painting, and never with a name for what she has.

## Decisions (Kent, 2026-11-01)

| | |
|---|---|
| Where the diary lives | **The bag's fourth tab**, on the same paper tabs as CREATURES, OBJECTS and SHAPES. The book replaces the pockets and cards while it is open; the bag stays the same size. |
| The book | **The book from `HUD-assets-ideas/Book-Inventory-Animation.gif`, without its ribbon tabs** ("i only want the book not the tabs because i already have an inventory tabs thing"). |
| A page, found | Kept first, then the book opens at it over the game; CONTINUE or Escape puts it down. |
| Payyo | The page already in her chest (2026-10-05), moved from a memory card into the book. |
| Piyesta | **Three pages**: one in the church, one in each alley. |
| Dagat | **The bakunawa gives it**, in place of the torn canvas corner, and only to a player who guided it home. Fought, it carries the page away; slipped past, there is none. |
| Dilim | **Her bestiary**: what lives in the woods and what to do about each, found as she enters. **The first time she meets each creature, the book opens at its page by itself**, and the apo stops saying "Lola said…". |
| Mayon | **The last page, at Lola's easel**, read after she turns. It is the most broken. |
| Mayon's lines | The apo says why everything is disappearing; **"Wait — I can fix this"** comes before the brush is raised to Lolo; **Lolo's last line is chosen by the run's dominant route**. |
| The ending | **The house replaces the real room.** "Lolo, let's go home" → the house, Lolo painted into every painting (not a ghost) → Lola: "Mahal, you look so young!" … "Who are you? Will you watch me paint?" Then the player is left in the house, Lola at her easel, for the rest of the save. |

These change two of `LEVEL_5.md`'s settled rows — the frame's return, and "no line about Lolo's
going that explains it" for the apo's line about the vanishing — at the team's request; PRs 5 and
6 rewrite those rows.

## The arc

The order she wrote them in is the order the illness goes. Each page is a little less sure of
the day, of the way home, of the name.

| | Where | What she is losing |
|---|---|---|
| Payyo | her chest | His name, some mornings. She walks the paintings with him while she still knows the way. |
| Piyesta | church · alley 1 · alley 2 | The words of a prayer she has said all her life; the way home from the plaza; lists, and the list repeated. |
| Dagat | the bakunawa | What she was searching for, and the knowing that she has lost it. |
| Dilim | her bestiary | Written for the apo: clear at first, then a creature written twice, words crossed out, a name she cannot find. |
| Mayon | her easel | Fragments. Someone she paints into all of them. The child who comes on Sundays. |

## Build order (each a PR that ships green; every new behaviour defaults to off)

| | PR | |
|---|---|---|
| 1 | `diary-book` | The art pipeline, the book, the DIARY tab, the found-page overlay, the profile's pages, Payyo's page moved in. **Built.** |
| 2 | `piyesta-diary` | Piyesta's three pages, lying where she walks: the nave, and each alley between its doors. The loose page (`DiaryPage2D`). **Built.** |
| 3 | `dagat-diary` | Dagat: the bakunawa gives the page on the light route, in place of the torn canvas corner; fought, it carries the page off in its coils. **Built.** |
| 4 | `dilim-bestiary` | Dilim's bestiary: found a few steps in, opens at each creature's page the first time she reaches it; no line says "Lola said…" any more. **Built.** |
| 5 | `mayon-lines` | Mayon: the apo's lines on why it is going white, "Wait — I can fix this", Lolo's last line by route, the last page at her easel. **Built.** |
| 6 | | The ending in the house: Lolo in every painting, Lola and the empty easel. |

## Where it lives

| | |
|---|---|
| The pages | `game/config/diary.json` — `id`, `level_id`, `date`, `found`, `pages` (a string, or `{text, anchor}` for a page a level opens the book at). `[s]…[/s]` is a line she crossed out. |
| What is found | `PlayerProfile.record_diary_page` / `has_diary_page` / `diary_pages` (`diary_pages` in the save; additive, no schema bump) |
| Reading them | `Diary` (static: every entry, and the ones found, in the order she wrote them) |
| The book | `DiaryBook` — the turn at Motion's pixel rate, one frame a tick; a click on the left page goes back, on the right page on |
| The bag's tab | `InventoryScreen` (`DIARY_TAB`, `_build_diary`, `_refresh_diary`) |
| A page, found | `LevelBase.find_diary_page(id)` → `DiaryOverlay` (layer 68, ahead of the memory card in the Escape queue) |
| A page a beat opens at | LevelBase `_diary_page_on_arrival(obstacle_id)` (off by default; Dilim's `BESTIARY_PAGES`) → `read_diary_at(entry, anchor, note)` before the beat's arrival lines. Read, not found: a page this save does not hold is not shown |
| A page lying in a level | `DiaryPage2D` (placed by the level, e.g. `level_2.gd` `DIARY_PAGES`); LevelBase lays them out (`_lay_out_diary_pages`: a page already found is not there) and finds one she stands over (`_tend_diary_pages`, from her body's anchor) |
| The art | `tools/build_diary_book.py` → `game/assets/hud/diary_book.png` (8 frames of 134 × 112; frame 7 is the book at rest) and `diary_page.png` (the loose page, a placeholder) |
| Tests | `run_diary_probe` · `run_walk_level1` (`_her_chest_opens`) · `run_play_level2` (Piyesta's three, found on the way) · `run_bakunawa_probe` (Dagat's, given on the light route and carried off by the fight) · `run_level5_act_one_probe` (why it goes white) · `run_level5_act_two_probe` ("I can fix this", Lolo's last line by route) · `run_level5_summit_probe` (her last page at the easel) · `tests.test_build_diary_book` |

## Rules

- **No page names a drawable class**, in English or Filipino: the diary is read by a player
  standing at the obstacle it is about. `run_diary_probe` checks every page against the fifty and
  a Filipino list (not *bangka*, the story's word for Lolo's boat, and not *araw*, which is "day"
  far more than "sun").
- **Every page fits its page.** The book does not scroll; the probe lays each page out in the
  real font and fails the one that runs over (432 px of writing a page).
- **Every entry is given by some level's script** — a page nobody can find is a page nobody wrote.
- **An entry starts on a left page.** One with an odd number of pages leaves its right page blank.

## Traps

- ⚠ **A `RichTextLabel` outside the tree measures nothing.** `get_content_height()` said a page
  three times too long fitted; the scratch label is measured in the tree.
- ⚠ **Do not measure the bag's lining at build time.** Before the first layout the big card's
  wrapped labels stand one word to a line, and the cards measured 1709 tall — the bag came out
  twice the height of the screen. The book's height is a constant; its width is taken from the
  laid-out cards when the tab opens.
- ⚠ **A loose page is found by distance, not by an `Area2D`.** Dilim's satchel things look for her
  hurtbox, and only Dilim has one (it is her health): in Piyesta a page waiting for a hurtbox was
  walked over and never found.
- ⚠ **An unattended run puts the book down by itself** (`DiaryOverlay.AUTO_HOLD`, half a second),
  because the dialogue box is set to auto-dismiss: a page opens over a paused game, and every probe
  that walked over one, or into a Dilim creature, stopped there with nobody to press CONTINUE. It
  hides the same pause bugs auto-dismiss does -- turn it off when chasing one.
- ⚠ **The ribbons are keyed by colour, not cropped by row.** The page in flight rises over the
  cover's top edge while the ribbons are still behind it.
