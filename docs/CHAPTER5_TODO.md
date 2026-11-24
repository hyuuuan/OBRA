# OBRA: Team To-Do (Chapter 5 and the manuscript)

*Updated 24 November 2026 (fifth game-dev reviewer added). Write a name in each Owner and tick a box when the task is finished.*

**Team:** Rusk · Erika · Kent · Kaina

## What's in this folder

| Where | What it is | Who it's for |
|---|---|---|
| **00 START HERE – Team To-Do** | This list | Everyone |
| **For Claude Code / 01_OBRA_CHAPTER5_BRIEF.md** | Everything for Chapter 5 in one file. It holds the results, the text to paste, the tables, the Chapter 4 changes, the bugs to fix, and every open question (marked `[[TEAM: …]]`) | Whoever writes Chapter 5, and Claude Code |
| **For Claude Code / 02_MANUSCRIPT_REVISIONS.md** | Changes to Chapters 1–4 and the appendices from before the playtest (31 Oct): bread for mushroom, counts, appendix numbering, the appeal items | Whoever edits Chapters 1–4 |
| **For Claude Code / 03_HOW_TO_REDO_THE_ANALYSIS.md** | How to re-run every analysis, what you need, and every cleaning decision built into the scripts | Whoever re-runs a number |
| **Analysis /** | The scripts (`postplay.py`, `play.py`, `cultural.py`, `requirements.txt`) and their outputs: `play_tables.md`, `play.json`, `cultural_tables.md`, and `questionnaire_scores_anonymised.csv` (scores by code, no names) | Claude Code, or anyone checking a number |
| **Data (private) /** | The three Google Form exports, the telemetry logs, and `postplay.json`. **They contain names, e-mails and student IDs.** Don't share them outside the team, and never commit them to GitHub | Whoever re-runs the analysis |

**How to use the brief with Claude Code.** Put the brief in the repo as `docs/CHAPTER5_BRIEF.md` (Part F, task F13 says how), then tell it, for example: *"Read docs/CHAPTER5_BRIEF.md, section 0 first. Then write §5.2.7 from Part A1 into …"*. The brief tells Claude Code to keep every `[[TEAM]]` marker, to never change a number by hand, and to never commit the private data.

**Order:** Phase 1 → 2 → 3 → 4. Phase 5 runs alongside. Chapter 5 text can be pasted now. Only the bits marked `[[TEAM]]` wait on Phase 2.

---

## Done already (20 Nov)

- [x] Exported the post-play questionnaire, the game-dev evaluation and the cultural panel responses
- [x] **Analysed the post-play questionnaire.** SUS 67.7, UEQ-S 1.57 / 1.82, IEQ-SF 3.46, GEQ 3.46 / 3.12 / 3.43, Godspeed 3.89 and QUESI 4.10, with 95% CIs and Cronbach's α. Brief Part A
- [x] **Analysed the game-dev (PLAY) review** of all 5 reviewers (the fifth added 24 Nov): 79% Met, 25 problems listed. Brief Part B
- [x] Re-checked the cultural panel numbers against the form. All match (Part D)
- [x] Telemetry analysis (17 Nov). Carried into the brief as Part C
- [x] Counted the responses:
  - main study: 34 (one ID answered twice, so the first answer is kept);
  - pilot: 10 (nine named, plus "R08");
  - excluded: Kaina's "test" row and the friend's duplicate all-maximum response.
- [x] Settled:
  - The questionnaire and telemetry can't be linked person by person (IDs vs session codes), so the results are reported as a group.
  - The questionnaire was answered 3–47 hours after play; this is disclosed.
  - The QUESI wording on the form is right and Appendix F is wrong. Permission came from Prof. Hurtienne on 11 Nov.
  - The deliberate-rejection question was dropped; §4.2.1B is reworded to say why.
  - Paper consent forms were signed by everyone.
- [x] Drafted §5.3.8 points (1)–(6) and all the §5.3.7 limitation bullets

---

## Phase 1: Data housekeeping

- [ ] **Keep the files in "Data (private)" read-only.** Work on copies only. Owner: ___
- [ ] **Remove names, e-mails and student IDs** from any copy that leaves the team (appendices, the adviser's copy). Use codes Q01–Q34, P01–P43, R1–R5 and P1–P7. Owner: ___

## Phase 2: Questions only the team can answer

Each one is a `[[TEAM: …]]` marker in the brief. Section 2 of the brief lists them all.

**Telemetry and the pilot**
- [ ] **What changed in the game after the pilot?** List the fixes and new features for the §4.1.2 pilot paragraph (brief C1). Owner: ___
  - Five events only the lab build logs: collectible, drawing_reused, form_ability_used, locked_card_hint and restriction_violation. Which were new features, and which only new logging?
  - Any crash you fixed. Three pilot logs on Windows stop in Dilim, and one Mac shows 14 launches of under 15 s.
  - Was the ~30-minute lab limit a response to the pilot? If not, delete that sentence.
- [ ] **Confirm all 43 telemetry folders are consented participants** and none is a team member. Check `R05` especially (a dev machine). Owner: ___
- [ ] **Write down the 16 Nov lab protocol:** the room, the PC specs, the time per group and the build version. Owner: ___
- [ ] **Was the M1 Max reference machine one of the pilot Macs** (A, B or C)? Owner: ___
- [ ] **Run `tools/aggregate_telemetry.py`** on the main-study logs and compare with Part C. If they disagree, the tool governs. Owner: ___
- [ ] **Table 37 statuses:** decide the wording for response time ("partly met"?) and frame rate. Owner: ___

**Questionnaire**
- [ ] **The kept pilot response is identical to the friend's on all 54 items.** If both were the friend, drop it too (the pilot becomes 9) and tell Claude Code to add it to `EXCLUDE_ROWS`. Owner: ___
- [ ] **Check that the 9 Nov e-mail to Prof. Hurtienne mentioned changing the wording to "drawing"**, so his "yes" covers the adaptation. Owner: ___
- [ ] *(Optional)* Find the **Familiarity subscale's own α** in Naumann & Hurtienne (2010). The brief currently uses the 0.78–0.92 range. Owner: ___

**Game-dev review**
- [x] **Collected the fifth reviewer's form** (23 Nov) and added it to Part B (24 Nov)
- [ ] **R5's I-A2:** the comment says "I rate this as an N" but the form records P, and P is used. Confirm, or correct the export and re-run `play.py`. Owner: ___
- [ ] **Decide the response to each of the 25 problems** in Table 33 (corrected / deferred / declined, with a reason). Eight of them are design questions R5 raised: the story opening, challenge depth, recognition accuracy, an enemy health bar in Dilim, Dagat's length, light drawings in Dilim, rebinding and controllers, and save slots. Owner: ___
- [ ] **Ask each reviewer whether they may be named** in the thesis, or should be described by role and years. Owner: ___
- [ ] **Confirm which build R4 played** (review dated 17 Nov). Owner: ___
- [ ] **§4.2.1C promises seven open questions on the drawing mechanic.** The form didn't have them. Delete the sentence, or add a limitation. Owner: ___

**Cultural panel**
- [ ] **Confirm the five "corrected" cultural fixes are in the build.** Any that isn't becomes "deferred". Owner: ___
  - [ ] Ifugao guardian at the bale in Payyo
  - [ ] Fiesta food in the Piyesta plaza
  - [ ] A line or two of each region's own language
  - [ ] The apo does the mano to Lola at the ending
  - [ ] Lolo tells the legend of Daragang Magayon, and the Cagsawa ruin is named

**Whole chapter**
- [ ] **Check the table numbers against the Chapter 5 template.** The brief uses Table 29 (questionnaire), Tables 32–33 (game dev) and Tables 34–36 (panel), with the old 36–38 becoming 37–39. Owner: ___

## Phase 3: Paste Chapter 5

The text to paste is in the brief. Paste it as it is and fill the `[[TEAM]]` bits from Phase 2.

- [ ] **§5.2.2C Live play** and Table 23 (Part C2). Owner: ___
- [ ] **§5.2.5 Recognition speed**, Table 27 and Figure 28 (Part C3). Owner: ___
- [ ] **§5.2.6 Gameplay performance**, Table 28 and Figure 29 (Part C4). Owner: ___
- [ ] **§5.2.7 Participants and user experience**, Table 29 with its pilot rows (Part A1). Owner: ___
- [ ] **§5.2.8 Gameplay effectiveness**, Tables 30–31 and Figure 30 (Part C6). Owner: ___
- [ ] **§5.2.9 Expert design review**, Tables 32–33 (Part B1). All five reviews are in. Owner: ___
- [ ] **§5.2.10 Cultural content** and Tables 34–36 (Part D2). Owner: ___
- [ ] **Table 37 rows** (Parts A2 and C7) and the **Table 39 objective-5 status** (Part C7). Owner: ___
- [ ] **§5.3.7 Limitations:** the bullets from Parts A3, B2, C8 and D4. Owner: ___
- [ ] **§5.3.8 Discussion:** points (1) and (4) from Part C9, (2) and (3) from A4, (5) from B3 and (6) from D3. Read them together once, then paste. Owner: ___
- [ ] **Figures 28–30:** the PNGs came with the 17 Nov telemetry write-up (`fig28_…`, `fig29_…`, `fig30_…`). Find them, or ask for them to be regenerated. Owner: ___
- [ ] **Renumber the tables** and fix the cross-references in §5.3.6. Owner: ___

## Phase 4: Chapters 1–4, the appendices and the finish

**From the evaluation (brief Parts C1, D1 and E)**
- [ ] **§4.1.2:** the pilot paragraph; the cultural panel's wording, eligibility and administration. Owner: ___
- [ ] **§4.2.1B:** the deliberate-rejection paragraph ("Two measures…" plus the new sentence). Owner: ___
- [ ] **§4.2.1C:** the open-questions sentence (see Phase 2). Owner: ___
- [ ] **§4.2.1D:** replace the content-validity paragraph with agreement counts. Owner: ___
- [ ] **§4.3.4 and §4.10.3:** "immediately after" becomes "online after the session". Owner: ___
- [ ] **§4.10.3:** recognition speed; Table 14's frame-rate and memory rows; live-play recall; Table 13; QUESI read against the midpoint. Owner: ___
- [ ] **Appendix F (QUESI):** fix items 2 and 3 to the form's wording, and replace the "pending" permission text with Prof. Hurtienne's 11 Nov permission. **Don't paste his e-mail** into Appendix H, because it is marked confidential. Owner: ___
- [ ] **Appendix H:** describe the cultural panel as it was actually constituted. Owner: ___

**"Must" fixes from 02_MANUSCRIPT_REVISIONS.md**
- [ ] **Abstract, §3.2.7, Table 1, §4.2.8 and the Appendix:** bread replaces mushroom; 49 of 50 classes; 119 abilities; 86 Direct. Owner: ___
- [ ] **Participant count:** use one number everywhere (33 main study + 10 pilot, with evaluators counted separately). Owner: ___
- [ ] **Appendix numbering:** make the table of contents, page headings and in-text references agree (C vs D). Owner: ___
- [ ] **§1.4:** "co-located Python recognition service", not "within the Godot engine". Owner: ___
- [ ] **§4.2.3 and §4.2.4, Tables 4–5:** the total becomes 6,960,566; add a bread row with 120,570 drawings. Owner: ___
- [ ] **§4.2.7:** "thin relative to their 1111-pixel frame". Owner: ___
- [ ] **§4.5.4.5:** delete the "mutually exclusive by construction" sentence. Owner: ___
- [ ] **§4.5.4.6:** "Bahay Kubo" → "Payyo", "Pista" → "Piyesta" (also in §2.6 and Appendix H). Owner: ___
- [ ] **Figure 15:** redraw it so the endings are computed and logged, and the summit is the ending. Owner: ___
- [ ] **§4.7.5:** "20 creatures, 3 primitives, 27 objects". Owner: ___
- [ ] **Appeal items** (TU-Berlin under both protocols, the as-built design, audio as future work): apply these **only once the panel answers**. Owner: ___

**Finish**
- [ ] **Abstract and Chapter 6:** use the headline paragraph in brief Part E. Owner: ___
- [ ] **§2.6:** add a citation for "reviews of the field consistently find…". Owner: ___
- [ ] **One full read-through** for consistency: numbers, table and figure numbers, level names. Owner: ___
- [ ] **Send the draft to our adviser** and log the feedback. Owner: ___
- [ ] **Apply the feedback.** Owner: ___
- [ ] **Book the final defense.** Owner: ___
- [ ] **Build the defense slides** and rehearse twice. Owner: ___

## Phase 5: Alongside (any time)

**Game fixes the reviewers found** (brief Part F; reproduce each on `main` first)
- [ ] **F1 Piyesta:** the player was put at the birds instead of the dancers (severity 4). Owner: ___
- [ ] **F2:** one way to win couldn't be completed although its conditions were met (severity 3). Ask R1 which level. Owner: ___
- [ ] **F3 Payyo:** the haystack minimap draws over the background (severity 2). Owner: ___
- [ ] **F4:** a settings label loses its "n" on hover. Owner: ___
- [ ] **F5:** the game logo is missing from the build. Owner: ___
- [ ] **F15 Payyo:** drawings placed inside the haystack disappear or turn up near the exit; the hint misleads (severity 2). Owner: ___
- [ ] **F16:** climbing drawn stairs with W makes the player float (severity 2). Owner: ___
- [ ] **F17 Payyo:** swimming animal forms can't jump on land (severity 1). Owner: ___

**Game fixes the logs point to** (optional, before any further sessions)
- [ ] **F6:** profile the spawn hitch (~180 ms of lost frames after each accepted drawing). Owner: ___
- [ ] **F7–F11:** telemetry logging fixes (platform and build, participant code, frame rate to first frame, `static_mb`, supervised play). Owner: ___
- [ ] **F12:** play through Dagat's artist route. All six who didn't finish Dagat were on it. Owner: ___

**Repo**
- [ ] **F13:** commit the brief and the scripts (not the data) on a branch such as `chapter5-brief`. Owner: ___
- [ ] **F14:** update `PAPER_STATUS.md`. The user study is done. Owner: ___

**Paper**
- [ ] **Shortlist Q1 2027 conferences:** non-predatory and published, online or in Asia, visa-free for Filipinos if possible. Check deadlines now, since many fall in Dec–Jan. Owner: ___
- [ ] **Choose the venue and the track** (full paper, short paper or demo). Owner: ___
- [ ] **Draft the paper from Chapter 5.** Owner: ___

**People**
- [ ] **Hand out the playtester prizes.** Owner: ___
- [ ] **Thank** the seven cultural panelists, the game-dev reviewers and Prof. Hurtienne. Owner: ___
- [ ] **Reply to panelist P4**, who asked whether we'll share the finished work. Owner: ___
