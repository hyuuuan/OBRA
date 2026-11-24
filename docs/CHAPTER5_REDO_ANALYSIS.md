# How to redo the Chapter 5 analysis

For anyone on the team, or Claude Code, who needs to reproduce or re-run a number in Chapter 5. As of 24
November 2026.

There are four analyses. Three can be re-run from this folder in a minute each. The telemetry needs one
more set of files (see section 4).

| Analysis | Brief part | Input (in "Data (private)") | Script (in "Analysis") | Output |
|---|---|---|---|---|
| Post-play questionnaire | A | `GameTestersPostPlay.xlsx` | `postplay.py` | `postplay.json` (private: holds IDs), `questionnaire_scores_anonymised.csv` |
| Game-dev review (PLAY) | B | `GameDevPlay.xlsx` | `play.py` | `play.json`, `play_tables.md` |
| Cultural panel | D | `CulturalContent.xlsx` | `cultural.py` | `cultural_tables.md` |
| Telemetry | C | `drive-download-20261117T005330Z-1-001.zip` | `analysis.py`, `load.py`, `figures.py` from 17 Nov, **not in this folder**; or the repo's `tools/aggregate_telemetry.py` | `results_main.json`, `results_pilot.json`, `per_participant.csv`, Figures 28–30 |

## 0. What you need

- **Python 3.10 or later**, with the packages in `requirements.txt` (`openpyxl`, `scipy`):
  `python3 -m pip install -r requirements.txt`
- **The Google Form exports, as `.xlsx`.** In each form, go to Responses → Link to Sheets → File →
  Download → Microsoft Excel. Don't edit, sort or delete anything in them. Each script checks the column
  layout and stops if it has changed.
- Put the scripts and the data side by side in one folder on your computer, then run the commands below
  from it.

## 1. Post-play questionnaire (Part A)

```
python3 postplay.py GameTestersPostPlay.xlsx postplay.json questionnaire_scores_anonymised.csv
```

**What it does, in order**

1. **Sorts each row into a group:**
   - "test" is excluded;
   - a response before 16 Nov is **pilot**, including the one coded "R08";
   - a response on or after 16 Nov is **main study**;
   - rows listed in `EXCLUDE_ROWS` at the top of the script are excluded.
2. **Keeps the first response** when a main-study ID appears twice.
3. **Checks every value is in range** and flags straight-lining. Flagged responses are kept, and the
   flag is printed.
4. **Scores each instrument** exactly as Appendix A–F says:
   - **SUS:** odd items minus 1, 5 minus even items, sum × 2.5.
   - **UEQ-S:** response minus 4. Pragmatic = items 1–4, hedonic = items 5–8.
   - **IEQ-SF:** items 5 and 10 reverse-scored (6 − x). Involvement 1–4, Real-World Dissociation 5–8,
     Challenge 9–11.
   - **GEQ (0–4):** Positive Affect 1–5, Competence 6–10, Sensory and Imaginative Immersion 11–16.
   - **Godspeed Animacy:** the mean of the 6 items.
   - **QUESI Familiarity:** the mean of the 3 items (1–5; higher = more intuitive).
5. **Reports for each group** the mean, SD, a 95% CI (t distribution), the median, min–max, Cronbach's α
   and item means, plus age and drawing/gaming habits.

**Decisions built in.** Each was decided by the team on 20 Nov. To change one, edit the script, not the
spreadsheet.

| Decision | Where in the script |
|---|---|
| "test" row excluded (Kaina testing the form) | the `grp = "test"` line |
| "R08" (14 Nov) counted as a pilot player | the `ts < datetime(2026,11,16)` line |
| Row 8 excluded: identical to row 7 on every item, all maximum; a friend answering for fun | `EXCLUDE_ROWS` |
| A main-study ID that appears twice: keep the first (the second is 5 min later, and the means differ by ≤ 0.03) | "Duplicate codes in the main group" |
| The three respondents whose SUS answers ignore the positive/negative alternation (Q27–Q29) are **kept** | (no code; reported in the text) |
| Pilot never pooled with the main study | the two `summarise(...)` calls |

**Where the brief's numbers come from.** `postplay.json` → `main` and `pilot`:

- `SUS.mean`, `.lo` and `.hi` give Table 29's mean and CI.
- `alpha` gives the α column.
- `items` gives the item means.
- `per_respondent` lists each person, **with their ID**, so keep it private.

The CSV has the same scores under codes only (Q01–Q34 for the main study, QP01–QP10 for the pilot). It's
safe to share inside the team.

