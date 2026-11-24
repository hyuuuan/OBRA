# OBRA, Chapter 5: the full brief for Claude Code

As of 2026-11-20. One file with everything Chapter 5 needs from the evaluation, and what to do with it.

| Part | What it covers | Source | State |
|---|---|---|---|
| **A** | Post-play questionnaire: SUS, UEQ-S, IEQ-SF, GEQ (3 components), Godspeed Animacy, QUESI | `GameTestersPostPlay.xlsx` (47 rows) | **New.** Analysed 2026-11-20 |
| **B** | Expert design review (PLAY), five game developers | `GameDevPlay.xlsx` (5 rows, final) | **New.** Analysed 2026-11-20; fifth reviewer added 2026-11-24 |
| **C** | Playtest telemetry: live recognition, speed, performance, effectiveness | telemetry zip, 43 participants | From `CHAP5_TELEMETRY.md` (17 Nov), updated with what Parts A and B settle |
| **D** | Cultural content panel, seven teachers | `CulturalContent.xlsx` (7 rows) | From `CHAP5_CULTURAL_PANEL.md` (17 Nov). The workbook was re-checked and matches |
| **E** | Changes elsewhere in the manuscript (Abstract, Ch 1, Ch 4, Ch 6, appendices) | All of the above | Consolidated |
| **F** | Code and repo tasks the evaluation turned up | Reviewers' problem logs, telemetry | New |
| **G** | How to reproduce every number | Scripts sent with this file | New |

Every figure here was computed from the workbooks or the logs. Nothing is estimated. Anything only the
team can settle is marked `[[TEAM: …]]`. Section 2 lists all of them in one place.

---

## 0. For Claude Code: read this first

**What this file is.** These are results and paste-ready manuscript text for Chapter 5 of the OBRA thesis,
plus the Chapter 4 and front-matter changes they force. It is *not* a design doc for the game. The
game's own rules (`AGENTS.md`, `LEVEL_*.md`, the project instructions) still govern any code you touch.

**What you may be asked to do with it.**

1. **Write manuscript text.** When Kaina asks for a section, use the paste-ready text in the matching
   part, verbatim, and fill nothing marked `[[TEAM]]` yourself; leave it marked. Do not round, re-derive
   or "improve" a number. If a number looks wrong, re-run the script in Part G and report the
   difference; don't edit the number silently.
2. **Keep the docs in the repo current.** Commit this file as `docs/CHAPTER5_BRIEF.md` on its own
   branch, and update `PAPER_STATUS.md` (its "User study: not yet run" row is out of date; see Part E).
3. **Fix what the reviewers found.** Part F lists bugs from the expert review. Reproduce each one on
   `main` before you change anything: the reviews were made on builds from 11 to 17 November, and some
   may already be fixed.
4. **Reproduce the numbers.** Part G gives the scripts and commands.

**Rules that apply here.**

- **Never commit the raw response workbooks or the telemetry export.** They hold names, e-mail
  addresses and student ID numbers. Commit scripts and aggregate results only. This file uses codes
  throughout: Q01–Q34 for main-study questionnaire respondents, R1–R4 for reviewers, P1–P7 for panelists
  and P01–P43 for telemetry participants.
- The repo's git rules hold. Use a branch per PR off `main` with a short kebab-case name (e.g.
  `chapter5-brief`). Subjects are plain-English sentences, with no `feat:` or `fix:` prefixes. The
  commit body says why. Merge once the suites the change touches pass.
- **The thesis manuscript governs** where it and the SRS disagree. Where this brief and the manuscript
  disagree on a *result*, this brief is newer. Where they disagree on a *method*, flag it to Kaina and
  don't pick one.

---

## 1. Headline results

| Evaluation | Headline |
|---|---|
| Live recognition (main study, N = 33) | 770 drawings; 67.9% accepted, 30.6% declined at the floor, 1.4% by the level's bar |
| Response time | Median 333 ms (target ≤ 250, **not met**); 95th percentile 438 ms (target ≤ 500, **met**). Recognition itself took 84 ms; the delay comes after the response |
| Frame rate | Held during the request (766 of 770 windows ≥ 55 fps); about 11 frames were lost just after each accepted drawing |
| Completion | Payyo 100%, Piyesta 91%, Dagat 79%, Dilim 28%, Mayon 33%. Every non-completion is a session that ended. All 10 untimed pilot players finished the game |
| **Usability (SUS, n = 34)** | **67.7** (95% CI 63.2–72.2): at the benchmark of 68, not above it |
| **UX (UEQ-S)** | Pragmatic **1.57** (1.19–1.94), hedonic **1.82** (1.54–2.10). Both positive (> 0.8) |
| **Immersion (IEQ-SF)** | **3.46** of 5. Involvement high (4.38), real-world dissociation at the midpoint (3.04), challenge just below it (2.80) |
| **GEQ (0–4)** | Positive affect **3.46**, competence **3.12**, sensory and imaginative immersion **3.43** |
| **Believability (Godspeed Animacy)** | **3.89** of 5 |
| **Ability-expectation (QUESI)** | **4.10** of 5 |
| **Expert review (PLAY, 5 reviewers)** | **79%** of 250 ratings Met, 1 Not met (audio feedback). 25 distinct problems. The most severe: a reported Piyesta spawn bug (severity 4), a way to win that couldn't be finished, and a rushed story opening (3). Raised by three reviewers: a challenge that doesn't deepen, and players guessing what to draw. R5 would first fix recognition accuracy |
| Cultural panel (7 teachers) | 4 "use as is", 3 "use after minor changes", none worse. Aswang the one divided item |

---

## 2. Decisions only the team can make (all of them, in one list)

**From the questionnaire (Part A): settled by Kaina on 20 Nov**

1. **34 respondents for 33 sessions.** The team says the questionnaire asking for ID numbers, while the
   logs use session codes, was its mistake. The "test" row is not among the 34: it is dated 12 Nov and
   was already excluded. So the 34 stand, the text discloses one more respondent than there are logged
   sessions, and the questionnaire is reported as a group. *(Settled.)*
2. **Timing.** The responses came 3 to 47 hours after the session, not immediately. Confirmed; the text
   discloses it, and §4.3.4 and §4.10.3 are reworded (Part E). *(Settled.)*
3. **The QUESI items.** The Google Form's wording is the published Perceived Familiarity wording, with
   the referent changed to "drawing" / "my drawing's ability", and the authors' permission was obtained.
   Appendix F is the one that's wrong: correct it to the form's wording (Part E). Only the Familiarity
   subscale was used. Its score is the mean of its items, 1 to 5, higher meaning more intuitive use, and
   with the subscale on its own it is read against the midpoint, like the IEQ-SF and GEQ (§4.10.3 is
   reworded in Part E). Permission: Prof. Dr. Jörn Hurtienne, by e-mail on 11 Nov 2026, in reply to
   Kaina's request of 9 Nov (Part E). Source α: 0.78–0.92 across the QUESI's subscales (Naumann &
   Hurtienne, 2010). `[[TEAM: if the paper gives the Familiarity subscale its own α, use that value
   instead of the range.]]`
   *Note for the team:* the permission came on 11 Nov. The main study (16 Nov) is well after it, but the
   pilot's questionnaire responses of 6–11 Nov were collected before or on the day of the reply. This
   doesn't need to go in the thesis. Just don't write that permission was in hand "before data
   collection began".
4. **The deliberate-rejection question.** It was left out, and the thesis can do without it. The
   question existed to catch players who might draw badly on purpose to steer their ending. As built,
   the endings are computed only for the analysis and never shown, so there is nothing to gain by
   drawing badly. §4.2.1B is reworded to say so (Part E), and no limitation is needed. *(Settled.)*
5. **The pilot questionnaire.** It is reported in its own rows and never pooled. Every participant
   signed a paper consent form before playing. *(Settled.)*
6. **Stray rows.** "Test" is excluded: it was Kaina testing the form and taking a screenshot. "R08"
   (14 Nov) is a pilot player and is included. That made 11 pilot responses for 10 players, so, on
   Kaina's instruction, the later of the two identical all-maximum responses (11 Nov, a friend answering
   for fun) is excluded. The pilot is 10 responses for 10 players. *(Settled.)*
   *Note for the team:* the response that was kept is identical to the excluded one on all 54 items. If
   both came from the same friend, drop it too, and say so. The pilot would then be 9.

**From the expert review (Part B)**

7. **The disposition of each problem** in Table 33 (corrected / deferred / declined, with a reason).
   Proposed dispositions are given; confirm each one, and after any fix, confirm it is in the build.
8. **Naming the reviewers.** The form recorded names, but no acknowledgement preference. Ask each
   reviewer whether they may be named, or describe them by role and years.
9. **The seven open questions on the drawing mechanic** that §4.2.1C promises were not on the form
   (nor in Appendix G). Delete the sentence or disclose the omission.
10. **The fifth reviewer (R5).** *(Settled 24 Nov.)* Added from the final export; Part B is rewritten for
    five. One check: R5's comment on I-A2 says "I rate this as an N", but the form records P, and P is
    used. `[[TEAM: confirm, or correct the export and re-run.]]`
11. **R4's review** (completed 17 Nov) rated all fifty principles Met with no comments. Report it as it
    is (the text does). Also confirm which build R4 played.

**Carried over from the telemetry (Part C)**

12. What changed in the build after the pilot (the §4.1.2 pilot paragraph).
13. That all 43 telemetry folders are consented participants, and none a team member (folder `R05` is a
    development machine).
14. The laboratory protocol on 16 Nov: the place, the PCs' specification, and the time given.
15. Whether the reference machine (M1 Max) was one of the pilot Macs.
16. The wording of the two Table 37 statuses ("partly met").
17. Whether to run `tools/aggregate_telemetry.py` on the main-study logs and reconcile it with these
    figures (it governs if they disagree).

**Carried over from the cultural panel (Part D)**

18. Before submission, confirm that each change Table 36 calls "corrected" is in the build.
19. Someone should reply to panelist P4, who asked whether the finished work will be shared.

**Manuscript-wide**

20. **Table numbering.** Part D adds a Table 36 and renumbers 36–38 → 37–39. Parts A and B use Table 29
    (questionnaire) and Tables 32–33 (expert review). Check these against the placeholders in your
    Chapter 5 template, then do one numbering pass at the end.

---
# Part A. The post-play questionnaire

Fills **§5.2.7** (participants and user experience), **Table 29**, the user-experience rows of **Table
37**, and points (2) and (3) of **§5.3.8**.

## A0. The data and the decisions taken

The workbook has 47 rows. They were sorted like this:

| Rows | Count | Decision |
|---|---|---|
| Responses dated 16–18 Nov, with ID numbers | 35 rows, 34 distinct IDs | **Main study.** One ID submitted twice, 5 minutes apart on 18 Nov; the **first** response is kept. Keeping the later one moves no scale mean by more than 0.03 |
| Responses dated 6–14 Nov: nine with names, plus one coded "R08" (14 Nov), a pilot player | 10 | **Pilot.** Reported in their own rows, never pooled |
| A response dated 11 Nov, identical on all 54 items to an earlier one and at the maximum throughout | 1 | Excluded on the team's instruction: a friend answering for fun. The earlier of the two identical responses is kept |
| A row coded "test" (12 Nov), age 9, minimum answers throughout | 1 | Excluded: the team testing the form |

**Checks on the main study (n = 34).**

- No blank item and no value outside its scale.
- Consent was confirmed on the form by all 34. Every participant, pilot included, also signed a paper
  consent form before playing.
- Three respondents (Q27, Q28, Q29) agreed with the negative SUS statements at least as much as with the
  positive ones, which suggests they did not read the alternation. Their responses are **kept**.
  Without them the SUS mean is 69.8 (95% CI 65.7–74.0), so the conclusion is unchanged.
- One of them (Q27) gave 3 on all ten SUS items.

**Scoring** (Appendix A–F as printed):

- **SUS:** odd items score the response minus 1, even items 5 minus the response; the sum is × 2.5.
- **UEQ-S:** the response minus 4 (giving −3 to +3). Pragmatic is the mean of items 1–4, hedonic the mean
  of items 5–8. No combined score.
- **IEQ-SF:** items 5 and 10 reverse-scored (6 − response). Involvement is items 1–4, Real-World
  Dissociation 5–8, Challenge 9–11.
- **GEQ (0–4):** Positive Affect is items 1–5, Competence 6–10, Sensory and Imaginative Immersion 11–16.
  No total.
- **Godspeed Animacy:** the mean of the six items.
- **QUESI:** the mean of the three items, in the published Perceived Familiarity wording with the
  referent changed to the drawing's ability, as adapted with the authors' permission (Appendix F).

The 95% confidence intervals use the t distribution. No significance tests are run, as §4.10.3
specifies.

**Linking to telemetry is not possible.** The questionnaire asked for an ID number, while the lab's
telemetry folders are named by session codes. Only one folder name matches an ID. The questionnaire is
therefore analysed as a group, and no per-player cross-tabulation with the logs is reported.

## A1. §5.2.7 Participants and User Experience: text to paste

This replaces the participants paragraph drafted in `CHAP5_TELEMETRY.md` §5 and the questionnaire
placeholder.

