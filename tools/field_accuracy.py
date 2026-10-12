#!/usr/bin/env python3
"""Compute field accuracy from the app's Field Test CSV export and write it into the model card.

Usage: python3 -I tools/field_accuracy.py ~/Downloads/field_test.csv
Writes model/eval/field_test.json and updates AutreyMillSentry/Resources/model_card.json (fieldAccuracy, fieldPhotos).
Rules: only rows with a true label count; a prediction is correct when predicted_label == true_label, and a
"needs expert review" prediction is scored separately (it is not a species claim).
"""
import csv, json, sys, pathlib, time
ROOT = pathlib.Path(__file__).resolve().parent.parent
src = pathlib.Path(sys.argv[1])
rows = [r for r in csv.DictReader(open(src)) if r.get("true_label")]
if not rows:
    raise SystemExit("no labelled rows")
claims = [r for r in rows if r["needs_expert_review"] != "true"]
correct = sum(1 for r in claims if r["predicted_label"] == r["true_label"])
expert = [r for r in rows if r["needs_expert_review"] == "true"]
expert_true_invasive = sum(1 for r in expert if r["true_label"] not in ("other_plant", "not_plant") and not r["true_label"].startswith(("lonicera_sempervirens", "wisteria_frutescens", "viburnum", "ilex_opaca", "toxicodendron", "parthenocissus", "vitis", "rosa_carolina", "rubus_argutus", "mitchella", "catalpa", "chasmanthium", "smilax")))
per = {}
for r in rows:
    d = per.setdefault(r["true_label"], {"n": 0, "correct": 0, "expert": 0})
    d["n"] += 1
    if r["needs_expert_review"] == "true": d["expert"] += 1
    elif r["predicted_label"] == r["true_label"]: d["correct"] += 1
out = {"source": str(src), "computedOn": time.strftime("%Y-%m-%d"), "labelledPhotos": len(rows), "speciesClaims": len(claims),
       "claimAccuracy": correct / max(len(claims), 1), "sentToExpertReview": len(expert), "expertReviewTrueInvasive": expert_true_invasive,
       "overallCorrectOrDeferred": (correct + len(expert)) / len(rows), "perTrueLabel": per,
       "note": "claimAccuracy = fraction of species claims (not expert-review) that matched the checker's label. Field conditions, phone camera, labels by a person who knows the plants."}
(ROOT / "model" / "eval").mkdir(parents=True, exist_ok=True)
json.dump(out, open(ROOT / "model" / "eval" / "field_test.json", "w"), indent=1)
card_p = ROOT / "AutreyMillSentry" / "Resources" / "model_card.json"
card = json.load(open(card_p))
card["fieldAccuracy"] = out["claimAccuracy"]; card["fieldPhotos"] = len(rows)
json.dump(card, open(card_p, "w"), indent=1)
print(json.dumps({k: v for k, v in out.items() if k != "perTrueLabel"}, indent=1))
