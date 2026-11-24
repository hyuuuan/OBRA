"""Reproduce Tables 34 and 35 of the cultural content panel (Part D of the brief) from the Google Form export.

Usage: python3 cultural.py CulturalContent.xlsx [out.md]
Familiarity counts (Table 34); per item: n, median, range, agree (4-5), neutral (3), disagree (1-2),
cannot judge; per dimension: each panelist's mean of the dimension's two items, counted >= 4 agree,
< 3 disagree; and the overall assessments. No alpha or CVI is computed (decided 17 Nov).
"""
import sys, statistics as st, openpyxl
ws = openpyxl.load_workbook(sys.argv[1], data_only=True).worksheets[0]
rows = [r for r in ws.iter_rows(values_only=True)]
h, d = rows[0], [r for r in rows[1:] if any(c is not None for c in r)]
FAM, ITEMS = range(12, 17), range(17, 38)
assert "Cordillera" in h[12] and "Mayon" in h[16] and h[17].startswith("B1.") and h[37].startswith("Levels")
LV = ["Not at all", "A little", "Somewhat", "Well", "Very well"]
DIMS = ["Language", "Persons", "Metaphors", "Content", "Concepts", "Goals", "Methods", "Context"]
val = lambda x: None if str(x).startswith("CJ") else int(str(x)[0])   # "CJ (Cannot Judge)" -> None
L = [f"Panelists: {len(d)}", "", "| Setting | " + " | ".join(LV) + " |", "|---" * 6 + "|"]
for j in FAM:
    L.append(f"| {h[j].split('[')[-1].rstrip(']')} | " + " | ".join(str(sum(r[j] == l for r in d)) for l in LV) + " |")
L += ["", "| Item | n | Median | Range | Agree | Neutral | Disagree | Cannot judge |", "|---" * 8 + "|"]
fmt = lambda x: f"{x:g}"
for k, j in enumerate(ITEMS, 1):
    v = [val(r[j]) for r in d]; w = [x for x in v if x is not None]
    if k <= 16 and k % 2 == 1:   # dimension row before its two items
        sc = [st.mean([x for x in (val(r[j]), val(r[j + 1])) if x is not None]) for r in d]
        L.append(f"| **{DIMS[(k-1)//2]}** | {len(sc)} | {fmt(st.median(sc))} | {fmt(min(sc))}–{fmt(max(sc))} | "
                 f"{sum(s >= 4 for s in sc)} | — | {sum(s < 3 for s in sc)} | 0 |")
    L.append(f"| {k} | {len(w)} | {fmt(st.median(w))} | {min(w)}–{max(w)} | {sum(x >= 4 for x in w)} | "
             f"{sum(x == 3 for x in w)} | {sum(x <= 2 for x in w)} | {v.count(None)} |")
L += ["", "Overall assessment:"]
for a in sorted(set(r[44] for r in d)):
    L.append(f"- {a}: {sum(r[44] == a for r in d)}")
L += ["", "Materials reviewed:"] + [f"- P{i}: {r[11]}" for i, r in enumerate(d, 1)]
out = "\n".join(L) + "\n"
open(sys.argv[2], "w", encoding="utf-8", newline="\n").write(out) if len(sys.argv) > 2 else print(out)