> Thirty-three participants took part in the main evaluation, a laboratory session on 16 November 2026,
> in two groups of 18 and 15. Sessions lasted a median of 32 minutes (9 to 38) and ended while a level was
> still in progress for 24 of the 33 (Section 5.2.8). `[[TEAM: recruitment, place, stratification and
> build.]]` Thirty-four main-study participants completed the post-session questionnaire. They were 17 to
> 20 years old (median 18; one did not give an age). Seventeen play video games but do not draw, 11 do
> both but play more often, 5 do both about equally and 1 draws more often; none reported doing neither.
> The questionnaire identified participants by ID number and the telemetry by session code, so the two
> could not be linked participant by participant. There is one more respondent than there are logged
> sessions, and the questionnaire results are reported for the 34 as a group. The questionnaire was
> completed online after the session rather than immediately, between three hours and two days after
> play: 6 responses on 16 November, 10 on 17 November and 18 on 18 November.
>
> Ten further participants took part in the pilot (Section 4.1.2) between 6 and 12 November, on their own
> or the researchers' computers and without a time limit. They played for a median of 44 minutes (29 to
> 80), and all ten completed the game. Their telemetry and questionnaire responses are reported
> separately and are not pooled with the main evaluation.
>
> Table 29 gives the scores. Each is reported as a mean with its 95% confidence interval and read against
> the reference stated in Section 4.10.3.
>
> *Usability.* The mean SUS score was 67.7 (95% CI 63.2 to 72.2; median 66.3; range 40 to 90). This is at
> the conventional above-average threshold of 68, not above it: the interval spans the threshold, and 16
> of the 34 participants scored above 68. At the item level, agreement with the positive statements was
> consistent (means 3.8 to 4.1 of 5), and the highest was that the functions were well integrated (4.1).
> The negative statements drew means of 2.4 to 2.7, between "disagree" and neutral. That the system was
> cumbersome (2.65) and unnecessarily complex (2.59) were the least firmly rejected.
>
> *Pragmatic and hedonic quality.* Both UEQ-S scales were positive, above the 0.8 boundary of the UEQ
> Handbook, with confidence intervals wholly above it. Pragmatic quality was 1.57 (1.19 to 1.94) and
> hedonic quality 1.82 (1.54 to 2.10). No participant's score was negative on either scale; 10 of the 34
> were neutral on pragmatic quality and 3 on hedonic quality. The game was rated most strongly as
> interesting (2.38 on the −3 to +3 range), and least strongly as clear (1.47) and leading-edge (1.35).
>
> *Immersion.* The IEQ-SF mean was 3.46 of 5 (3.33 to 3.60), above the scale midpoint. Its three subfactors
> differed. Involvement was high (4.38; 4.20 to 4.57), with enjoyment the highest-rated item of the
> questionnaire (4.68). Real-world dissociation sat at the midpoint (3.04; 2.79 to 3.28): participants
> remained aware of the real world (3.85 before reverse scoring), which a shared laboratory and a
> half-hour session may explain. Challenge was just below the midpoint (2.80; 2.58 to 3.02), and the
> participants agreed more that the game was easy (3.85) than that it was challenging (3.24).
>
> *Game experience.* On the GEQ's 0 to 4 scale, positive affect was 3.46 (3.27 to 3.66), sensory and
> imaginative immersion 3.43 (3.20 to 3.66) and competence 3.12 (2.86 to 3.39), all between "fairly" and
> "extremely". Competence was the lowest of the three. Its lowest item was being fast at reaching the
> game's targets (2.94), consistent with sessions in which most participants were still inside a level
> when time ran out (Section 5.2.8).
>
> *Believability of the animated drawing.* The Godspeed Animacy mean was 3.89 of 5 (3.61 to 4.17), above
> the midpoint. The drawing was rated more interactive (4.15) and responsive (4.00) than lifelike (3.68)
> or organic (3.74).
>
> *Ability-expectation.* The QUESI Perceived Familiarity mean was 4.10 of 5 (3.84 to 4.35). Participants
> agreed most that they could use their drawing's ability in a way that seemed familiar (4.29), and least
> that it was always clear what they had to do to use it (3.88). On the QUESI's 1 to 5 scale, where a
> higher score indicates more intuitive use (Naumann & Hurtienne, 2010), the whole interval lies above the
> midpoint.
>
> *Reliability.* Cronbach's alpha, computed from the participants' responses, was 0.79 or above for the
> UEQ-S scales, the three GEQ components, the Godspeed Animacy subscale and the QUESI items, and 0.70 for
> the SUS. For the adapted QUESI items, 0.81 lies within the range of 0.78 to 0.92 reported for the
> QUESI's subscales (Naumann & Hurtienne, 2010). It was lower for the IEQ-SF: 0.59 for the full scale and 0.39 for its three-item Challenge
> subfactor, against 0.82 and 0.68 in the source. The Challenge score is therefore read with caution.
>
> *The pilot.* The ten pilot participants answered the same questionnaire (Table 29, lower rows). Their
> scores were higher than the main study's on every scale except challenge (2.80 in both). One of the ten
> responses gave the highest rating on every item, including the negatively worded SUS statements; a
> second response identical to it was excluded as a duplicate. The pilot played an earlier build, without a time limit and on
> other machines, and was designated a pilot afterwards. Its scores are therefore reported for
> completeness and are not compared with the main study's.

### Table 29. Post-Session Questionnaire Scores, Main Study

| Instrument and scale | Range | n | Mean | SD | 95% CI | Median | Min–max | Reference | Reading | α (study) | α (source) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| SUS | 0–100 | 34 | 67.7 | 12.9 | 63.2–72.2 | 66.3 | 40–90 | > 68 above average | At the benchmark (CI spans 68) | .70 | ≈ .91 |
| UEQ-S Pragmatic quality | −3 to +3 | 34 | 1.57 | 1.07 | 1.19–1.94 | 1.75 | −0.75–3.00 | > 0.8 positive | Positive | .84 | .85 |
| UEQ-S Hedonic quality | −3 to +3 | 34 | 1.82 | 0.80 | 1.54–2.10 | 1.88 | 0.00–3.00 | > 0.8 positive | Positive | .79 | .81 |
| IEQ-SF, all 11 items | 1–5 | 34 | 3.46 | 0.38 | 3.33–3.60 | 3.50 | 2.64–4.09 | Midpoint 3 | Above midpoint | .59 | .82 |
| Involvement (1–4) | 1–5 | 34 | 4.38 | 0.53 | 4.20–4.57 | 4.38 | 3.50–5.00 | Midpoint 3 | Above | .81 | .77 |
| Real-world dissociation (5–8) | 1–5 | 34 | 3.04 | 0.70 | 2.79–3.28 | 3.25 | 1.50–4.25 | Midpoint 3 | At midpoint | .69 | .75 |
| Challenge (9–11) | 1–5 | 34 | 2.80 | 0.63 | 2.58–3.02 | 3.00 | 1.33–3.67 | Midpoint 3 | At or just below | .39 | .68 |
| GEQ Positive affect | 0–4 | 34 | 3.46 | 0.56 | 3.27–3.66 | 3.70 | 2.40–4.00 | Midpoint 2 | Above | .92 | `[[TEAM]]` |
| GEQ Competence | 0–4 | 34 | 3.12 | 0.77 | 2.86–3.39 | 3.10 | 1.40–4.00 | Midpoint 2 | Above | .91 | `[[TEAM]]` |
| GEQ Sensory and imaginative immersion | 0–4 | 34 | 3.43 | 0.65 | 3.20–3.66 | 3.67 | 1.17–4.00 | Midpoint 2 | Above | .90 | `[[TEAM]]` |
| Godspeed Animacy | 1–5 | 34 | 3.89 | 0.80 | 3.61–4.17 | 3.83 | 2.00–5.00 | Midpoint 3 | Above | .91 | ≈ .88 |
| QUESI Perceived Familiarity | 1–5 | 34 | 4.10 | 0.73 | 3.84–4.35 | 4.00 | 2.33–5.00 | Midpoint 3 (higher = more intuitive) | Above | .81 | .78–.92 (subscales) |

*Note.* Main study only, first response per participant. References follow Section 4.10.3: the SUS
threshold of 68 (Sauro, 2011); the UEQ-S boundary of 0.8 (UEQ Handbook); for the IEQ-SF, GEQ, Godspeed and the
QUESI's Familiarity subscale administered on its own, which have no published population benchmark, the
scale midpoint. QUESI scores are item means from 1 to 5, higher scores indicating more intuitive use
(Naumann & Hurtienne, 2010). Source reliabilities are those stated in
Section 4.2.1B: SUS (Brooke, 1996; Lewis & Sauro, 2009), UEQ-S (Schrepp et al., 2017), IEQ-SF (Cutting et
al., 2025) and Godspeed Animacy (Ho & MacDorman, 2010); for the QUESI, the range across its five subscales (Naumann &
Hurtienne, 2010). IEQ-SF items 5 and 10 are reverse-scored. The
QUESI items were adapted to the drawing's ability, with the authors' permission (Appendix F). Without the three respondents whose
SUS answers did not follow the alternation of positive and negative statements, the SUS mean is 69.8 (95%
CI 65.7–74.0, n = 31).

### Item means (for an appendix, or for the team)

| Instrument | Item | Mean |
|---|---|---|
| SUS (1–5) | 1 use frequently · 2 unnecessarily complex · 3 easy to use · 4 need technical support · 5 well integrated · 6 too much inconsistency · 7 learn quickly · 8 cumbersome · 9 confident · 10 needed to learn a lot | 3.82 · 2.59 · 3.88 · 2.38 · 4.12 · 2.50 · 3.97 · 2.65 · 3.97 · 2.56 |
| UEQ-S (−3 to +3) | supportive · easy · efficient · clear · exciting · interesting · inventive · leading edge | 1.50 · 1.68 · 1.62 · 1.47 · 1.82 · 2.38 · 1.74 · 1.35 |
| IEQ-SF (1–5, raw, before reversal) | focused · experiencing · motivated · enjoyed · aware of real world* · forgot everyday concerns · separated from real world · unaware of controls · challenging · easy* · suspense | 4.41 · 4.18 · 4.26 · 4.68 · 3.85 · 3.41 · 3.21 · 3.38 · 3.24 · 3.85 · 3.03 |
| GEQ (0–4) | content · fun · happy · good · enjoyed it · skilful · competent · good at it · successful · fast at targets · story · aesthetically pleasing · imaginative · could explore · impressive · rich experience | 3.29 · 3.47 · 3.53 · 3.50 · 3.53 · 3.18 · 3.21 · 3.18 · 3.12 · 2.94 · 3.09 · 3.41 · 3.38 · 3.47 · 3.65 · 3.59 |
| Godspeed (1–5) | alive · lively · organic · lifelike · interactive · responsive | 3.88 · 3.91 · 3.74 · 3.68 · 4.15 · 4.00 |
| QUESI (1–5) | familiar · always clear what to do · automatically did the right thing | 4.29 · 3.88 · 4.12 |

\* reverse-scored when computing the subfactor.

### Table 29, lower rows: the pilot

Add these under the main-study rows, after a row that reads "**Pilot (n = 10), reported separately**".

| Instrument and scale | Range | n | Mean | SD | 95% CI | Median | Min–max |
|---|---|---|---|---|---|---|---|
| SUS | 0–100 | 10 | 68.8 | 17.9 | 56.0–81.5 | 71.3 | 45–100 |
| UEQ-S Pragmatic quality | −3 to +3 | 10 | 2.08 | 0.68 | 1.59–2.56 | 2.00 | 1.00–3.00 |
| UEQ-S Hedonic quality | −3 to +3 | 10 | 2.83 | 0.17 | 2.70–2.95 | 2.75 | 2.50–3.00 |
| IEQ-SF, all 11 items | 1–5 | 10 | 3.75 | 0.45 | 3.42–4.07 | 3.64 | 3.18–4.36 |
| Involvement | 1–5 | 10 | 4.70 | 0.54 | 4.32–5.00 | 5.00 | 3.50–5.00 |
| Real-world dissociation | 1–5 | 10 | 3.50 | 0.71 | 2.99–4.01 | 3.50 | 2.50–5.00 |
| Challenge | 1–5 | 10 | 2.80 | 0.86 | 2.18–3.42 | 2.83 | 1.67–4.00 |
| GEQ Positive affect | 0–4 | 10 | 3.70 | 0.40 | 3.41–3.99 | 3.80 | 2.80–4.00 |
| GEQ Competence | 0–4 | 10 | 3.24 | 0.82 | 2.65–3.83 | 3.50 | 1.60–4.00 |
| GEQ Sensory and imaginative immersion | 0–4 | 10 | 3.77 | 0.34 | 3.53–4.01 | 3.92 | 3.17–4.00 |
| Godspeed Animacy | 1–5 | 10 | 4.43 | 0.50 | 4.08–4.79 | 4.42 | 3.83–5.00 |
| QUESI Perceived Familiarity | 1–5 | 10 | 4.47 | 0.92 | 3.81–5.00 | 5.00 | 2.33–5.00 |

Add to Table 29's note: "Pilot: an earlier build, untimed, on other machines; not pooled with the main
study and not compared with it. One pilot response gave the highest rating on every item, including
the negatively worded SUS statements, and is included; a second response identical to it was excluded as
a duplicate. Confidence limits above the scale
maximum are shown at the maximum." Leave the Reference, Reading and α columns blank for the pilot rows.

## A2. Table 37: rows for the questionnaire

| Criterion (Section 4.10.3) | Result | Status |
|---|---|---|
| SUS above the above-average threshold of 68 | Mean 67.7 (95% CI 63.2–72.2), n = 34; 16 of 34 above 68 (Section 5.2.7) | Not shown: at the benchmark, not above it |
| UEQ-S pragmatic and hedonic quality positive (> 0.8) | Pragmatic 1.57 (1.19–1.94), hedonic 1.82 (1.54–2.10) | Met, on both scales |
| QUESI Perceived Familiarity (1–5, higher = more intuitive) | 4.10 (3.84–4.35) | Above the midpoint; descriptive, no numeric benchmark |
| IEQ-SF, GEQ components, Godspeed Animacy (no published benchmark) | IEQ-SF 3.46; GEQ 3.46 / 3.12 / 3.43; Animacy 3.89; all above the midpoint | Descriptive; no criterion |

This replaces "The SUS row stays pending until the questionnaire is analysed" in Part C §7.

## A3. §5.3.7 Limitations: bullets to add

> *The questionnaire was not completed immediately after play.* It was answered online between three
> hours and two days after the laboratory session, so the ratings rest on recollection rather than on an
> immediate reaction, as Section 4.3.4 intended.
>
> *Questionnaire and telemetry could not be linked.* Participants identified themselves by ID number in
> the questionnaire, and the telemetry recorded session codes. Thirty-four responses were received for 33
> logged sessions. The questionnaire is therefore reported for the group, and no player's ratings can be
> set beside their own play.
>
> *The Challenge subfactor of the IEQ-SF was unreliable in this sample* (α = 0.39), so its score is read
> with caution.
>
> *The sample.* The main study's participants were 17 to 20 years old. Twenty-eight of the 34 play video
> games more often than they draw, or do not draw at all. The results describe that audience.

## A4. §5.3.8 Discussion: drafts for points (2) and (3)

`[[TEAM: match these two headings to the wording of points (2) and (3) in your §5.3.8 template.]]`

**(2) Whether the game was usable and its experience positive.**

> The players found the game engaging more than they found it easy to operate. Its hedonic quality was
> clearly positive and its involvement high: enjoyment was the highest-rated statement in the whole
> questionnaire, and *interesting* the strongest of the UEQ-S's eight pairs. Its usability was at the
> conventional average, not above it. The SUS mean of 67.7 sits on the threshold of 68, and slightly
> fewer than half the players scored above it. The UEQ-S's pragmatic scale agrees in direction but rates
> the game more kindly, positive at 1.57, with *clear* its weakest item.
>
> The telemetry suggests where the friction lies. A third of the main study's drawings were declined, and
> nearly four in ten in Payyo, the level in which players learn what the brush accepts (Section 5.2.2C).
> Two of the five expert reviewers found themselves guessing at what to draw, and one would first make
> recognition more accurate (Section 5.2.9). An interface whose central input is sometimes refused is likely to be judged more cumbersome
> than one whose input always succeeds, however the refusal is explained, and *cumbersome* was the
> negative SUS statement the players rejected least firmly. The usability result should therefore be read
> as the cost of a recogniser that declines uncertain drawings, a choice the study made deliberately
> (Section 4.5.4.2), as much as of the menus and controls.
>
> Two other results qualify the immersion score. Players stayed aware of the real world, which a shared
> laboratory and a half-hour limit make likely. And they found the game easier than challenging. That
> agrees with three of the expert reviewers, who found that the challenge does not deepen once the
> mechanic is learned. It sits oddly beside the
> low completion of the later levels, until one recalls that those levels went unfinished because the
> sessions ended, not because players were stuck (Section 5.2.8). Competence was the lowest GEQ
> component, and its lowest item was speed at reaching the game's targets: players felt the clock more
> than the difficulty.

**(3) Whether the animated drawing was believable and its ability expected.**