**If the form gets more responses** (for example a late one): re-run, then update every questionnaire
number in Part A. Have Claude Code do it, and check its numbers against `postplay.json`.

## 2. Game-dev review, PLAY (Part B)

```
python3 play.py GameDevPlay.xlsx play.json play_tables.md
```

**What it does**

- Reads the 50 principle ratings (M, P, N or CA) and their severities for each reviewer (R1, R2, …, in
  order of submission).
- Counts the ratings per principle, per heuristic, per category and per reviewer.
- Lists severities entered on Met items. These are not counted, because the form asks for severity on P
  and N only.
- Writes Table 32, the "principles below Met" table and every overall judgement to `play_tables.md`.

**What it does not do.** It doesn't merge the reviewers' problems into Table 33. That is a judgement:
one problem is often written under two principles (e.g. audio under II-D1 and III-C2). Table 33 was built
by hand from the comments and problem logs. The rule is in the Table 33 note: one row per distinct
problem, and the mean severity is each reviewer's highest severity for that problem, averaged over the
reviewers who raised it.

**All five reviews are in** (R5 added 24 Nov). If a rating is ever corrected, download the export again, re-run,
and follow brief Part B4.

## 3. Cultural panel (Part D)

```
python3 cultural.py CulturalContent.xlsx cultural_tables.md
```

It produces Table 34 (familiarity) and Table 35 (each item and dimension), and the overall assessments.

- A dimension score is each panelist's mean of the dimension's two items, counted "agree" at 4 or above
  and "disagree" below 3.
- "CJ (Cannot Judge)" is left out of the item's n.
- No α and no content validity index are computed (decided 17 Nov).

The open responses (D1–D6) and Table 36 were analysed by hand. They are in Part D2 and aren't produced by
the script.

## 4. Telemetry (Part C)

This one needs more than this folder.

**The input** is `drive-download-20261117T005330Z-1-001.zip`, the logs exported from every machine. Before
anything is counted, it must be cleaned exactly as Part C0 says:

- 32 laboratory folders appear twice. Use the copy inside `R08/`; keep `R1003`, which exists only at the
  top level.
- `R03-1` and `R03-2` are one person. Use `R03-2`.
- `R05` is a development machine with 246 logs. Keep only its pilot sitting, 9 Nov 18:44–19:14.
- Pilot = P01–P10 (6–12 Nov). Main study = P11–P43 (16 Nov lab).

**The scripts.** `analysis.py`, `load.py` and `figures.py` were delivered with the 17 Nov telemetry
write-up (`CHAP5_TELEMETRY.md`). They aren't in this folder, because the session that made this folder
didn't have them. Two routes:

1. **If anyone still has them:** put them in this folder, then run:
   ```
   unzip drive-download-20261117T005330Z-1-001.zip -d export
   OBRA_COHORT=lab        python3 analysis.py export . out_main
   OBRA_COHORT=individual python3 analysis.py export . out_pilot
   ```
   `figures.py` draws Figures 28–30 from the results.
2. **Otherwise, use the repo's own tool.** `tools/aggregate_telemetry.py` in `hyuuuan/OBRA` reads the
   same logs. Clean the export first, as above (or build the `OBRA_telemetry_main.zip` it expects). The
   brief says that where the two disagree on a definition, **the tool governs**. Part C0 lists every
   definition used, so a difference can be traced. `tools/chapter5/clean_telemetry.py` does the
   cleaning, and `docs/chapter5_results/telemetry_check.md` records the 24 Nov comparison and its
   commands. Claude Code can do this:

   > "Read docs/CHAPTER5_BRIEF.md Part C0, clean the telemetry export as it says, run
   > tools/aggregate_telemetry.py on the main study, and list every figure that differs from Part C."

**Checks that must pass** (they passed on 17 Nov):

- each participant's `profile.json` counts equal the counts in their logs;
- every gate decision agrees with Equation 4 and the bar in force;
- a second script reading the files directly gives the same totals.

## 5. Privacy

- **Private:** the three `.xlsx` exports, the telemetry zip and `postplay.json`. They hold names,
  e-mails, student IDs or (in one folder name) an ID number.
- **Shareable within the team:** everything else in this folder, including the anonymised CSV.
- **Never commit the private files to GitHub.** Commit the scripts only.
- **Codes for anything that leaves the team:** Q01–Q34 and QP01–QP10 (questionnaire), P01–P43
  (telemetry), R1–R5 (game devs), P1–P7 (cultural panel).
