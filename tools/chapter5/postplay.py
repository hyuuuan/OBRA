"""Score the post-play questionnaire (SUS, UEQ-S, IEQ-SF, GEQ x3, Godspeed Animacy, QUESI)."""
import sys, json, math, statistics as st
import openpyxl
from datetime import datetime
from scipy import stats

path = sys.argv[1]
ws = openpyxl.load_workbook(path, data_only=True).worksheets[0]
rows = [r for r in ws.iter_rows(values_only=True)]
hdr, data = rows[0], [r for r in rows[1:] if any(c is not None for c in r)]

# Column layout (0-based): 0 ts, 1 code, 2 email, 3-12 SUS, 13-20 UEQ-S, 21-31 IEQ-SF,
# 32-47 GEQ, 48-53 Godspeed, 54-56 QUESI, 57 age, 58 habit, 59 consent
SUS, UEQ, IEQ, GEQ, GOD, QUE = range(3,13), range(13,21), range(21,32), range(32,48), range(48,54), range(54,57)
assert "frequently" in hdr[3] and "get going" in hdr[12]
assert hdr[13].startswith("1. Obstructive") and hdr[20].startswith("8. Usual")
assert "focused" in hdr[21] and "suspense" in hdr[31]
assert "content" in hdr[32] and "rich experience" in hdr[47]
assert hdr[48].startswith("1. Dead") and hdr[53].startswith("6. Apathetic")
assert "familiar" in hdr[54] and "automatically" in hdr[56]

# Spreadsheet rows (1-based, header = row 1) removed on the team's instruction, with the reason.
EXCLUDE_ROWS = {
    8: "pilot; identical on all 54 items to row 7 and at the maximum throughout; the team identified it "
       "as a friend answering for fun (20 Nov). Row 7 is kept, being the earlier submission.",
}

def code(r):
    return str(r[1]).strip().replace(".0","") if r[1] is not None else ""

recs = []
for i, r in enumerate(data):
    ts = r[0] if isinstance(r[0], datetime) else datetime.fromisoformat(str(r[0]))
    c = code(r)
    if c.lower() == "test":
        grp = "test"
    elif i+2 in EXCLUDE_ROWS:
        grp = "excluded"
    elif ts < datetime(2026,11,16):
        grp = "pilot"                      # includes "R08" (14 Nov), a pilot player per the team
    else:
        grp = "main"
    recs.append(dict(row=i+2, ts=ts, code=c, grp=grp, r=r))

# Duplicate codes in the main group: keep the first submission.
seen = {}
for x in recs:
    if x["grp"] != "main": continue
    if x["code"] in seen:
        x["grp"] = "main_duplicate"; x["dup_of"] = seen[x["code"]]
    else:
        seen[x["code"]] = x["row"]

def score(r):
    v = lambda k: float(r[k])
    sus = sum((v(k)-1) if (k-3)%2==0 else (5-v(k)) for k in SUS)*2.5
    ueq = [v(k)-4 for k in UEQ]
    ieq = [v(k) for k in IEQ]
    ieq[4] = 6-ieq[4]; ieq[9] = 6-ieq[9]          # items 5 and 10 reverse-scored
    geq = [v(k) for k in GEQ]
    god = [v(k) for k in GOD]; que = [v(k) for k in QUE]
    return dict(
        SUS=sus, UEQ_PQ=st.mean(ueq[:4]), UEQ_HQ=st.mean(ueq[4:]),
        IEQ=st.mean(ieq), IEQ_Inv=st.mean(ieq[:4]), IEQ_RWD=st.mean(ieq[4:8]), IEQ_Chal=st.mean(ieq[8:]),
        GEQ_PA=st.mean(geq[:5]), GEQ_Comp=st.mean(geq[5:10]), GEQ_SII=st.mean(geq[10:]),
        Animacy=st.mean(god), QUESI=st.mean(que)), dict(ueq=ueq, ieq=ieq, geq=geq, god=god, que=que,
        sus_items=[v(k) for k in SUS])