> Players judged the animated drawing alive more than not (Godspeed Animacy 3.89 of 5). They rated it
> most highly as interactive and responsive, and less highly as lifelike or organic. The rigged drawing
> reads first as something that answers the player, and only second as something that lives. That fits
> what it is: the player's own strokes, recognisably a drawing, given a body and abilities.
>
> The abilities matched expectation. Players agreed that they could use their drawing's ability in a way
> that seemed familiar (4.29) and that they did the right thing with it without deliberating (4.12). The
> lowest of the three, that it was always clear what to do with the ability (3.88), was still in
> agreement. Set against the telemetry, the result needs one qualification. A quarter of the accepted
> drawings that players tried on an obstacle did not have the ability it needed (Section 5.2.2C). Players
> therefore felt that abilities behaved as expected even when a drawing failed to meet the obstacle's
> need. The questionnaire cannot say whether they blamed the drawing they chose or the ability it was
> given.

---
# Part B. The expert design review (PLAY)

Fills **§5.2.9**, **Tables 32 and 33** (`[[TEAM: check these numbers against the §5.2.9 placeholders]]`),
point (5) of **§5.3.8**, and parts of **§5.3.7**.

> **Final: all five reviews are in** (R5 submitted 23 November; updated 24 November). R1–R4 are unchanged
> in the final export. Every count below comes from `play.py` run on the final export.

## B0. The data and the decisions taken

| Issue | Decision |
|---|---|
| Five reviewers, within the three to five planned (§4.2.1C) | All five are reported |
| R1 entered a severity of 1 on five principles rated Met (III-A1, III-A2, III-G1, III-H4, III-I1) | The form asks for severity on P and N only, so these severities are not counted. Their comments are kept: two describe real problems (the haystack minimap, getting stuck) and are logged in Table 33 |
| R4 rated all fifty principles Met and left no comment | Reported as given. R4's ratings count in every total |
| R5's comment on I-A2 says "I rate this as an N", but the form records P | The recorded rating (P) is used. `[[TEAM: if R5 meant N, change it in the export and re-run.]]` |
| R5 noted that the build has no audio, but rated III-C2 (audio-visual feedback) Met | Counted as Met. R5 is not counted among the reviewers who raised the audio problem |
| The form had no item for the seven open questions on the drawing mechanic promised in §4.2.1C | Reported; see Section 2, item 9 |
| Several reviewers described one problem under more than one principle (e.g. audio under II-D1 and III-C2) | Merged into one problem in Table 33. Its severity is the highest the reviewer gave it, averaged over the reviewers who raised it |
| Names and e-mails were collected | Not reproduced. Reviewers are R1–R5 in order of submission |

## B1. §5.2.9 Expert Design Review: text to paste

> Five game development practitioners reviewed the design independently (Section 4.2.1C). R1 is the head
> programmer and founder of an independent studio, with five years in game development and three titles.
> R2 is a game developer and IT instructor with five years and two titles. R3 is a game developer with
> four years. R4 is a freelance developer with five years. R5 is a game reviewer, play tester and content
> creator and a member of a university indie game development organisation. R5 has five years of game
> development, two to three of them seriously, and has not yet published a title. `[[TEAM: or name them,
> if they agree.]]` All five played the build. R1, R3, R4 and R5 also reviewed the game design plan, the
> flowchart, the demonstration video and the concept art; R2 reviewed the video, the build and the concept
> art. The reviews were completed between 11 and 23 November 2026.
>
> Each reviewer rated all fifty principles of PLAY. Of the 250 ratings, 197 (79%) were Met, 51 (20%)
> Partially met, one Not met, and one Cannot assess. Fifteen principles were met in the view of all five
> reviewers, and none was rated below Met by more than three. Two were rated below Met by three
> reviewers: I-B2, pressure without frustration, and I-E4, challenge for players of every level. Table 32
> gives the ratings by heuristic. Usability and Game Mechanics (Category III) was met in 83% of ratings,
> and Game Play (Category I) in 76%. Coolness, Entertainment, Humour and Emotional Immersion (Category II)
> was met in 65%: seven of its twenty ratings were Partially met. Within Game Play, challenge, strategy
> and pace, and variety of players and game styles, were each met in 70% of ratings. Navigation was met
> in every rating, and error prevention in 23 of 25.
>
> The reviewers differed in how much they found. R5 rated 25 principles Partially met and logged twelve
> problems. R1 rated 12 principles below Met and logged five problems. R2 rated 12 Partially met and one
> Cannot assess, but logged no problem. R3 rated three Partially met. R4 rated every principle Met and made
> no comment.
>
> The one principle rated Not met was III-C2, appropriate audio, visual and visceral feedback. R1 rated it
> Not met because the game has no music or sound effects (severity 3), and R3 rated it Partially met for
> the same reason (severity 2). Both also rated immersion (II-D1) down for it, and it is the change R3
> would make first. R5 noted the missing audio too, but rated the principle Met.
>
> Table 33 lists the 25 distinct problems the reviewers identified, with the number who identified each,
> its mean severity and the team's response. Eight were identified by two or more reviewers, two of them by
> three, and seventeen by one.
>
> - **Severity 3 or 4.** These were found in play of the build.
>   - In Piyesta, the game once advanced the player to the birds rather than to the dancers (R1, severity
>     4; R1 noted "we can't be sure").
>   - One way to win could not be completed although its conditions had been met (R1, severity 3).
>   - The story starts too fast (R5, severity 3). The apo learns that Lola's brush leads into her
>     paintings through a question-and-answer exchange with Lolo at the start, and neither the brush nor
>     Lola's past is explained.
> - **Severity 2 to 2.5.**
>   - The game has no audio (R1 and R3).
>   - The challenge does not deepen (R1, R3 and R5): opponents do not adapt, the same drawings carry a
>     player through every level, and the game is easy to master.
>   - The recogniser misread drawings (R5): a flashlight in Dagat, and a sword read as a bridge or as bread.
>   - In Payyo's haystack, the minimap was drawn over the background (R1), and drawings placed inside
>     disappeared and turned up near the exit (R5).
>   - Climbing drawn stairs made the player float (R5).
>   - In Dilim, nothing shows how hurt an enemy is after several hits (R5).
>   - Dagat can be finished in under two minutes by avoiding the bakunawa (R5).
> - **Severity 1.5 to 2.** Two reviewers found themselves guessing at what to draw: R1 in the first level,
>   and R5 at the birds in Piyesta (drawing seeds before bread) and in the dark of Dagat. A third, R2,
>   rated the pacing of difficulty partially met.
> - **Severity 1.** The rest were cosmetic:
>   - rewards are the player's own growing skill rather than in-game capabilities;
>   - the emotional connection depends on the player;
>   - there is little humour, and the dialogue is poetic and told only in text;
>   - the art is not unified in style and scale, and Dagat's surface and underwater look pasted together;
>   - the game can drag at times, in Payyo and Dilim;
>   - fuller tutorials;
>   - light drawings that can be abused in Dilim;
>   - swimming forms that cannot jump on land;
>   - no key rebinding or controller support;
>   - a single save slot;
>   - a settings label that loses a letter on hover;
>   - a missing logo.
>
> Asked for an overall judgement, all five reviewers were favourable.
>
> - R1 judged the game professionally documented and complete, its bugs easily overlooked in play, and
>   ready to publish. R1 would first make the dialogue more casual, humorous or emotional.
> - R2 judged the design good, and would first make the art consistent in style and scale.
> - R3 judged it fit to stand against popular games: interesting, creative and immersive, with easy
>   onboarding and a gradual rise in challenge. R3 would first add audio.
> - R4 judged that the design complements every detail of the game, and named no change.
> - R5 saw "something to look forward to", praised its use of Filipino mythology and folklore as a
>   representation of the country, and judged that further patches and playtesting would improve it. R5
>   would first make recognition more accurate.
>
> On the review materials, R1 and R3 praised the documentation; R4 found it plain text and suggested a
> video presentation or images.

### Table 32. PLAY Ratings by Heuristic

| Category and heuristic | Principles | Met | Partially met | Not met | Cannot assess | Met (%) |
|---|---|---|---|---|---|---|
| **I. Game Play** | **22** | **84** | **25** | **0** | **1** | **76** |
| A. Enduring play | 5 | 18 | 7 | 0 | 0 | 72 |
| B. Challenge, strategy and pace | 6 | 21 | 9 | 0 | 0 | 70 |
| C. Consistency in game world | 2 | 9 | 1 | 0 | 0 | 90 |
| D. Goals | 3 | 13 | 2 | 0 | 0 | 87 |
| E. Variety of players and game styles | 4 | 14 | 5 | 0 | 1 | 70 |
| F. Players' perception of control | 2 | 9 | 1 | 0 | 0 | 90 |
| **II. Coolness, Entertainment, Humour and Emotional Immersion** | **4** | **13** | **7** | **0** | **0** | **65** |
| A. Emotional connection | 1 | 3 | 2 | 0 | 0 | 60 |
| B. Coolness / entertainment | 1 | 4 | 1 | 0 | 0 | 80 |
| C. Humour | 1 | 3 | 2 | 0 | 0 | 60 |
| D. Immersion | 1 | 3 | 2 | 0 | 0 | 60 |
| **III. Usability and Game Mechanics** | **24** | **100** | **19** | **1** | **0** | **83** |
| A. Documentation / tutorial | 2 | 7 | 3 | 0 | 0 | 70 |
| B. Status and score | 4 | 18 | 2 | 0 | 0 | 90 |
| C. Game provides feedback | 2 | 7 | 2 | 1 | 0 | 70 |
| D. Terminology | 3 | 14 | 1 | 0 | 0 | 93 |
| E. Burden on player | 2 | 8 | 2 | 0 | 0 | 80 |
| F. Screen layout | 4 | 14 | 6 | 0 | 0 | 70 |
| G. Navigation | 1 | 5 | 0 | 0 | 0 | 100 |
| H. Error prevention | 5 | 23 | 2 | 0 | 0 | 92 |
| I. Game story immersion | 1 | 4 | 1 | 0 | 0 | 80 |
| **All** | **50** | **197** | **51** | **1** | **1** | **79** |

*Note.* Five reviewers, so a heuristic with *k* principles has 5*k* ratings. Principles were rated Met,
Partially met, Not met or Cannot assess (Desurvire & Wiberg, 2009). By reviewer, ratings below Met: R1, 11
Partially met and 1 Not met; R2, 12 Partially met and 1 Cannot assess; R3, 3 Partially met; R4, none; R5, 25
Partially met. `[[TEAM: Heuristic III-D (Terminology) carries the same three principles as I-D (Goals) on
the form, as in Appendix G. Check this against Table 1 of the source.]]`

**Principles rated below Met, for the team** (rating and severity, as `play.py` prints them):

| Principle | Ratings below Met | Severities |
|---|---|---|
| I-A1 | R1 P, R5 P | 1, 1 |
| I-A2 | R5 P | 1 |
| I-A4 | R1 P, R5 P | 1, 2 |
| I-A5 | R2 P, R5 P | 1, 2 |
| I-B1 | R5 P | 1 |
| I-B2 | R1 P, R2 P, R5 P | 2, 1, 2 |
| I-B3 | R3 P, R5 P | 2, 2 |
| I-B5 | R5 P | 1 |
| I-B6 | R1 P, R5 P | 2, 3 |
| I-C2 | R5 P | 2 |
| I-D3 | R1 P, R2 P | 1, 1 |
| I-E1 | R2 P | 1 |
| I-E2 | R1 P, R5 P | 1, 1 |
| I-E4 | R1 P, R2 CA, R5 P | 1, —, 1 |
| I-F2 | R5 P | 2 |
| II-A1 | R1 P, R2 P | 1, 1 |
| II-B1 | R2 P | 1 |
| II-C1 | R1 P, R5 P | 1, 1 |
| II-D1 | R1 P, R3 P | 3, 2 |
| III-A1 | R2 P | 1 |
| III-A2 | R2 P, R5 P | 1, 1 |
| III-B2 | R5 P | 2 |
| III-B3 | R5 P | 1 |
| III-C1 | R5 P | 1 |
| III-C2 | **R1 N**, R3 P | 3, 2 |
| III-D3 | R1 P | 1 |
| III-E1 | R5 P | 2 |
| III-E2 | R5 P | 1 |
| III-F1 | R2 P | 1 |
| III-F2 | R2 P, R5 P | 1, 1 |
| III-F3 | R2 P, R5 P | 1, 1 |
| III-F4 | R2 P | 1 |
| III-H2 | R5 P | 1 |
| III-H4 | R5 P | 2 |
| III-I1 | R5 P | 3 |

### Table 33. Problems Identified by the Expert Reviewers, and the Team's Response

