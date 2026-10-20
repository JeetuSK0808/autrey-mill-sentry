#!/bin/bash
# Bundle the v4 models into the app after tools/run_training_chain_v4.sh finishes (both V4 and V4B CHAIN DONE).
# Copies models, writes labels/thresholds/embeddings/model card, regenerates the local species catalog, runs the unit tests.
set -e
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
P="model/.venv/bin/python -I"
RES=AutreyMillSentry/Resources
grep -q "V4B CHAIN DONE" data/logs/train_v4.log || { echo "chain not finished"; exit 1; }
rm -rf $RES/InvasiveClassifier.mlpackage $RES/InvasiveClassifierB.mlpackage
cp -R build/model_v4/InvasiveClassifier.mlpackage $RES/InvasiveClassifier.mlpackage
cp -R build/model_v4/InvasiveClassifierB.mlpackage $RES/InvasiveClassifierB.mlpackage
$P - <<'PY'
import json, torch, pathlib
ck = torch.load("model/checkpoints/v4_best.pt", map_location="cpu", weights_only=False)
json.dump({"version": "v4", "labels": ck["labels"]}, open("AutreyMillSentry/Resources/labels.json", "w"))
print("labels.json", len(ck["labels"]))
PY
# field-aware calibration and confirm floors: degraded val/test logits, then re-evaluate both models with --field-val
for V in v4 v4b; do
  $P model/field_logits.py --version $V --split val | tail -1
  $P model/field_logits.py --version $V --split test | tail -1
  $P model/evaluate.py --version $V --target-precision 0.98 --no-bundle --field-val | grep -E 'temperature|confirm threshold|degraded test'
done
cp model/eval/v4_thresholds.json $RES/thresholds.json
$P model/compute_centroids.py --version v4 --keep 0.90 --bundle | tail -1
$P model/compare_models.py v4b v4 --write-card | tail -1
$P model/eval_holdout.py v4b v4 | tail -2 || true
$P model/sweep_possible.py v4b v4 | tail -3 || true
python3 -I tools/gen_local_species.py
~/miniforge3/bin/python3 -I tools/attribution_summary.py | tail -1
tools/build_sim.sh test 2>&1 | grep -E 'error:|Executed .* tests|TEST (SUCC|FAIL)' | tail -2
echo "BUNDLE DONE $(date)"