RANGES = [(SUS,1,5,"SUS"),(UEQ,1,7,"UEQ-S"),(IEQ,1,5,"IEQ-SF"),(GEQ,0,4,"GEQ"),(GOD,1,5,"Godspeed"),(QUE,1,5,"QUESI")]
def problems(r):
    out=[]
    for rng,lo,hi,name in RANGES:
        for k in rng:
            if r[k] is None: out.append(f"{name} item {k-rng.start+1} blank")
            elif not (lo <= r[k] <= hi): out.append(f"{name} item {k-rng.start+1} = {r[k]:g}, outside {lo}-{hi}")
    sus = [r[k] for k in SUS]
    if len(set(sus))==1: out.append(f"SUS straight-lined (all {sus[0]:g}, positive and negative items alike)")
    return out

for x in recs:
    x["problems"] = problems(x["r"])
    x["scores"], x["items"] = score(x["r"]) if not any("blank" in p or "outside" in p for p in x["problems"]) else (None,None)
    x["age"] = x["r"][57]; x["habit"] = x["r"][58]

def ci(vals):
    n=len(vals); m=st.mean(vals); sd=st.stdev(vals) if n>1 else float("nan")
    h = stats.t.ppf(0.975, n-1)*sd/math.sqrt(n) if n>1 else float("nan")
    return dict(n=n, mean=m, sd=sd, lo=m-h, hi=m+h, median=st.median(vals), min=min(vals), max=max(vals))

def alpha(itemrows):
    k=len(itemrows[0]);
    if len(itemrows)<3: return float("nan")
    cols=list(zip(*itemrows)); iv=sum(st.variance(c) for c in cols); tv=st.variance([sum(r) for r in itemrows])
    return k/(k-1)*(1-iv/tv) if tv>0 else float("nan")

def summarise(group_names, label):
    xs=[x for x in recs if x["grp"] in group_names]
    ok=[x for x in xs if x["scores"]]
    res={"label":label,"n_rows":len(xs),"n_scored":len(ok),"excluded":[(x["code"],x["problems"]) for x in xs if not x["scores"]]}
    for key in ok[0]["scores"]:
        res[key]=ci([x["scores"][key] for x in ok])
    it=lambda name, sl=slice(None): [x["items"][name][sl] for x in ok]
    res["alpha"]=dict(SUS=alpha([[ (v-1) if j%2==0 else (5-v) for j,v in enumerate(x["items"]["sus_items"])] for x in ok]),
        UEQ_PQ=alpha(it("ueq",slice(0,4))), UEQ_HQ=alpha(it("ueq",slice(4,8))),
        IEQ=alpha(it("ieq")), IEQ_Inv=alpha(it("ieq",slice(0,4))), IEQ_RWD=alpha(it("ieq",slice(4,8))), IEQ_Chal=alpha(it("ieq",slice(8,11))),
        GEQ_PA=alpha(it("geq",slice(0,5))), GEQ_Comp=alpha(it("geq",slice(5,10))), GEQ_SII=alpha(it("geq",slice(10,16))),
        Animacy=alpha(it("god")), QUESI=alpha(it("que")))
    sus=[x["scores"]["SUS"] for x in ok]
    res["SUS_above_68"]=sum(s>68 for s in sus); res["SUS_at_or_above_68"]=sum(s>=68 for s in sus)
    for k in ("UEQ_PQ","UEQ_HQ"):
        v=[x["scores"][k] for x in ok]
        res[k+"_bands"]=dict(positive=sum(a>0.8 for a in v), neutral=sum(-0.8<=a<=0.8 for a in v), negative=sum(a<-0.8 for a in v))
    # item means
    res["items"]=dict(
        SUS=[st.mean(x["items"]["sus_items"][j] for x in ok) for j in range(10)],
        UEQ=[st.mean(x["items"]["ueq"][j] for x in ok) for j in range(8)],
        IEQ_raw=[st.mean(float(x["r"][21+j]) for x in ok) for j in range(11)],
        GEQ=[st.mean(x["items"]["geq"][j] for x in ok) for j in range(16)],
        GOD=[st.mean(x["items"]["god"][j] for x in ok) for j in range(6)],
        QUE=[st.mean(x["items"]["que"][j] for x in ok) for j in range(3)])
    ages=[x["age"] for x in xs if isinstance(x["age"],(int,float))]
    res["age"]=dict(n=len(ages), median=st.median(ages) if ages else None, min=min(ages) if ages else None, max=max(ages) if ages else None,
                    counts={int(a):ages.count(a) for a in sorted(set(ages))})
    hab={}
    for x in xs: hab[x["habit"] or "(blank)"]=hab.get(x["habit"] or "(blank)",0)+1
    res["habit"]=hab
    res["dates"]=sorted({x["ts"].strftime("%Y-%m-%d") for x in xs})
    res["date_counts"]={d:sum(x["ts"].strftime("%Y-%m-%d")==d for x in xs) for d in res["dates"]}
    res["per_respondent"]=[dict(row=x["row"],code=x["code"],ts=x["ts"].isoformat(timespec="minutes"),**({k:round(v,3) for k,v in x["scores"].items()} if x["scores"] else {}),problems=x["problems"]) for x in xs]
    return res