| # | Problem | Where | Principles | Reviewers | Mean severity | Response (proposed) | Reason or change |
|---|---|---|---|---|---|---|---|
| 1 | The game advanced the player to the birds instead of to the dancers | Piyesta | general | R1 | 4 | `[[TEAM: Corrected / not reproduced]]` | Part F, task F1 |
| 2 | One way to win could not be completed although its conditions were met | Logged as "end game"; also under I-E2 | I-E2, general | R1 | 3 | `[[TEAM]]` | Part F, task F2 |
| 3 | The story starts too fast. The brush's power is learned through a Q&A with Lolo, and the brush and Lola's past are never explained | Payyo opening; whole story | I-A5, III-I1 | R5 | 3 | `[[TEAM]]` | Lola's past is told through her diary pages, which R5 found too thin |
| 4 | No music or sound effects; visual responses have no audio cue | Whole game | II-D1, III-C2 | R1, R3 | 2.5 | Deferred | Audio is future work (§1.4, §4.5.4.7). The sound system and every sound are specified; no recordings exist |
| 5 | The challenge does not deepen: enemies don't adapt, the same drawings work through every level, and the game is easy to master. One difficulty setting | Whole game | I-B2, I-B3, I-B6, I-E2, I-E4 | R1, R3, R5 | 2.3 | `[[TEAM: Declined?]]` | By design the challenge is the drawing, and the confidence bar rises from Level 3 (§4.5.4.2). The questionnaire agrees: players rated the game easy (Section 5.2.7) |
| 6 | The recogniser misreads drawings (a flashlight in Dagat; a sword read as a bridge or bread), so redrawing feels repetitive. R5's first change | Drawing canvas | I-A1, I-A2, I-B2, I-B5, III-C1, III-E1, III-E2 | R5 | 2 | `[[TEAM: Deferred?]]` | The telemetry agrees: a quarter of the accepted drawings tried on an obstacle did not meet its tag (Section 5.2.2C). Retraining is outside the study's scope |
| 7 | Entering the haystack draws its minimap over the main background | Payyo | III-G1, general | R1 | 2 | `[[TEAM]]` | Part F, task F3 |
| 8 | Drawings placed inside the haystack disappear, and one turned up near the exit, wasting ink. The hint "something to stand on" misleads | Payyo, the haystack under the key | I-C2, I-E2, I-F2, III-E1 | R5 | 2 | `[[TEAM]]` | Part F, task F15 |
| 9 | Climbing drawn stairs (holding W) makes the player float | Payyo, drawn stairs | I-F2, III-E1, III-F2 | R5 | 2 | `[[TEAM]]` | Part F, task F16 |
| 10 | Nothing shows an enemy's health after 3–4 hits; the UI feels scattered and combat confusing | Dilim, combat | I-A1, III-B2, III-F2, III-F3 | R5 | 2 | `[[TEAM]]` | Dilim produced the most checkpoint restarts (Section 5.2.8) |
| 11 | Dagat is too short: under two minutes when the bakunawa is avoided | Dagat | I-A4 | R5 | 2 | `[[TEAM]]` | Median time to complete Dagat in the main study: 4.9 minutes (Table 30) |
| 12 | Players guess at what to draw, and the hints don't say enough (the first level; bread for the birds; the light in Dagat despite "needs light") | Payyo, Piyesta, Dagat | I-A1, I-A4, I-B2, III-H4 | R1, R2, R5 | 1.7 | `[[TEAM]]` | The telemetry agrees: 38.4% of Payyo's drawings were declined, and 22 of 33 players skipped the rest of its tutorial (Section 5.2.8) |
| 13 | Rewards are the player's own drawing skill, not in-game capability | Whole game | I-D3, III-D3 | R1, R2 | 1.0 | Declined | By design: abilities come with the class drawn, not with progress. Collectibles and the five flowers are the in-game rewards |
| 14 | The emotional connection depends on the player; the avatar could have a deeper purpose | Whole game | II-A1 | R1, R2 | 1.0 | `[[TEAM]]` | |
| 15 | Little humour; the dialogue is mostly poetic and told only in text, which may keep casual players out | Dialogue | II-C1, III-I1 | R1, R5 | 1.0 | `[[TEAM]]` | |
| 16 | The art is not unified in style and scale; Dagat's surface and underwater look pasted together | Whole game; Dagat | III-F1–F4, I-E1, general | R2, R5 | 1.0 | Deferred | Several pieces are placeholders, each listed by name in `ART_PLACEHOLDERS.md` |
| 17 | Engagement could be improved; the game can drag at times, in Payyo and Dilim | Payyo, Dilim | I-A1, I-A5, II-B1 | R2, R5 | 1.0 | `[[TEAM]]` | |
| 18 | Fuller tutorials ("actual tutorials") | Tutorial | III-A1, III-A2 | R2 | 1 | `[[TEAM]]` | |
| 19 | Light drawings such as the sun can be abused; R5 suggests a timer | Dilim | I-B1 | R5 | 1 | `[[TEAM]]` | |
| 20 | Swimming animal forms cannot jump on land, so the player must draw them mid-air over a puddle | Payyo | general | R5 | 1 | `[[TEAM]]` | Part F, task F17 |
| 21 | No key rebinding or controller support | Controls | III-B3 | R5 | 1 | `[[TEAM: Deferred?]]` | |
| 22 | Only one automatic save slot | Save system | III-H2 | R5 | 1 | `[[TEAM: Declined?]]` | Checkpoints save and restore progress (FR-8) |
| 23 | A settings label loses the letter "n" when hovered or toggled | Main menu, Settings | general | R1 | 1 | `[[TEAM]]` | Part F, task F4 |
| 24 | The game's logo is missing from the game files | Build | general | R1 | 1 | `[[TEAM]]` | Part F, task F5 |
| 25 | Physics or an unclear situation can leave a player stuck despite the hints | Seen in testing | III-H4 (rated Met) | R1 | — | `[[TEAM]]` | R1 judged it unlikely in normal play |

*Note.* A problem raised under more than one principle, or by more than one reviewer, is listed once.
Mean severity is over the reviewers who identified the problem, taking each reviewer's highest severity
for it (Nielsen, 1994: 0 not a problem, 1 cosmetic, 2 minor, 3 major, 4 catastrophic). Problem 25 was
described on a principle rated Met, so it carries no severity. Responses marked "proposed" are the
brief's suggestion; the team's response is final.

## B2. §5.3.7 Limitations: bullets to add

> *The expert review.* Five practitioners reviewed the design. Two of them (R1 and R5) identified most of
> the problems, and one rated every principle met without comment. The review therefore establishes that
> the problems in Table 33 exist, not that no others do (Section 4.2.1C). The form did not include the
> open questions on the drawing mechanic that Section 4.2.1C describes. The reviewers saw builds from 11 to
> 23 November, and some problems may have been fixed since.

## B3. §5.3.8 Discussion: draft for point (5)

`[[TEAM: match the heading to point (5) of your template.]]`

**(5) What practitioners make of the design.**

> The practitioners judged the design sound. Four in five of their ratings were Met, and no principle was
> rated below Met by more than three of the five. All five overall judgements were favourable: one
> reviewer called the game ready to publish, and another saw in it something to look forward to. Their
> reservations fall in four places, and each matches evidence from elsewhere in the study.
>
> The first is sound. The game has none, and it is the one principle rated Not met. Two reviewers named
> it, and one would fix it first. The study deferred audio (Section 1.4), and this result records the cost
> of that choice.
>
> The second is the start, and knowing what to draw. One reviewer found the first level confusing and
> found himself guessing; another drew seeds for the birds before trying bread, and found the story's
> opening too fast, its premise delivered as questions and answers with Lolo. The telemetry shows the
> same difficulty in play: Payyo had the highest decline rate of any level, and two in three players
> skipped the rest of its tutorial (Section 5.2.8). The players' usability rating, at the average rather
> than above it, is consistent with an opening that asks them to learn what the brush accepts largely by
> being refused.
>
> The third is recognition and the depth of challenge. The reviewer who found most problems would first
> make recognition more accurate, having seen a sword taken for a bridge or for bread. The telemetry
> agrees that this happens. A quarter of the accepted drawings that players tried on an obstacle lacked
> the ability it needed, and a player told to draw a ladder had a drawing accepted as bread (Section
> 5.2.2C). Three reviewers also found that the challenge does not deepen: the same drawings carry a player
> through, and opponents do not adapt. The players agreed that the game was easier than challenging
> (Section 5.2.7). Both points concern the study's central mechanic. The first is a limit of the
> recogniser; the second follows from a design in which the drawing is the challenge.
>
> The fourth is emotional reach. Humour, emotional connection, coolness and immersion were met in fewer
> ratings than any other part of PLAY (13 of 20). The players' ratings do not echo this. Their enjoyment
> and involvement were the highest scores of the questionnaire (Section 5.2.7). The practitioners judged
> the design against games they know, and the players judged the experience they had. The two can differ
> without either being wrong.
>
> What the practitioners praised is what the study set out to build: a drawing mechanic that lets a
> problem be solved several ways, goals presented clearly, and a game drawn from Filipino mythology and
> folklore. Navigation was met in every rating and error prevention in nearly every one.

## B4. If the reviews change again (for Claude Code)

R5 was added on 24 November by these steps. Use them again if a rating is corrected.

1. **Get the updated export from Kaina.** Keep it out of the repo, because it holds names and e-mails.
2. **Re-run:** `python3 play.py GameDevPlay.xlsx play.json play_tables.md`.
3. **Replace Table 32 and the "principles below Met" table** with the script's output. Never edit the
   counts by hand.
4. **Update every count in B1, B2 and B3** from the script's first three lines (totals, principles met by
   all, ratings below Met per reviewer, the category percentages).
5. **Merge new problems into Table 33 by hand.** Follow the rule in its note, then update the problem
   counts in B1.
6. **Update the reviewer count wherever it appears:** Section 1, Part C7, Part E and Part B2.
7. **Re-run `play.py`** and check every number in B1–B3 against its output.

---
# Part C. The playtest telemetry

This is `CHAP5_TELEMETRY.md` (17 November), carried over in full. Where Parts A and B settle something it
left open, the change is marked **[updated 20 Nov]**.

It fills **§5.2.2C (live play)**, **§5.2.5 (recognition speed)**, **§5.2.6 (gameplay performance)**,
the telemetry part of **§5.2.7 (participants)**, **§5.2.8 (gameplay effectiveness)**, two rows of
**Table 37**, and points (1) and (4) of **§5.3.8**. It also gives the Chapter 4 changes they depend on,
including a new paragraph on the pilot. Every figure comes from the telemetry in
`drive-download-20261117T005330Z-1-001.zip`, computed by `analysis.py` and recounted by a second script.
Nothing is estimated.

**Pilot and main study.** The team decided that the ten individual sessions of 6 to 12 November are a
**pilot**, and that the game was updated before the laboratory session. The **main study** is the 33
laboratory sessions of 16 November. Every result and every criterion below is judged on the main study.
The pilot is reported in its own rows, never pooled, and its questionnaire responses leave the main
analysis with it.

`tools/aggregate_telemetry.py` was **not** used, because the session that made these figures could not
open the repository. Run it on the main study's logs (`OBRA_telemetry_main.zip`) and compare. Section C0
gives the definitions used here so any difference can be traced. If the two disagree on a definition,
the tool's governs.

The five things this part left to the team:

1. **What changed after the pilot.** Section C1 drafts the pilot paragraph for §4.1.2, but only the team
   knows what was fixed and why.
2. **Are all 43 folders consented participants?** None should be a team member. One pilot folder (`R05`)
   sits on a development machine with 245 earlier sessions. **[updated 20 Nov]** None of the ten names in
   the pilot questionnaire is one of the thesis authors.
3. **The laboratory protocol on 16 November:** the place, the PCs' specification, and the time each group
   was given. The logs show two groups and sessions of about half an hour.
4. ~~Which questionnaire response belongs to which telemetry folder.~~ **[updated 20 Nov] Settled: they
   can't be linked.** The main study's questionnaire asked for ID numbers, the lab folders are named by
   session code, and only one folder name is an ID number. There are 34 responses for 33 sessions (Part
   A0). Pilot responses carry names, so the team can match them by hand if it decides to report them.
5. ~~The question on deliberately rejected drawings~~ **[updated 20 Nov] Settled: it was omitted, and
   the thesis does without it.** §4.2.1B is reworded (Part E); no limitation is added.

## C0. What the data is, and the decisions taken

### The sample

| | Main study | Pilot |
|---|---|---|
| Participants | **33** | 10 |
| Dates | Monday 16 November 2026, 09:40 to 10:59, in two groups (18 started 09:40 to 10:02, 15 started 10:16 to 10:28) | 6, 8, 9, 10, 11 and 12 November 2026, one at a time |
| Setting | Laboratory PCs, Windows, 60 Hz displays (inferred) | Participants' or the team's machines: 8 macOS, 2 Windows (inferred) |
| Time limit | About half an hour. Play time median 32.2 min (8.9 to 38.1) | None. Play time median 44.0 min (29.2 to 80.4) |
| Drawings submitted | 770 (median 23 per participant, 8 to 44) | 332 |
| Accepted drawings that appeared | 523 | 260 |

Participants are coded **P01 to P43** in order of start time over all 43: the pilot is P01 to P10 and the
main study P11 to P43. Use the codes in anything submitted. `per_participant.csv` holds the key to the
folder names; one lab folder is named with what looks like a student ID number, so never quote folder
names in anything submitted.

### Issues found in the export, and what was done

| Issue | Decision |
|---|---|
| The zip holds 74 `profile.json` files for 43 people. Thirty-two laboratory folders appear twice: once inside `R08/` (complete) and once at the top level (partial or empty). Every top-level copy is byte-identical to the nested one | Use the nested copy. `R1003` exists only at the top level and is kept |
| `R03-1` and `R03-2` are the same pilot participant. `R03-1` lacks the last session | Use `R03-2`, as P03 |
| `R05` holds 246 session logs from 25 July onward: a development machine | Keep only the pilot sitting (9 November, 18:44 to 19:14). Its profile agrees: 25 submissions, 4 declines |
| No log records the operating system, the hardware or the build | Platform is inferred from the clock: Windows writes timestamps to the millisecond, macOS to finer than that. Machines are grouped by display rate, round-trip time and memory footprint. Both are inferences and are labelled so |
| The logs do not separate supervised play from free play | Each participant's whole sitting is used |
| The lab build logs five kinds of event the pilot build never wrote: `collectible`, `drawing_reused`, `form_ability_used`, `locked_card_hint`, `restriction_violation` | Evidence that the build changed between pilot and main study. Cited in the pilot paragraph |

Three self-checks passed in both groups. Each participant's `profile.json` counts equal the counts in
their logs, for all 43. Every one of the 1,102 gate decisions agrees with Equation 4 and the bar in
force. A second script, reading the files directly, reproduces the totals.

### Definitions used

