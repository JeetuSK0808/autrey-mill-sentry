#!/usr/bin/env python3
"""Summarise a scan_diagnostics.json exported from the phone (Reports > gear > Developer > Export scan diagnostics):
what the live loop saw (light, sharpness, subject size, gates, lock states, torch, focus pass) and what every
captured still decided. Usage: python3 -I tools/field_report.py ~/Downloads/scan_diagnostics.json"""
import json, sys, collections, statistics as st
snap = json.load(open(sys.argv[1]))
live, stills = snap.get("recentLive", []), snap.get("loggedStills") or snap.get("stills", [])
print(f"model {snap.get('modelVersion')}  frames {snap.get('frames')}  classified {snap.get('classified')}  exported {snap.get('exportedAt')}")
if live:
    q = lambda k: [s[k] for s in live if k in s]
    def band(v): return "dark" if v < 0.16 else "dim" if v < 0.3 else "ok" if v < 0.7 else "bright"
    print(f"\nLIVE ({len(live)} recent frames)")
    print(" light   :", dict(collections.Counter(band(v) for v in q("luma"))), f" median luma {st.median(q('luma')):.2f}")
    print(" sharp   :", f"median {st.median(q('sharp')):.0f}  <10 (blurry) {sum(v < 10 for v in q('sharp'))}")
    print(" subject :", f"median {st.median(q('subject')):.2f}  <0.04 (far) {sum(v < 0.04 for v in q('subject'))}")
    print(" motion  :", f"median {st.median(q('motion')):.2f}  >0.3 {sum(v > 0.3 for v in q('motion'))}")
    print(" hard gate:", dict(collections.Counter(s.get("hard") or "-" for s in live)))
    print(" soft gate:", dict(collections.Counter(s.get("soft") or "-" for s in live)))
    print(" lock     :", dict(collections.Counter((s.get("lock") or "").split(" ")[0] for s in live)), f" median lock p {st.median(q('lockP')) if q('lockP') else 'n/a'}")
    print(" torch    :", sum(bool(s.get("torch")) for s in live), " focus pass:", sum(bool(s.get("focus")) for s in live))
    tops = collections.Counter(t.rsplit(" ", 1)[0] if t else "-" for s in live for t in s.get("top", [])[:1])
    print(" top guess:", tops.most_common(8))
if stills:
    print(f"\nSTILLS ({len(stills)})")
    for s in stills[-12:]:
        print(f" {s.get('source','?'):6s} sharp {s.get('sharp',0):4.0f} luma {s.get('luma',0):.2f} subj {s.get('subject',0):.2f} -> {s.get('outcome','?'):28s} top {' | '.join(s.get('top', [])[:3])}" + (f"  sim {s['similarity']:.2f}/{s.get('floor',0):.2f}" if s.get('similarity') is not None else ""))
    print(" outcomes:", dict(collections.Counter((s.get("outcome") or "").split(" ")[0] for s in stills)))