out = dict(
    groups={g:sum(x["grp"]==g for x in recs) for g in ("main","main_duplicate","pilot","excluded","test")},
    excluded={r:EXCLUDE_ROWS[r] for r in EXCLUDE_ROWS},
    duplicates=[(x["code"],x["row"],x.get("dup_of")) for x in recs if x["grp"]=="main_duplicate"],
    main=summarise({"main"},"Main study (first response per ID)"),
    main_dup_last=None,
    pilot=summarise({"pilot"},"Pilot"),
    all_problem_rows=[(x["row"],x["grp"],x["code"],x["problems"]) for x in recs if x["problems"]],
)
# Sensitivity: use the duplicate's later response instead of the first
for x in recs:
    if x["grp"]=="main_duplicate": x["grp"]="main_alt"
    elif x["grp"]=="main" and x["code"] in [d[0] for d in out["duplicates"]]: x["grp"]="main_first_dup"
alt = summarise({"main","main_alt"},"Main, later duplicate kept")
out["main_dup_last"]={k:alt[k] for k in alt if k not in("per_respondent","items")}
# Sensitivity: drop main-study rows with problems flagged but still scorable (straight-lined SUS)
for x in recs:
    if x["grp"]=="main_alt": x["grp"]="main_duplicate"
    elif x["grp"]=="main_first_dup": x["grp"]="main"
json.dump(out, open(sys.argv[2],"w",encoding="utf-8",newline="\n"), indent=1, default=str)

# Optional third argument: an anonymised CSV of every scored respondent (codes only, no names or IDs),
# safe to share inside the team. Main study = Q01..Q34 in order of submission; pilot = QP01..QP10.
if len(sys.argv) > 3:
    import csv
    keys = ["SUS","UEQ_PQ","UEQ_HQ","IEQ","IEQ_Inv","IEQ_RWD","IEQ_Chal","GEQ_PA","GEQ_Comp","GEQ_SII","Animacy","QUESI"]
    with open(sys.argv[3], "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f); w.writerow(["code","group","submitted","age","habit"] + keys + ["flags"])
        for grp, prefix in (("main","Q"),("pilot","QP")):
            xs = [x for x in recs if x["grp"] == grp]
            for n, x in enumerate(xs, 1):
                w.writerow([f"{prefix}{n:02d}", "main study" if grp=="main" else "pilot",
                            x["ts"].strftime("%Y-%m-%d %H:%M"), x["age"] or "", x["habit"] or ""]
                           + [round(x["scores"][k], 3) for k in keys] + ["; ".join(x["problems"])])
print(json.dumps({k:out[k] for k in ("groups","duplicates","all_problem_rows")}, indent=1, default=str))