- **Submission:** a `recognition` event, written when the player presses Paint.
- **Declined at the floor:** `reason = confidence` (confidence below 0.60 or margin below 0.15).
  **Declined by the bar:** `reason = brush` (the floor accepted; the level's bar did not).
- **Redraw rate:** declined submissions ÷ submissions. **At the floor only:** floor declines ÷
  submissions.
- **End-to-end response time:** `spawn.latency_ms`, Paint pressed to the entity's first visible frame.
  **Round trip:** `recognition.latency_ms`. **Recogniser, inference:** `backend_timing`.
- **Percentiles:** linear interpolation.
- **Met the tag:** each accepted drawing made at an obstacle is matched to the first use of that drawing
  on that obstacle before the player's next submission (`obstacle_attempt.tag_match`).
- **Completion:** a participant completed a level if any visit to it ended `completed`.
  **Time to complete:** `time_on_level_s` summed over the participant's visits to the level up to the
  first completion, because the counter restarts on every visit.
- **Per-session CPU and memory:** the recogniser's 1 Hz samples that fall inside the participant's
  session logs.

## C1. Chapter 4 changes this depends on

### §4.1.2, gameplay participants: add a pilot paragraph

Add after the paragraph on the sample size of the gameplay evaluation:

> *Pilot.* Ten participants played the game individually between 6 and 12 November 2026, before the
> main evaluation, on the participants' or the researchers' own computers and without a time limit.
> These sessions served as a pilot of the build, the telemetry and the session procedure. They were
> designated a pilot after they had run, when the team updated the game in response to them. The
> changes made were: `[[TEAM: list them. The lab build logs five events the pilot build did not —
> collectible pickups, reused drawings, form abilities, hints on locked cards and restriction
> violations — so say which of these were new features and which only new logging. Name any crash
> fixed: three pilot logs on Windows stop in Dilim without a session end, and one Mac shows fourteen
> launches of under fifteen seconds.]]`. The session procedure was also changed, from untimed
> individual play to a laboratory session of about half an hour. The pilot participants' telemetry
> and questionnaire responses are reported separately in Chapter 5 and are not pooled with the main
> evaluation.

`[[TEAM: if the time limit was not a response to the pilot, delete that sentence.]]`

### §4.1.2 and §1.2.2: participant counts

"At least thirty play testers" still holds: the main study has 33. Report the pilot's 10 in addition, not
as part of the 30.

### §4.10.3, Recognition Speed

**Now:** "It is reported as a median and a ninety-fifth percentile across a full evaluation session on
the reference machine."

**Write:**

> It is reported as a median and a ninety-fifth percentile over every accepted drawing of the main
> evaluation, which ran on the laboratory's PCs. The telemetry does not record the hardware, so the
> platform is identified from the resolution of the system clock. The figures from the pilot, which
> ran on other machines including the reference machine, are reported separately.

`[[TEAM: check that the reference machine (the M1 Max MacBook Pro) was one of the pilot Macs. If so, the
sentence stands. If the lab PCs' specification is known, add it to §4.1.1.]]`

### §4.10.3, Table 14, Frame rate

**Add** to the "Instrumentation and Interval" cell:

> Computed as the whole frames counted during the request, divided by its duration. The request lasts
> five to ten frames, so one frame is a tenth to a fifth of the reading. The 1 Hz samples of the
> session are therefore reported beside it, including those of the seconds after each response.

### §4.10.3, Table 14, Memory Usage

**Write:** "Resident memory of the game process and the recognition backend, recorded separately by the
recogniser's sampler at 1 Hz; video memory of the game, sampled by the engine at 1 Hz." The engine's
static-memory counter reads zero in the exported build, so it is not used.

### §4.2.1B, the first supervised session

**Add** after "…excluded from the recognition analysis.":

> The telemetry as implemented does not mark where a supervised session ends. Each participant took
> part in one sitting, and all of it is analysed.

### §4.10.3, CNN Performance, live play

The sentence from `MANUSCRIPT_REVISIONS.md` stands ("Once the third hint names a class…"). **Add:**

> A player is not obliged to draw the class a hint names, so a mismatch on this subset cannot be
> separated from a player's choice to draw something else.

### §4.10.3, Table 13, Gameplay Effectiveness

**Now:** "Per session, reported within route". **Write:** "Per level, with the route chosen at each
fork". A route is chosen at each fork of a level, not once for the level (Figure 30).

## C2. §5.2.2C Live play: text to paste

Replace the placeholder and Table 23 with the following.

> In the main evaluation, 33 participants submitted 770 drawings (median 23 per participant, range 8
> to 44). The gate accepted 523 (67.9%) and declined 247 (32.1%). Of the declines, 236 (30.6% of
> submissions) fell below the floor of Equation 4 and 11 (1.4%) passed the floor but not the level's
> bar. Every floor decline failed on confidence: 121 on confidence alone and 115 on confidence and
> margin together. No drawing was declined on margin alone. Table 23 gives the outcomes by level, with
> the pilot in its own row.
>
> Median confidence was 0.88 over all submissions and median margin 0.81. Accepted drawings had a
> median confidence of 0.97, and 365 of the 523 (69.8%) were accepted at 0.90 or above. Declined
> drawings had a median confidence of 0.43. The model was seldom near its threshold: it was either
> sure or far from sure.
>
> The share of drawings declined at the floor fell from 38.4% in Payyo to about 22% in Dagat and
> Dilim. The later levels were reached by fewer participants (Section 5.2.8), so this compares a larger
> group with a smaller one and is not a clean measure of learning. The level's bar applied to 246
> submissions. It turned back 11 of the 202 that the floor would have accepted (5.4%), all with
> confidences between 0.61 and 0.69.
>
> Of the 523 accepted drawings, 413 (79.0%) followed no decline. Fifty-five came after one decline,
> 28 after two and 27 after three or more; the longest run was twelve declines before an acceptance.
> Three participants were never declined, and four were declined on half or more of their
> submissions.
>
> *Meeting the obstacle's tag.* 487 drawings were submitted at an obstacle. 190 (39.0%) were accepted
> and met the tag the obstacle asked for. 63 (12.9%) were accepted but did not meet it, 88 (18.1%) were
> accepted but not used on the obstacle before the next drawing, and 146 (30.0%) were declined.
> Twenty-five of the 88 were drawn in Dilim's last encounter, where drawings are used in a fight and
> not offered to a gate. Of the 253 accepted drawings that were tried on their obstacle, 190 (75.1%)
> met its tag.
>
> *Per-class recall.* Live per-class recall could not be estimated. The third hint, which names a
> class, was reached 18 times by 15 participants, and only 10 submissions by 7 participants carry an
> intended class: stairs (5), bat (3), ladder (1) and snake (1). One was recognised as the named class
> (snake). One was declined, and eight were accepted as a different class, four of which met the
> obstacle's tag anyway. A participant told to draw a ladder drew something accepted as bread at 0.98
> confidence, for example, and it solved the obstacle. A named class is therefore not evidence of
> what the player meant to draw, and with a support of at most five no figure is reported. Table 23's
> per-class rows are omitted for that reason.
>
> *Classes drawn.* Players had 37 of the fifty classes accepted at least once. The most often accepted
> were fish (59), axe (50), stairs (47), ladder (42), boomerang (33), flashlight (27), sword (27),
> bread (25) and bird (24). Thirteen classes were never accepted: ant, bee, bucket, cloud, crab,
> elephant, monkey, penguin, pig, scorpion, sea turtle, tree and wheel. Of the two classes below 0.70
> held-out recall (Section 5.2.2A), bird was accepted 24 times for 11 participants and frog twice.
>
> *The pilot.* The ten pilot participants submitted 332 drawings, of which 78.9% were accepted and
> 17.5% declined at the floor. They played without a time limit on different machines and an earlier
> build, so the comparison with the main study is descriptive only.

### Table 23. Recognition in Live Play, by Level

| Level | Bar | Submissions | Accepted | Declined at the floor | Declined by the bar |
|---|---|---|---|---|---|
| 1  Payyo | 0.60 | 320 | 197 (61.6%) | 123 (38.4%) | 0 |
| 2  Piyesta | 0.60 | 185 | 128 (69.2%) | 57 (30.8%) | 0 |
| 3  Dagat | 0.65 | 129 | 100 (77.5%) | 28 (21.7%) | 1 (0.8%) |
| 4  Dilim | 0.70 | 130 | 94 (72.3%) | 28 (21.5%) | 8 (6.2%) |
| 5  Mayon | 0.75 | 6 | 4 (66.7%) | 0 | 2 (33.3%) |
| Main study, all levels | | 770 | 523 (67.9%) | 236 (30.6%) | 11 (1.4%) |
| Pilot, all levels | | 332 | 262 (78.9%) | 58 (17.5%) | 12 (3.6%) |

*Note.* Main study: N = 33. Pilot: N = 10, reported separately and not included in the main-study rows.
A submission is one press of Paint. The floor is confidence ≥ 0.60 and margin ≥ 0.15 (Equation 4). The
bar is the level's nominal bar; it applies once the new brush is held and eases after two declines in a
row, so 13 main-study submissions in Dagat, 13 in Dilim and 1 in Mayon were judged at a lower bar than
the one shown. Per-class precision and recall are not reported: ten submissions carried an intended
class.

## C3. §5.2.5 Recognition Speed: text to paste

Keep the section's first paragraph, but change "on the reference machine and over a full evaluation
session" to "over every accepted drawing of the main evaluation". Replace the placeholder and Table 27
with the following.

> The end-to-end time was recorded for 523 accepted drawings in the main evaluation (Table 27). The
> median was 333 ms and the 95th percentile 438 ms. The 95th-percentile target of 500 ms was met: 519
> of the 523 drawings (99.2%) appeared within 500 ms. The median target of 250 ms was not met: only 5
> drawings (1.0%) appeared within 250 ms. The same held for each participant. Their medians ranged from
> 310 to 418 ms, so none met the median target, and the 95th percentile was at or below 500 ms for 32 of
> the 33.
>
> Recognition itself was not the slow part. The round trip, from the request leaving the game to the
> response returning, had a median of 84 ms. The recogniser accounted for about 4 ms of that (3.6 ms of
> preprocessing and 0.47 ms of inference). Across all 24,124 requests it served during the main
> evaluation, which include the guesses made while a drawing was in progress, its median was 3.8 ms
> and its 95th percentile 4.6 ms. The larger share of the end-to-end time came after the response: a
> median of 246 ms passed between the response and the entity's first visible frame. Section 5.2.6
> shows that the game rendered few frames during that interval.
>
> The pilot ran on other machines (Figure 28). On the two pilot Macs with 60 Hz displays the median
> met the target (228 ms and 247 ms). On a Mac with a 120 Hz display it was 326 ms, and on the two
> Windows machines 342 and 358 ms. Over the pilot's 260 accepted drawings the median was 267 ms and
> the 95th percentile 425 ms.

`[[TEAM: if the reference machine (M1 Max) is one of the pilot Macs, name it here: "On the reference
machine, Mac __, the median was __ ms." Mac A: 228 ms; Mac B (120 Hz): 326 ms; Mac C: 247 ms.]]`

### Table 27. Recognition Response Time (milliseconds)

| Measure | Group | n | Median | 95th percentile | Criterion met? |
|---|---|---|---|---|---|
| End to end: Paint → entity visible | Main study | 523 | 333 | 438 | Median no; 95th percentile yes |
| Component: round trip | Main study | 770 | 84 | 129 | n/a |
| Component: recogniser (decode, preprocess, inference) | Main study | 770 | 4.2 | 5.0 | n/a |
| Component: inference only | Main study | 770 | 0.47 | 0.56 | n/a |
| Response → entity visible | Main study | 523 | 246 | 318 | n/a |
| End to end: Paint → entity visible | Pilot, macOS | 178 | 246 | 347 | n/a (pilot) |
| End to end: Paint → entity visible | Pilot, Windows | 82 | 357 | 473 | n/a (pilot) |
| End to end: Paint → entity visible | Pilot, both | 260 | 267 | 425 | n/a (pilot) |

*Note.* Criterion: median ≤ 250 ms and 95th percentile ≤ 500 ms (Section 4.10.3), judged on the main
study. End-to-end times are of accepted drawings; the components are of every submission. The main study
ran on the laboratory's PCs under Windows; the pilot's platforms are inferred from the resolution of the
logged clock. By pilot machine, end-to-end median and 95th percentile: Windows PC 1, 342 and 447 (n =
33); Windows PC 2, 358 and 534 (49); Mac A, 228 and 259 (65); Mac B, 326 and 361 (50); Mac C, 247 and
279 (63).

### Figure 28. End-to-End Response Time, Main Study and Pilot Machines

File: `fig28_response_time.png`.

*Note.* Each bar spans the middle half of the accepted drawings in a group of sessions, the white line is
the median, and the thin line runs from the 5th to the 95th percentile. The main study is the top row.
Pilot machines are grouped by display rate and memory footprint; the telemetry does not name them.

## C4. §5.2.6 Gameplay Performance: text to paste

Replace the placeholder and Table 28 with the following.

> Table 28 reports the measures of Table 14 for the 33 sessions of the main evaluation, as the median
> across sessions of each session's median, and the highest peak any session reached. GPU utilisation
> is not reported: the engine exposes no counter for it.
>
> *Frame rate during submission.* The frame rate held during recognition. Of 770 submission windows,
> 766 were at or above the floor of 55 frames per second. The four below it (42.7 to 54.8) were each in
> a different session, on requests that took 164 to 234 ms.
>
> *Frame rate after the response.* The 1 Hz samples show a drop that the submission window does not
> cover (Figure 29). In the second after an accepted drawing the reading had a median of 59 and a 5th
> percentile of 46, and in the second after that a median of 52. It returned to 60 by the third second.
> After a declined drawing it stayed at 60 throughout. The lowest reading in the three seconds after the
> response was below 55 for 96.4% of accepted drawings and 0.4% of declined ones. Measured against each
> session's own median, an accepted drawing cost a median of 11 frames, about 183 ms, and a declined
> drawing none. Declined drawings pass through the same request and the same recogniser. The frames are
> therefore lost to what follows acceptance and not to recognition. What follows acceptance is the
> building of the entity from the player's strokes, though the telemetry does not time that step.
>
> *Processor and memory.* The game used a median of 28% of one core. The recogniser was idle most of
> the time: 80% of its samples read zero, and it rose in bursts to a peak of 78% to 125% of one core.
> Its resident memory stayed below 100 MB in every session. The game's resident memory had a median of
> 1,104 MB, with a peak of 1,596 MB.
>
> *The pilot.* On the pilot machines the frame rate during the request held on the Windows machines and
> the 120 Hz Mac. On the two 60 Hz Macs the measure could not resolve the floor. It divides the whole
> frames counted during a request by the request's duration. A request there took about 95 ms, between
> five and six frame intervals at 60 Hz. Five whole frames were counted in 85% of requests, which gives
> 50 to 55 whatever the true rate, and 150 of 159 windows read between 49.5 and 54.9. The 1 Hz samples of
> the same sessions have a median of 60.

### Table 28. Gameplay Performance per Session, Main Study

| Quantity | Process | Sessions | Median (range of session medians) | Highest peak | Note |
|---|---|---|---|---|---|
| Frame rate during submission (fps) | Game | 33 | 60.3 (60.0 to 64.0) | lowest 42.7 | 766 of 770 windows ≥ 55 |
| Frame rate, 1 Hz samples (fps) | Game | 33 | 60 (60 to 60) | lowest 1 | 1.4% of 60,573 samples < 55 |
| CPU utilisation (% of one core) | Game | 33 | 27.7 (21.6 to 35.9) | 143.8 | |
| CPU utilisation (% of one core) | Recogniser | 33 | 0.0 (0.0 to 0.0) | 125.0 | 80% of samples zero |
| Resident memory (MB) | Game | 33 | 1,104 (822 to 1,153) | 1,596 | |
| Resident memory (MB) | Recogniser | 33 | 96 (90 to 97) | 99 | |
| Video memory (MB) | Game | 33 | 268 (183 to 315) | 682 | |
| GPU utilisation | — | — | not measured | — | No counter exposed |

*Note.* Main study: 33 sessions on the laboratory's PCs, Windows, 60 Hz displays. A submission window is
the interval during which a recognition request is in flight. Floor: 55 fps (Section 4.10.2). For frame
rate, the "highest peak" column gives the lowest value, since the floor is a minimum; the lowest 1 Hz
samples fall at level loads. CPU and resident memory are the recogniser's 1 Hz samples of both processes.
Pilot (10 sessions, not shown): game memory median 477 MB on macOS and 918 MB on Windows; the recogniser
peaked above 700% of one core on both pilot Windows machines.

### Figure 29. Frame Rate in the Seconds Around a Recognition Response

File: `fig29_frame_rate_after_submission.png`.

*Note.* Main study. Median and 5th percentile of the 1 Hz frame-rate samples of the 33 sessions, grouped
by the second in which they fall relative to the response. Each point rests on 471 to 531 samples for
accepted drawings and 244 to 249 for declined ones. The 5th percentile of declined drawings stays at 59 or
above and is not drawn.

## C5. §5.2.7, the participants paragraph

**[updated 20 Nov]** Superseded by **Part A1**, which merges the telemetry's participant facts with the
questionnaire's. Use Part A1.

## C6. §5.2.8 Gameplay Effectiveness: text to paste

Replace the placeholder, Table 30 and Table 31 with the following. Table 30 changes shape. The template
had one row per level and route, but a route is chosen at each fork within a level, so routes are
reported per fork in Figure 30.

> Table 30 reports completion, time and redraw rate for each level of the main evaluation. All 33
> participants completed Payyo, 30 Piyesta, 22 Dagat, 5 Dilim and 1 Mayon. The furthest level completed
> was Dagat for 17 participants, Piyesta for 8, Dilim for 4, Payyo for 3 and Mayon for 1.
>
> These rates measure the length of the session as much as the difficulty of the levels. Sessions
> lasted a median of 32 minutes. Nine of the 33 participants stopped after completing a level. The other
> 24 were inside a level when their logs end: three in Piyesta, six in Dagat, thirteen in Dilim and two
> in Mayon. No participant left a level unfinished and went on playing something else, so every
> non-completion coincides with the end of a session. The pilot shows how long the whole game takes
> without a limit: its ten participants needed 29 to 80 minutes (median 44), and only four of them
> would have finished within the longest laboratory session (38 minutes). No incomplete level in the
> main evaluation can therefore be attributed to a low-recall class or to a level that could not be
> passed.
>
> Dagat is the one level where completion differed by route. All six participants who did not complete
> it had taken the artist route there. Of the 14 on that route, 8 completed it, against all 6 on the
> pragmatist route and all 8 on the protector route, and they took longer (median 5.9 minutes against
> 3.8 and 4.9). With six non-completions, all ended by the session, this is a pattern to check rather
> than a finding.
>
> Dilim took the longest: a median of 12.6 minutes for the five who completed it, against 4.9 to 9.7
> for the other levels. It also produced the most restarts from a checkpoint, 46 across 15 of its 18
> players (median 2 per player, at most 11), against 27 in Dagat and one each in Payyo and Piyesta.
> Players ran out of supplies five times, all in Dilim's last encounter. The thirteen who did not
> complete Dilim had been in it for a median of 10.0 minutes (2.2 to 17.0) when their sessions ended.
>
> Few players needed the later hints. Of 376 obstacles solved, 356 were solved with no hint or the first
> prompt alone, 10 after the second hint and 10 after the third, and 4 were logged as assisted. The
> second hint was reached 32 times and the third 18 times. Twenty-two of the 33 participants skipped the
> remaining lessons of the Payyo tutorial, with a median of 24 lessons still to come (7 to 27).
>
> Figure 30 shows the route each participant first chose at each fork. Across the 293 choices, 100 were
> artist, 92 pragmatist and 101 protector. The balance differs by fork. At Payyo's last fork 30 of 33
> participants took the pragmatist route, which is opened with an item found in the level. Dilim's
> encounters each had a preferred answer: protector for the tikbalang (12 of 15), pragmatist for the
> tiyanak and the manananggal (7 of 14 and 6 of 10), and artist for the kapre (9 of 14).
>
> Table 31 gives the play-style profile. Participants had a median of 10 distinct classes accepted (5 to
> 17). The redraw rate had a median of 0.32 per participant (0.00 to 0.60). No route dominated: 11
> participants leaned protector, 8 pragmatist and 6 artist, and 8 were tied. Only one participant in the
> main evaluation reached the summit. Its computed ending was C, which is logged and not shown to the
> player.
>
> In the pilot, where play was untimed, all ten participants completed all five levels. Dilim again took
> the longest (median 16.2 minutes) and produced most of the restarts (57). The endings computed for
> the ten were D (The Persevering Spirit) for seven, C for two and B for one. No pilot participant found
> all five hidden flowers, so all ten summits played the standard ending.

### Table 30. Completion, Time on Level and Redraw Rate by Level

| Level | Group | Started | Completed | Completion rate | Median time to complete, min (IQR) | Submissions | Redraw rate |
|---|---|---|---|---|---|---|---|
| 1  Payyo | Main study | 33 | 33 | 100% | 9.7 (7.6 to 11.1) | 320 | 38.4% |
| 2  Piyesta | Main study | 33 | 30 | 91% | 5.3 (4.6 to 7.1) | 185 | 30.8% |
| 3  Dagat | Main study | 28 | 22 | 79% | 4.9 (3.6 to 6.6) | 129 | 22.5% |
| 4  Dilim | Main study | 18 | 5 | 28% | 12.6 (8.8 to 14.3) | 130 | 27.7% |
| 5  Mayon | Main study | 3 | 1 | 33% | 7.0 (one participant) | 6 | 33.3% |
| 1  Payyo | Pilot | 10 | 10 | 100% | 7.2 (6.8 to 10.0) | 85 | 16.5% |
| 2  Piyesta | Pilot | 10 | 10 | 100% | 4.3 (3.2 to 5.1) | 28 | 21.4% |
| 3  Dagat | Pilot | 10 | 10 | 100% | 4.9 (3.9 to 5.6) | 47 | 21.3% |
| 4  Dilim | Pilot | 10 | 10 | 100% | 16.2 (7.9 to 18.6) | 132 | 19.7% |
| 5  Mayon | Pilot | 10 | 10 | 100% | 6.6 (5.6 to 7.5) | 40 | 35.0% |

*Note.* Main study: laboratory sessions of about half an hour; every participant who did not complete a
level was in it when the session ended. Pilot: untimed, reported separately. The completion rate is of
those who started the level. Time to complete is summed over a participant's visits to the level up to
its first completion. The redraw rate is declined submissions over submissions made in the level. Routes
are chosen at each fork and are reported in Figure 30.

### Figure 30. Route First Chosen at Each Fork, Main Study

File: `fig30_routes_by_fork.png`.

*Note.* One bar per fork or encounter, counting each main-study participant's first choice there.
Segments of one participant are unlabelled. Dagat's first fork offers two routes and Dilim's nuno one.
One further fork in Payyo was reached by a single participant and is not shown.

### Table 31. Play-Style Profile

| Measure | Main study (N = 33) | Pilot (N = 10) |
|---|---|---|
| Class diversity (distinct classes accepted), median (range) | 10 (5 to 17) | 11 (8 to 16) |
| Redraw rate, whole session, median (range) | 0.32 (0.00 to 0.60) | 0.19 (0.00 to 0.43) |
| Redraw rate at the gate's floor only, median (range) | 0.32 (0.00 to 0.60) | 0.14 (0.00 to 0.38) |
| Dominant route | Protector 11, pragmatist 8, artist 6, tied 8 | Artist 5, protector 2, pragmatist 1, tied 2 |
| Reached the summit | 1 | 10 |
| Ending computed (A–D), logged, not shown | C 1 | D 7, C 2, B 1 |
| Hidden flowers found (of 5), median (range) | 1 (0 to 3) | 1.5 (0 to 3) |
| Bakunawa encounter in Dagat | Lit 13, fought 8, evaded 6 (n = 27) | Fought 5, lit 3, evaded 2 |

*Note.* The dominant route is the highest of a participant's three route tallies at the end of the
session. The last two rows are additions to the template. No participant in either group found all five
hidden flowers.

## C7. §5.3.6: Tables 37 and 38

### Table 37, two rows

| Criterion (Section 4.10.3) | Result | Status |
|---|---|---|
| Median end-to-end response ≤ 250 ms; 95th percentile ≤ 500 ms | Main study, 523 accepted drawings: median 333 ms, 95th percentile 438 ms (Section 5.2.5) | 95th percentile met; median not met |
| Frame rate not below 55 fps during a submission window | Main study: 766 of 770 windows at or above 55. A drop below 55 follows 96% of accepted drawings, after the window closes (Section 5.2.6) | Met during the request. A drop follows acceptance |

`[[TEAM: decide how to word the two statuses. "Partly met" is the honest short form for the first.]]`
**[updated 20 Nov]** The questionnaire rows are in **Part A2**.

### Table 38 (to become Table 39), objective 5

**[updated 20 Nov]** Set the status to:

> Gameplay evaluation complete: playtest telemetry for 33 participants, with a pilot of 10 (Sections
> 5.2.2C, 5.2.5, 5.2.6 and 5.2.8); post-session questionnaire for 34 respondents (Section 5.2.7); expert
> design review by five practitioners (Section 5.2.9); cultural panel of seven (Section 5.2.10).

This replaces the wordings in `CHAP5_TELEMETRY.md` and `CHAP5_CULTURAL_PANEL.md`.

## C8. §5.3.7 Limitations Exposed During Testing: bullets to add

> *The response time after recognition.* The recogniser answered in a median of 84 ms, but a median of
> 246 ms more passed before the entity appeared, and the game lost about eleven frames after each
> accepted drawing. Building the entity from the player's strokes is the likeliest cause, and the
> telemetry does not break that interval down.
>
> *The frame-rate measure.* The submission window is five to ten frames long, so its reading moves by a
> tenth to a fifth for each frame counted. It could not resolve the 55 fps floor on the pilot's 60 Hz
> Macs, and it closes before the entity is built, where the drop occurs.
>
> *Hardware was not logged.* The telemetry records neither the operating system nor the machine. The
> platform was inferred from the resolution of the logged clock.
>
> *Time-limited sessions.* The 33 main-study sessions lasted about half an hour, and 24 ended inside a
> level. Completion of Dilim and Mayon was observed without a time limit only in the pilot, on an
> earlier build.
>
> *A pilot designated afterwards.* The ten pilot sessions were designated a pilot after they had run,
> when the game was updated in response to them. Their results are reported separately.
>
> *Live per-class recall.* Only ten submissions carried an intended class, and the players did not
> always draw the class the hint named. Recognition of specific classes by real players therefore
> remains unmeasured.
>
> *Supervised and free play.* The logs do not mark where a supervised session ends, so each
> participant's whole sitting was analysed.
>
**[updated 20 Nov]** The 17 Nov draft had an eighth bullet, on deliberately rejected drawings. **Drop
it.** The question was omitted, and §4.2.1B now explains why it isn't needed (Part E).

## C9. §5.3.8, points (1) and (4): drafts

Points (2), (3) and (5) are now drafted in Parts A4 and B3. Point (6) is in Part D3.

**(1) Whether recognition was fast and smooth enough in practice.**

> Recognition was fast. The model answered in under half a millisecond, the recognition service in
> about four, and the whole request in 84 ms. The claim that recognition does not block the game is
> also supported: the frame rate held through the request, and a declined drawing, which makes the
> same request, cost no frames at all.
>
> The response as a whole was slower than the target. The median of 333 ms missed the 250 ms target,
> though nearly every drawing appeared within the 500 ms set for the 95th percentile. The delay lies
> after recognition. About 250 ms passed between the response and the entity's appearance, and the
> game dropped about eleven frames at that moment. The likeliest cause is turning the player's strokes
> into a rigged, physical body in one step, on the thread that draws the game. The telemetry cannot
> confirm this, since it does not time that step. If it is the cause, it is the cost of the study's
> central design choice, that the player's own drawing is what moves, and a game that swapped the
> drawing for a prepared sprite would not pay it. The remedy would be an engineering one, spreading the
> construction over several frames or moving it off the main thread, and it is left as future work.
> The pilot suggests the hardware matters too: on two of its Macs the median was under 250 ms.
>
> The frame-rate criterion was written for the submission window, on the assumption that the request
> was where frames would be lost. The request turned out to be harmless and the loss came just after
> it, outside the window. The 1 Hz samples, which Section 4.10.3 specified for another purpose, are
> what exposed it.

**(4) Completion within each route.**

> No participant was stopped by a level. In the pilot, without a time limit, all ten completed the
> game. In the main evaluation no participant abandoned a level and moved on: each non-completion is a
> session that ended. The telemetry therefore gives no case of a level that a player could not pass. It
> cannot rule such cases out for the participants whose sessions ended in Dagat or Dilim.
>
> Dilim is where time went. It took the longest in both groups and produced most of the checkpoint
> restarts, and it is the level in which the game turns from puzzles to fighting by drawing. Whether
> that is the intended climb in difficulty or a spike is a design question, and it should be weighed
> with the expert reviewers' ratings (Section 5.2.9).
>
> Redrawing was common but short. A third of the main evaluation's drawings were declined, and in
> Payyo, where players were still learning what the brush accepts, nearly four in ten were. But four
> accepted drawings in five followed no decline, and the model was rarely undecided: accepted drawings
> were mostly above 0.90 and declined ones mostly below 0.55. The level's bar played a small part,
> declining 11 drawings in all, 5% of those the floor would have accepted.
>
> The routes were used. Across all forks the three were chosen about equally, which suggests that the
> gates did not funnel players into one answer. The exceptions are informative: at Payyo's last fork
> nine in ten players used the item the level had given them and did not draw, and each of Dilim's
> creatures drew most players to one counter. Obstacles that ask for an ability were answered with a
> wide range of drawings, 37 of the fifty classes, though a quarter of the accepted drawings tried on an
> obstacle did not have the ability it needed. The telemetry cannot say how many of those were the
> wrong class recognised and how many the right class for the wrong job.

**[updated 24 Nov]** One expert reviewer (R5) singled out Dilim, but for confusing combat, with nothing
to show an enemy's health, not for difficulty. R5 also wanted the later levels to be harder. If the
paragraph on Dilim keeps its last sentence, add: "One of the five reviewers found its combat confusing,
chiefly because nothing shows how hurt an enemy is; none found it too hard."

`[[TEAM: the pilot declined fewer drawings (21%) than the main study (32%). The pilot used an earlier
build, other machines and no time limit, and its players may have been different, so do not read the gap
as an effect of anything in particular unless §5.2.7 can explain it.]]` **[updated 20 Nov]** §5.2.7 now
shows the main study's players were 17 to 20 and mostly gamers. The pilot's eight who gave an age were 20
to 21. That is a difference in the groups, not an explanation.

## C10. Other places in the manuscript that change (telemetry)

- **Chapter 5, opening note and second paragraph:** change "the gameplay evaluation with at least thirty
  participants" to "the gameplay evaluation with 33 participants, after a pilot with 10".
- **§5.1.4:** "tools/aggregate\_telemetry.py turns a set of session logs into the figures reported in
  Sections 5.2.5 to 5.2.8". Keep it only if the tool is run on the main study's logs and its output is
  what the chapter reports. Also change "frame rate and memory sampled at 1 Hz" to "frame rate and video
  memory".
- **Figures:** Figures 28 to 30 are new. No figure follows Figure 27 in Chapter 5, so nothing is
  renumbered.
- **Section 5.2.3, last sentence of the simulation's limitations:** "That is measured in the playtest
  (Section 5.2.2C)". Change to "The redraw rate of real players is reported in Section 5.2.2C."
- **Abstract and Chapter 6:** see Part E.

## C11. For the team, not for the chapter

These are now **Part F**, tasks F6–F11.

## C12. Files (from the 17 Nov analysis)

| File | What it is |
|---|---|
| `analysis.py`, `load.py`, `figures.py` | The scripts. `OBRA_COHORT=lab python3 analysis.py <unzipped export> <folder holding load.py> <output folder>` gives the main study; `OBRA_COHORT=individual` the pilot; unset, all 43 |
| `results_main.json`, `results_pilot.json` | Every figure in this part |
| `per_participant.csv` | One row per participant, both groups, with a `cohort` column (`lab` = main study, `individual` = pilot) |
| `OBRA_telemetry_main.zip`, `OBRA_telemetry_pilot.zip` | The deduplicated logs of each group, for `tools/aggregate_telemetry.py` |
| `fig28_response_time.png`, `fig29_frame_rate_after_submission.png`, `fig30_routes_by_fork.png` | Figures 28 to 30 |

`[[TEAM: these files were delivered with CHAP5_TELEMETRY.md on 17 November and are not attached to this
brief. If you no longer have them, ask for them to be regenerated.]]`

---
# Part D. The cultural content panel

This is `CHAP5_CULTURAL_PANEL.md` (17 November), carried over in full. On 20 November every count in
Tables 34 and 35 and the overall assessments were re-checked against `CulturalContent.xlsx`, and all
match. It fills **§5.2.10 (Cultural Content Evaluation)** and point (6) of **§5.3.8**, and gives the
matching changes to Chapter 4.

The team's decisions (17 November) are built in. One check is left:

> `[[TEAM: Table 36 calls five changes "corrected". Before submission, confirm each one is actually in
> the build. Any that isn't becomes "deferred", here and in the discussion.]]`

## D0. What changed from the plan, and the decisions taken

| Issue | Decision |
|---|---|
| Four of the seven panelists teach Araling Panlipunan 7 or 8 (junior high), not the elementary subjects in §4.1.2 | Describe the panel as **teachers of Araling Panlipunan and related subjects in basic education**, and state the change as a deviation from the plan |
| No panelist played the game | Report it. The brief offered a supervised session with the playable build; none was held |
| No clarity or relevance ratings were collected | **Drop the content validity indices** from §4.2.1D, report agreement counts, and add a limitation |
| Familiarity options | The same five as Appendix H: Not at all, A little, Somewhat, Well, Very well |
| Items 5, 17, 18 and 20 were worded for an earlier version of the game | Report each item as asked, with a table note |
| Cronbach's alpha | Not reported. Delete the α column from Table 35 |
| Table numbering | A new Table 36 (the panel's concerns). The current Tables 36–38 become 37–39; update §5.3.6's cross-references |
| Names | All seven chose not to be named; four typed a name in the optional field anyway. Remove that field from anything submitted |

## D1. Chapter 4 changes this depends on

### §4.1.2, "Cultural content panel": three replacements

**First paragraph, first sentence.** Replace with:

> The cultural content of the game is reviewed by a panel of six to eight teachers of Araling
> Panlipunan and related subjects in basic education, whose assigned subjects include the Philippine
> places, communities, beliefs and celebrations on which the game draws.

**Eligibility, criterion (1).** Replace with:

> (1) teach, in School Year 2026–2027, Araling Panlipunan or a related subject (Music and Arts,
> Makabansa or Filipino) at the elementary or junior high school level, or taught one in either of the
> two preceding school years;

Then add at the end of the *Eligibility* paragraph:

> The panel was planned around teachers of the elementary subjects named above. Four of the seven
> teachers recruited teach Araling Panlipunan at the junior high level instead; each holds a degree in
> Social Studies or Social Science or teaches Araling Panlipunan, and the criterion was widened to admit
> them. Section 5.2.10 reports the panel as constituted.

**Administration.** Replace the sentences from "A researcher brings a computer…" to "…outside class
hours." with:

> The brief offered each panelist a supervised session with the playable build, at a time and place of
> their choosing outside class hours. No panelist took one, and all reviewed the brief, the
> demonstration video, or both.

### §4.2.1D: replace the reliability paragraph

Replace the paragraph on content validity indices (or, if not yet revised, the one from "Content validity
rests on…" to "…rather than in place of them.") with:

> For each item, the analysis reports the number of panelists who rated it, the median, the range, the
> numbers who agreed, were neutral and disagreed, and the number who could not judge. The same is
> reported for each dimension, from each panelist's dimension score. The open responses are analysed
> thematically, and each issue is recorded with the team's response: corrected, deferred, or declined
> with a stated reason. An item on which more than one panelist disagrees, and any concern raised by two
> or more panelists, goes on a documented revision list. No content validity index is reported, since
> the panelists were not asked to rate each item's clarity and relevance, and Cronbach's alpha is not
> reported.

Also in §4.2.1D: "a panel of elementary school teachers" becomes "a panel of teachers of Araling
Panlipunan and related subjects". The same change goes in the Abstract, §1.2.1, §1.2.2 and §1.3.

## D2. §5.2.10 Cultural Content Evaluation: text to paste

Replace the whole placeholder, including the yellow note, with the following.

> **5.2.10 Cultural Content Evaluation**
>
> Seven teachers reviewed the game's cultural content (Section 4.2.1D), within the panel size of six to
> eight set in Section 4.1.2. Four teach Araling Panlipunan in junior high school (Grades 7 and 8), with
> seven to thirteen years in the subject. Three teach or have taught the elementary subjects on which the
> panel was planned: one taught Araling Panlipunan 4 and 5 for twenty years; one has taught Kindergarten
> to Grade 6 for more than twenty years, including Araling Panlipunan 4 and 5, Music and Arts 4,
> Makabansa 3 and Filipino; and one has taught Makabansa 3 for three years. Four teach in public schools
> and three in private schools, in Cebu and Leyte. All seven have lived in Central or Eastern Visayas; no
> panelist was from the Cordillera or Bicol. All seven asked not to be named.
>
> No panelist played the build. Three reviewed the brief alone, one the demonstration video alone, and
> three both. Every judgement reported here therefore rests on the design materials rather than on play
> (Section 4.2.1D).
>
> Table 34 gives the panel's familiarity with each setting. No panelist chose "not at all" or "a little"
> for any setting. Philippine folklore and Visayan festivals were the best known, with six of the seven
> panelists familiar with each "well" or "very well". Coastal fishing communities were the least known:
> four of the seven were only "somewhat" familiar with them.
>
> Table 35 reports each item and each dimension of the Ecological Validity Model (Bernal, Bonilla &
> Bellido, 1995): the number of panelists who rated it, the median, the range, how many agreed (4 or 5),
> were neutral (3) or disagreed (1 or 2), and how many could not judge. A dimension score is a
> panelist's mean on the dimension's two items. Agreement was high. On 17 of the 21 items, at least six
> of the seven panelists agreed, and no panelist chose "strongly disagree" on any item. Language and
> Persons had the strongest support: all seven panelists scored both dimensions 4 or above. The one
> "cannot judge" response was on item 4, the grandfather as a guiding presence. One panelist, who
> reviewed the brief alone, answered "neither agree nor disagree" on every item from 5 to 21, which sets
> the ceiling of six agreements on most items.
>
> Four items fell below six agreements. Item 5, on the aswang as a figure of the grandmother's grief,
> drew the most dissent: three panelists disagreed, one was neutral and three agreed (median 3, range
> 2–5). It is the only item on which more than one panelist disagreed, and it places the Metaphors
> dimension lowest (median 3.5; three of seven at 4 or above). Item 5 was written for an earlier design.
> In the game as built, the aswang does not stand for the grandmother's grief, and the brief said so. So
> a disagreement may reject the metaphor as the item describes it, or the aswang as the game shows it.
> The open responses (below) point to the latter. Items 11 and 12, on the ending and what the game asks
> the player to value, and item 21, on Mayon as the setting of the climax, each drew one disagreement.
> The two Goals disagreements came from the panelist who reviewed the video alone and reported that it
> was too fast to follow. The Mayon disagreement came from a panelist who reviewed the brief alone.
>
> In their overall assessment, four panelists judged that the cultural content may be used as it is,
> and three that it may be used after the minor changes they noted. None asked for major changes or
> judged that the content should not be used.
>
> *Open responses.* The six open questions were answered by six panelists; one left them blank. Two
> concerns were raised by more than one panelist, and both are on the revision list (Table 36):
>
> - **The aswang.** One panelist named "the aswang part" as the thing that felt wrong. Another asked the
>   team to research the aswang further, since in folklore it is a mystery handed down through
>   generations, different from the game's description and closer to a white lady. The game does draw
>   one aswang after the white lady of Filipino ghost stories, as the brief disclosed.
> - **Everyday culture.** Three panelists asked for more of everyday Filipino life: food (bibingka,
>   adobo), clothing (the bahag), local languages, traditional arts, an Ifugao main character, and family
>   customs such as visiting the dead at the cemetery with prayers and candles. One observed that the
>   game "only focuses on places, literature, and festivals".
>
> On whether the game understands Philippine culture or only uses its names and places (D3), five of the
> six who answered said that it understands it. Two of those five qualified their answer: the
> understanding rests on places, folklore and festivals, and more everyday detail would deepen it. The
> sixth could not judge, because the video was too fast to follow. On the title (D4), five of the six who
> answered said that it fits, four of them reading *obra* as a work of art or a creation ("likha",
> "obra maestra"). The sixth answered "somewhat", reading it as work or labour. Five of six would be
> comfortable showing the game to someone from a region it depicts, two of them on condition that the
> details are accurate or that the characters look native to the region. The sixth would try but could
> not promise.
>
> One concern was raised by a single panelist: throwing things at the birds in Piyesta, one of the
> level's three ways to recover the scraps, might offend animal lovers. One panelist commended the use of
> local characters in place of the demonic characters common in popular games.
>
> Table 36 lists every concern the panel raised and the team's response to each.

### Table 34. Panelists' Familiarity with Each Setting

| Setting | Not at all | A little | Somewhat | Well | Very well |
|---|---|---|---|---|---|
| The Cordillera and the Banaue Rice Terraces (Payyo) | 0 | 0 | 2 | 3 | 2 |
| Sinulog or other Visayan street festivals (Piyesta) | 0 | 0 | 1 | 2 | 4 |
| Coastal and small-boat fishing communities (Dagat) | 0 | 0 | 4 | 0 | 3 |
| Philippine folklore and its creatures (Dilim) | 0 | 0 | 1 | 2 | 4 |
| The Bicol region and Mayon Volcano (Mayon) | 0 | 0 | 2 | 4 | 1 |

*Note.* n = 7. Settings as worded in the questionnaire as administered.

### Table 35. Cultural Content Questionnaire Results

| Dimension or item | n | Median | Range | Agree (4–5) | Neutral (3) | Disagree (1–2) | Cannot judge |
|---|---|---|---|---|---|---|---|
| **Language** | 7 | 5 | 4–5 | 7 | 0 | 0 | 0 |
| 1. Filipino words used correctly | 7 | 5 | 4–5 | 7 | 0 | 0 | 0 |
| 2. Untranslated words feel natural | 7 | 5 | 4–5 | 7 | 0 | 0 | 0 |
| **Persons** | 7 | 5 | 4–5 | 7 | 0 | 0 | 0 |
| 3. Grandchild and grandmother | 7 | 5 | 4–5 | 7 | 0 | 0 | 0 |
| 4. Grandfather as a guiding presence | 6 | 5 | 4–5 | 6 | 0 | 0 | 1 |
| **Metaphors** | 7 | 3.5 | 3–5 | 3 | — | 0 | 0 |
| 5. The aswang as the grandmother's grief | 7 | 3 | 2–5 | 3 | 1 | 3 | 0 |
| 6. Other symbols (flowers, Mayon) | 7 | 5 | 3–5 | 6 | 1 | 0 | 0 |
| **Content** | 7 | 4.5 | 3–5 | 6 | — | 0 | 0 |
| 7. The festival | 7 | 5 | 3–5 | 6 | 1 | 0 | 0 |
| 8. Everyday details | 7 | 4 | 3–5 | 6 | 1 | 0 | 0 |
| **Concepts** | 7 | 4.5 | 3–5 | 6 | — | 0 | 0 |
| 9. Grief and memory | 7 | 4 | 3–5 | 6 | 1 | 0 | 0 |
| 10. Family obligation | 7 | 5 | 3–5 | 6 | 1 | 0 | 0 |
| **Goals** | 7 | 5 | 2–5 | 4 | — | 1 | 0 |
| 11. The ending | 7 | 5 | 2–5 | 4 | 2 | 1 | 0 |
| 12. What the player is asked to value | 7 | 5 | 2–5 | 5 | 1 | 1 | 0 |
| **Methods** | 7 | 4.5 | 3–5 | 6 | — | 0 | 0 |
| 13. Drawing as the main way to play | 7 | 5 | 3–5 | 6 | 1 | 0 | 0 |
| 14. The dialogue choices | 7 | 4 | 3–5 | 6 | 1 | 0 | 0 |
| **Context** | 7 | 4.5 | 3–5 | 6 | — | 0 | 0 |
| 15. The five settings together | 7 | 5 | 3–5 | 6 | 1 | 0 | 0 |
| 16. Poorer neighbourhoods | 7 | 4 | 3–5 | 6 | 1 | 0 | 0 |
| 17. Payyo (asked as "Bahay Kubo") | 7 | 5 | 3–5 | 6 | 1 | 0 | 0 |
| 18. Piyesta (asked as "Pista") | 7 | 4 | 3–5 | 6 | 1 | 0 | 0 |
| 19. Dagat | 7 | 4 | 3–5 | 6 | 1 | 0 | 0 |
| 20. Dilim (asked as "its Aswang encounter") | 7 | 4 | 3–5 | 6 | 1 | 0 | 0 |
| 21. Mayon | 7 | 4 | 2–5 | 5 | 1 | 1 | 0 |

*Note.* Dimensions follow Bernal, Bonilla and Bellido (1995). Ratings run from 1 (strongly disagree) to 5
(strongly agree). A dimension score is each panelist's mean of the dimension's two items, and the
dimension rows count panelists whose score is 4 or above ("Agree") or below 3 ("Disagree"); scores of 3 to
3.5 are counted in neither. Item 5 was written for an earlier design: in the game as reviewed, the aswang
does not represent the grandmother's grief. Items 17, 18 and 20 are reported under the level names used
in the questionnaire, which predate the final names.

*How the dimension rows were counted (for the team; not for the chapter).* Metaphors: scores of 3, 3, 3,
3.5, 4.5, 5, 5, so three at 4 or above and four between 3 and 3.5. Goals: 2, 3, 3.5, 5, 5, 5, 5, so four
at 4 or above and one below 3. In the Content, Concepts, Methods and Context rows, the one panelist not
counted scored 3.

### Table 36. Concerns Raised by the Panel and the Team's Response

| Concern | Raised by | Response | Reason or change |
|---|---|---|---|
| The aswang: its depiction, one form being drawn after the white lady | Item 5: three panelists disagreed. Open responses: two panelists | Declined | Aswang lore varies from region to region and gives the figure no single form. One of the game's two forms follows common descriptions of the aswang; the other's white-lady look is borrowed, as the brief disclosed. No panelist saw the aswang in play, where the player need not fight it and has only to last until dawn. |
| Everyday culture: food, clothing, language, family customs, an Ifugao main character | Three panelists | Corrected in part; the rest deferred | Added: an Ifugao guardian at the bale in Payyo, who tells the apo about Ifugao houses; fiesta food in the Piyesta plaza; a line or two in each region's own language. Deferred: regional dress, an Ifugao main character, and family customs for the dead. |
| The ending, and what the game asks the player to value | Items 11–12: one panelist | Corrected | At the ending, the apo does the mano to Lola. |
| Mayon as the setting of the climax | Item 21: one panelist | Corrected | Lolo tells the legend of Daragang Magayon, and the Cagsawa ruin is named. |
| Throwing things at the birds in Piyesta | One panelist | Declined | Throwing is one of three ways to recover the scraps; the player may instead feed the birds or climb to the strings. |
| The demonstration video was too fast to follow | One panelist | Corrected, for later reviewers | A narrated slide presentation now explains each level and its themes alongside the video. |

*Note.* Under Section 4.2.1D, an item on which more than one panelist disagrees, and any concern raised by
two or more, goes on the revision list; the first two rows met that rule. The remaining rows are
single-panelist concerns, recorded for completeness.

## D3. §5.3.8, point (6): the panel's judgement, for the discussion

The discussion interprets; it should not repeat Table 35. A draft:

> The cultural panel accepted the game's cultural content. No panelist rejected it, and most agreed with
> nearly every item. Their agreement was strongest where the game is closest to ordinary Filipino family
> life: the language it keeps untranslated and the relationships between the apo, Lola and Lolo. Their
> reservations were narrower and fell in two places.
>
> The first is the aswang. It is the one figure on which the panel divided, and six of the seven
> panelists know Philippine folklore well or very well, so the division carries weight. Their written
> comments suggest the objection is to the figure as drawn more than to any meaning given to it: one of
> the game's two aswang forms is borrowed from the white lady, a separate figure, and a panelist pointed
> out exactly that conflation. The team kept both forms, for the reasons given in Table 36. The concern
> is therefore recorded rather than resolved, and the Metaphors result should be read with that in mind.
>
> The second is a matter of omission rather than error. Section 2.6 observed that Philippine settings,
> where games use them at all, are often reduced to visual motif, and Section 4.2.1D adopted Bernal,
> Bonilla and Bellido's (1995) distinction between surface-level adaptation, which reaches names, images
> and settings, and deep-structure adaptation, which reaches values and meanings, as a test the game might
> fail. The panel's answer runs against the expectation stated there. The game was judged strongest on
> deep structure, the family relationships and the values its story turns on (Persons, Concepts, Goals),
> and the panelists' requests concerned the surface it leaves thin: food, clothing, language and everyday
> custom. The rating items could not register that gap, since they ask whether what the game shows is
> accurate and respectful, not what it leaves out. The open responses therefore qualify the ratings. The
> game represents Philippine places, festivals, folklore and family in a way these teachers recognise,
> but it represents Philippine everyday life only thinly. The team added some of what was asked (Table
> 36) and deferred the rest.
>
> The panel's judgement has limits that weigh on these conclusions. No panelist played the game, so none
> judged how the content reads in motion or in the pacing of play. The single dissents on the ending and
> on Mayon came from panelists who saw only one of the two review materials. And the panel was drawn from
> the Visayas, so its judgement of the Cordillera and Bicol levels is that of teachers who know those
> places through the curriculum, not through residence.

## D4. Other places in the manuscript that change (cultural panel)

- **§5.3.6, Table 38 (to become Table 39), objective 5:** use the status in Part C7, which supersedes this
  part's wording.
- **§5.3.7, Limitations Exposed During Testing:** add one bullet.
  > *The cultural review rests on design materials.* The seven panelists reviewed a brief, a
  > demonstration video, or both; none played the game. Four teach junior high school rather than the
  > elementary subjects on which the panel was planned, and none is from the Cordillera or Bicol. Four
  > questionnaire items were worded for an earlier version of the game. The panelists did not rate each
  > item's clarity and relevance, so no content validity index is reported, and the panel's agreement is
  > reported as counts.
- **§2.6** still calls the levels "a bahay kubo among rice terraces, a town pista". Update them to Payyo
  and Piyesta. Its claim that "reviews of the field consistently find" that serious games succeed when the
  mechanics carry the content has no citation; give it one, since the discussion above now leans on §2.6.
- **Appendix H:** it still says the questionnaire was administered to students of anthropology, sociology
  and history. Change it to the panel as constituted (Section D1 above).
- **Appendix (if responses are reproduced):** use panelist codes P1–P7 in order of response, and remove
  the name and town fields. With a panel this small, a town and a subject together can identify someone.

## D5. Acknowledgements (all seven chose "describe me by subject, grade and years")

In order of response:

- P1: a teacher of Araling Panlipunan 8, ten years
- P2: a teacher of Araling Panlipunan 7 and 8, seven years
- P3: a teacher of Araling Panlipunan 7, ten years
- P4: a teacher of Araling Panlipunan 4 and 5, twenty years
- P5: a teacher of Araling Panlipunan 7, thirteen years
- P6: an elementary teacher of Araling Panlipunan, Music and Arts, Makabansa and Filipino, Kindergarten to
  Grade 6, more than twenty years
- P7: a teacher of Makabansa 3, three years

P4 asked whether the team will share the finished work with the panel. Someone on the team should reply.

---
# Part E. Changes elsewhere in the manuscript

Chapter 1–4 changes from before the evaluation are in the repo's `docs/MANUSCRIPT_REVISIONS.md` (31
Oct). They still stand and are not repeated here. The changes below follow from the evaluation. Parts C1
and D1 hold the telemetry's and the panel's Chapter 4 changes.

### Abstract and Chapter 6: headline results

Use these figures, and no others:

> The gameplay evaluation involved 33 participants in a laboratory session, after a pilot with 10. Of
> 770 drawings, 68% were accepted. The median response from drawing to entity was 333 ms, with a 95th
> percentile of 438 ms. Recognition itself took 84 ms; the rest was the building of the entity. All ten
> untimed pilot participants completed the game. Usability was average (SUS 67.7). Pragmatic and hedonic
> quality were positive (UEQ-S 1.57 and 1.82), the animated drawings were judged alive (Godspeed Animacy
> 3.89 of 5), and their abilities familiar (QUESI 4.10 of 5). Five game developers found
> 79% of the PLAY ratings met. The gaps they named most were missing audio, a challenge that does not
> deepen, and players guessing at what to draw. Seven teachers
> judged the cultural content usable, four as it is and three after minor changes.

### §1.2.2, objective 5, and §1.4

Write "33 play testers, after a pilot of 10, with five game developer practitioners and
seven cultural evaluators recruited separately" wherever a single participant count is given (see
`MANUSCRIPT_REVISIONS.md`, Abstract item).

### §4.2.1B, Gameplay-Evaluation Instruments

- **Appendix F (QUESI).** The questionnaire used the published wording with the referent adapted.
  Appendix F's items 2 and 3 are wrong. Replace them with the wording actually administered:
  - "It was always clear to me what I had to do to use my drawing's ability."
  - "With my drawing's ability, I automatically did the right thing to achieve my goals."

  Item 1 is already correct. The *Adaptation* paragraph stands. Replace the *Permission* paragraph's
  account of the pending request (from "A written permission request was nevertheless sent…" to the end)
  with:

  > A written request to use the subscale, with its referent adapted to the drawing's ability, was sent
  > to Prof. Dr. Jörn Hurtienne on 9 November 2026, and permission was granted by him in writing on 11
  > November 2026.

  **The e-mail itself.** His reply carries a footer saying its content is confidential and may not be
  shared with a third party without the sender's express consent. So **don't reproduce the e-mail in
  Appendix H** as the other permissions are. State the permission as above. If the panel wants the
  correspondence, ask Prof. Hurtienne whether it may be reproduced, or show it to the panel privately.
  `[[TEAM: check that the 9 Nov request described the change of referent, so his "yes" covers the
  adaptation and not only use.]]`
- **The deliberate-rejection measure.** The question was left out, and the paragraph should now say why
  it isn't needed. In the paragraph on the play-style profile, change "Three measures are therefore
  taken." to "Two measures are therefore taken." Then replace the sentence "The post-session
  questionnaire asks participants directly whether they deliberately submitted drawings they expected
  to be rejected, and sessions answering in the affirmative are reported separately rather than
  discarded silently." with:

  > A direct question in the post-session questionnaire was also considered and not included. As built,
  > the four endings are computed and logged for the analysis but never shown to the player, whose run
  > ends at Mayon's summit (Section 4.5.4.5), so a participant has no ending to gain by drawing badly.

  Also update the paragraph's opening: the claim that "class diversity, together with route history and
  collectibles, determines which of the four endings the player receives" should become "…determines
  which of the four endings is computed for the analysis".

### §4.3.4 and §4.10.3: when the questionnaire was answered

**Now:** "Immediately after the session, each participant will complete the post-session instruments".

**Write:**

> After the session, each participant completed the post-session instruments online. In the main
> evaluation they were completed between three hours and two days after play (Section 5.2.7).

Apply the same change to the *User Acceptance Testing* paragraph ("Immediately after completing the
assigned gameplay session…").

### §4.2.1C, Expert Design Review Instrument

- **Now:** "The form also carries seven open-response questions on the drawing mechanic — the team's own,
  and identified as such — and a problem log."
- **Write:** "The form also carries a problem log and a request for an overall judgement." Do this
  `[[TEAM: Section 2, item 9]]`; or keep the sentence and add the omission to §5.3.7.
- "The study recruits three to five reviewers": five took part. Nothing to change.

### §4.10.3, User Experience: the QUESI reference

Only the Familiarity subscale was administered, so the full QUESI's benchmark does not apply.

- **Now:** "Three carry a published interpretive reference and three do not."
  **Write:** "Two carry a published interpretive reference and four do not."
- **Now:** "QUESI Perceived Familiarity is read against the benchmark values reported by Naumann and
  Hurtienne (2010)."
  **Write:** "QUESI Perceived Familiarity is scored as the mean of its items, from 1 to 5, higher scores
  indicating more intuitive use (Naumann & Hurtienne, 2010); because the subscale is administered on its
  own, it is read against the scale midpoint."
- **Now:** "For the IEQ-SF, the GEQ components, and the Godspeed Animacy subscale no population benchmark
  is published…"
  **Write:** "For the IEQ-SF, the GEQ components, the Godspeed Animacy subscale and the QUESI Familiarity
  subscale used on its own, no population benchmark applies…"

Everything else in the paragraph stands: means with 95% confidence intervals, against the stated
references, with no significance tests between subgroups.

### `PAPER_STATUS.md` (repo)

Replace the "User study" row with:

> **Run.** 16 Nov 2026: 33 players in the laboratory, after a pilot of 10 (6–12 Nov). Telemetry, a
> post-session questionnaire (34 respondents), an expert review (PLAY, five developers) and
> a cultural panel (seven teachers). Results are in `docs/CHAPTER5_BRIEF.md`.

Also update "What is not done": remove "No user study", and keep the audio and per-class-recall caveats.
Under "Results available now", add the headline figures above.

---

# Part F. Code and repo tasks

Each task gets its own branch and PR under the repo's rules. **Reproduce first.** If a bug doesn't
reproduce on `main`, say so in the PR or to Kaina, and record it as "not reproduced" in Table 33. Do not
change Table 33's response column yourself; tell Kaina what you found.

**From the expert review (Table 33)**

| Task | Problem | Where to look | Severity |
|---|---|---|---|
| **F1** | R1: "the game proceeds to the area where the player need to interact with the birds instead of spawning on the area where the dancers are". After a load, restart or checkpoint, the player is placed at the birds, not the dancers | Piyesta's spawn and checkpoint restore; `game/config/level_02.json` (or Piyesta's level script) | 4 |
| **F2** | R1: "The game can't fully finished even all conditions are met" (logged as "Eng game"), and under I-E2: "one option to win has some bugs… the actual level can't be 'finished' even certain conditions are met". The level isn't named | Ask Kaina whether R1 said which level. If not, run `run_journey_probe` and each level's route probes for every route; look for a route whose completion condition can be met without the level ending | 3 |
| **F3** | Payyo: "weird overlaying of haystack mini map and main background" on entering the haystack | Payyo's haystack interior and minimap layers. Capture it with a `tests/_tmp_*.gd` window script and look at the frame | 2 |
| **F4** | Settings, main menu: a label loses its letter "n" when hovered or toggled | The settings menu's labels and their hover/toggle styles (`UISkin`). Likely clipping or a changed font size on hover | 1 |
| **F5** | "Missing logo of the game" in the game files | The export preset's icon, the boot splash, the window icon | 1 |
| **F15** | R5: drawings placed inside Payyo's haystack disappear, and a ladder turned up near the exit, wasting ink. The hint ("something to stand on") misleads; only angled stairs worked | Placement and collision inside the haystack sub-room; where a drawing is put when it lands out of bounds; the hint's wording (it must not name a class) | 2 |
| **F16** | R5: climbing drawn stairs while holding W makes the player float up | The stairs utility's climb behaviour, and its interaction with the ladder climb | 2 |
| **F17** | R5: swimming animal forms can't jump on land, so the player has to draw them mid-air over a puddle | The swim forms' ground movement in Payyo | 1 |

The other problems R5 raised are design decisions for the team, not bugs. They are Table 33 rows 3, 5,
6, 10, 11, 19, 21 and 22: the story opening, challenge depth, recognition accuracy, an enemy health
indicator in Dilim, Dagat's length, light drawings in Dilim, rebinding and controllers, and save slots.
Don't build any of them unless the team decides to.

**From the telemetry (formerly C11)**

| Task | What | Why |
|---|---|---|
| **F6** | Profile the spawn: about 180 ms of lost frames per accepted drawing on the lab PCs | Part C4. Check the rig-building step in the profiler; consider spreading it over frames |
| **F7** | `fps_during_submit`: record the longest frame time in the window, and extend the window to the entity's first frame | The current measure can't see the drop (Part C4) |
| **F8** | Log the platform, the machine, the build and a participant code in `session_start` | Hardware had to be inferred (Part C0) |
| **F9** | Ask for the participant code the questionnaire uses (or show the code to type into it) | The questionnaire and telemetry could not be linked (Part A0) |
| **F10** | `static_mb` is zero in exported builds: drop it or replace it | Part C1 |
| **F11** | Mark supervised play and free play, if §4.2.1B is to hold | Part C1 |
| **F12** | Dagat's artist route: the six who did not finish Dagat were all on it. Play it through | Part C6 |

**Docs**

| Task | What |
|---|---|
| **F13** | Commit this file as `docs/CHAPTER5_BRIEF.md`, and the two scripts from Part G as `tools/chapter5/postplay.py` and `tools/chapter5/play.py`, on a branch such as `chapter5-brief`. **Not** the workbooks |
| **F14** | Update `PAPER_STATUS.md` as in Part E |

---

# Part G. Reproducing the numbers

The scripts take the Google Forms exports as downloaded, and need Python 3 with `openpyxl` and `scipy`
(`requirements.txt`). `docs/CHAPTER5_REDO_ANALYSIS.md` walks through every step and decision.

| What | Command | Output |
|---|---|---|
| Questionnaire (Part A) | `python3 postplay.py GameTestersPostPlay.xlsx postplay.json questionnaire_scores_anonymised.csv` | Every figure in Part A: scale scores, 95% CIs, alphas, item means, the per-respondent scores, and the data checks. Prints the exclusions and flagged rows |
| Expert review (Part B) | `python3 play.py GameDevPlay.xlsx play.json play_tables.md` | Part B's counts, Table 32, the principles below Met, and the overall judgements, as Markdown. Re-run it if a review is corrected (Part B4) |
| Cultural panel (Part D) | `python3 cultural.py CulturalContent.xlsx cultural_tables.md` | Tables 34 and 35, and the overall assessments |
| Telemetry (Part C) | `OBRA_COHORT=lab python3 analysis.py <unzipped export> <folder with load.py> <out>` | The 17 Nov scripts (Part C12) |

How `postplay.py` decides each row's group:

- A code of "test" is excluded.
- A response before 16 Nov is pilot (this includes the one coded "R08").
- The rows listed in `EXCLUDE_ROWS` at the top of the script are removed. Each carries its reason;
  today that is one duplicate pilot response.
- A response on or after 16 Nov is main study, keeping the first response per ID.

It asserts the column layout before scoring. If the form is exported again with columns added or
reordered, it will stop rather than mis-score.

**Respondent codes.** Q01–Q34 are the main-study respondents in order of submission. Q27–Q29 are the three
whose SUS answers ignore the alternation, and Q27 is the one who gave 3 on every SUS item. The mapping
from codes to IDs is in `postplay.json` (`per_respondent`), which holds student IDs, so keep it out of
the repo.
