"""Tabulate the PLAY expert design review: ratings, severities, problems."""
import sys, json, re, statistics as st, openpyxl
ws=openpyxl.load_workbook(sys.argv[1],data_only=True).worksheets[0]
rows=[r for r in ws.iter_rows(values_only=True)]
hdr, data = rows[0], [r for r in rows[1:] if any(c is not None for c in r)]
rate={}; sev={}
for j,h in enumerate(hdr):
    if not h: continue
    m=re.match(r"Rating for each principle \[(I{1,3}-[A-I]\d): (.*)\]$", h, re.S)
    if m: rate[m.group(1)]=(j,m.group(2).strip())
    m=re.match(r"Severity \(only for items rated P or N\) \[(I{1,3}-[A-I]\d)\]", h)
    if m: sev[m.group(1)]=j
assert len(rate)==50 and set(rate)==set(sev), (len(rate), set(rate)^set(sev))
codes=list(rate)  # form order
rev=[]
for i,r in enumerate(data):
    rev.append(dict(id=f"R{i+1}", submitted=str(r[0])[:16], materials=r[1], role=r[5], years=r[6], played=r[8],
        completed=str(r[10])[:10], ratings={c:r[rate[c][0]] for c in codes}, sev={c:r[sev[c]] for c in codes},
        overall=r[hdr.index("In two or three sentences, state your overall judgement of the design as presented, and the single change you would make first.")]))
cat=lambda c: c.split("-")[0]
heur=lambda c: c[:-1]
NAMES={"I-A":"Enduring Play","I-B":"Challenge, Strategy and Pace","I-C":"Consistency in Game World","I-D":"Goals",
 "I-E":"Variety of Players and Game Styles","I-F":"Players' Perception of Control","II-A":"Emotional Connection",
 "II-B":"Coolness/Entertainment","II-C":"Humor","II-D":"Immersion","III-A":"Documentation/Tutorial","III-B":"Status and Score",
 "III-C":"Game Provides Feedback","III-D":"Terminology","III-E":"Burden on Player","III-F":"Screen Layout","III-G":"Navigation",
 "III-H":"Error Prevention","III-I":"Game Story Immersion"}
per={}
for c in codes:
    rs=[x["ratings"][c] for x in rev]
    svs=[x["sev"][c] for x in rev if x["ratings"][c] in ("P","N") and x["sev"][c] is not None]
    per[c]=dict(text=rate[c][1], M=rs.count("M"),P=rs.count("P"),N=rs.count("N"),CA=rs.count("CA"),
        sev=svs, mean_sev=(st.mean(svs) if svs else None), by=[x["id"]+":"+x["ratings"][c] for x in rev if x["ratings"][c]!="M"])
oddsev=[(x["id"],c,x["sev"][c]) for x in rev for c in codes if x["ratings"][c]=="M" and x["sev"][c] not in (None,0,0.0)]
def agg(keyf):
    out={}
    for c in codes:
        k=keyf(c); d=out.setdefault(k,dict(M=0,P=0,N=0,CA=0,items=0))
        d["items"]+=1
        for t in ("M","P","N","CA"): d[t]+=per[c][t]
    return out
byrev={x["id"]:{t:list(x["ratings"].values()).count(t) for t in ("M","P","N","CA")} for x in rev}
res=dict(reviewers=[{k:v for k,v in x.items() if k not in("ratings","sev")} for x in rev], per_principle=per,
    by_heuristic=agg(heur), by_category=agg(cat), by_reviewer=byrev, severity_on_met_items=oddsev, names=NAMES,
    totals={t:sum(per[c][t] for c in codes) for t in ("M","P","N","CA")})
json.dump(res,open(sys.argv[2],"w",encoding="utf-8",newline="\n"),indent=1,default=str)
for c in codes:
    p=per[c]
    if p["M"]<len(rev): print(c, p["M"],p["P"],p["N"],p["CA"], "sev",p["sev"], p["by"])
print(res["totals"], byrev); print("by cat", res["by_category"]); print("sev on met:",oddsev)
for h,d in res["by_heuristic"].items(): print(h, NAMES[h], d)

# ---- Markdown output, so the tables can be rebuilt when another review arrives ----
if len(sys.argv) > 3:
    n=len(rev); L=[]
    pct=lambda d: int(100*d["M"]/(d["M"]+d["P"]+d["N"]+d["CA"])+0.5)  # half up, not to even
    T=res["totals"]; allr=sum(T.values())
    L.append(f"Reviewers: {n}. Ratings: {allr}. Met {T['M']} ({pct(T)}%), Partially met {T['P']}, Not met {T['N']}, Cannot assess {T['CA']}.")
    L.append(f"Principles Met by all {n}: {sum(per[c]['M']==n for c in codes)} of 50. Most reviewers below Met on one principle: {max(n-per[c]['M'] for c in codes)}.")
    L.append("By reviewer: " + "; ".join(f"{k}: P {v['P']}, N {v['N']}, CA {v['CA']}" for k,v in byrev.items()))
    L.append("Severity entered on Met items (not counted): " + (", ".join(f"{a} {b} ({c:g})" for a,b,c in oddsev) or "none"))
    L.append("")
    L.append("| Category and heuristic | Principles | Met | Partially met | Not met | Cannot assess | Met (%) |")
    L.append("|---|---|---|---|---|---|---|")
    CAT={"I":"I. Game Play","II":"II. Coolness, Entertainment, Humour and Emotional Immersion","III":"III. Usability and Game Mechanics"}
    for ck,cn in CAT.items():
        d=res["by_category"][ck]; L.append(f"| **{cn}** | **{d['items']}** | **{d['M']}** | **{d['P']}** | **{d['N']}** | **{d['CA']}** | **{pct(d)}** |")
        for h,dd in res["by_heuristic"].items():
            if h.split('-')[0]==ck: L.append(f"| {h.split('-')[1]}. {NAMES[h]} | {dd['items']} | {dd['M']} | {dd['P']} | {dd['N']} | {dd['CA']} | {pct(dd)} |")
    L.append(f"| **All** | **50** | **{T['M']}** | **{T['P']}** | **{T['N']}** | **{T['CA']}** | **{pct(T)}** |")
    L.append(""); L.append("| Principle | Ratings below Met | Severities |"); L.append("|---|---|---|")
    for c in codes:
        p=per[c]
        if p["M"]<n:
            sv=[ (f"{x['sev'][c]:g}" if x['ratings'][c] in ('P','N') and x['sev'][c] is not None else '—') for x in rev if x['ratings'][c]!='M']
            L.append(f"| {c} | {', '.join(b.replace(':',' ') for b in p['by'])} | {', '.join(sv)} |")
    L.append(""); L.append("Overall judgements:")
    for x in rev: L.append(f"- {x['id']} ({x['role']}, {x['years']} years, played: {x['played']}): {str(x['overall']).strip()}")
    open(sys.argv[3],"w",encoding="utf-8",newline="\n").write("\n".join(L)+"\n")
