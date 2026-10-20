#!/bin/bash
# v4: 75 local native classes added (189 classes), trail-camera augmentation (--field-aug). Waits for the fetch, then
# trains the B0 primary, evaluates, embeds, computes centroids, exports, and runs the field-conditions eval.
cd "$(dirname "$0")/.."
export VECLIB_MAXIMUM_THREADS=1
LOG=data/logs/train_v4.log
until grep -q "FETCH CHAIN DONE" data/logs/fetch_local_natives.log 2>/dev/null; do sleep 60; done
while pgrep -f "tools/fetch_inat.py" >/dev/null; do sleep 30; done
echo "fetch finished $(date)" > $LOG
~/miniforge3/bin/python3 -I tools/attribution_summary.py >> $LOG 2>&1
P="nice -n 10 model/.venv/bin/python -I"
$P model/train.py --arch efficientnet_b0 --size 256 --epochs 24 --version v4 --workers 5 --field-aug >> $LOG 2>&1 || { echo "TRAIN FAILED" >> $LOG; exit 1; }
$P model/evaluate.py --version v4 --target-precision 0.98 --no-bundle >> $LOG 2>&1 || { echo "EVAL FAILED" >> $LOG; exit 1; }
$P model/embed.py --version v4 >> $LOG 2>&1 || { echo "EMBED FAILED" >> $LOG; exit 1; }
$P model/compute_centroids.py --version v4 --keep 0.90 >> $LOG 2>&1 || { echo "CENTROIDS FAILED" >> $LOG; exit 1; }
mkdir -p build/model_v4
$P model/export_coreml.py --version v4 --out build/model_v4/InvasiveClassifier.mlpackage --no-labels >> $LOG 2>&1 || { echo "EXPORT FAILED" >> $LOG; exit 1; }
$P model/field_eval.py --version v4 --n 1500 >> $LOG 2>&1 || { echo "FIELD EVAL FAILED" >> $LOG; exit 1; }
echo "V4 CHAIN DONE $(date)" >> $LOG
# second model for the still-image ensemble: EfficientNet-B2 at 288, same classes and augmentation
$P model/train.py --arch efficientnet_b2 --size 288 --epochs 22 --version v4b --workers 5 --field-aug --batch 48 >> $LOG 2>&1 || { echo "TRAIN v4b FAILED" >> $LOG; exit 1; }
$P model/evaluate.py --version v4b --target-precision 0.98 --no-bundle >> $LOG 2>&1 || { echo "EVAL v4b FAILED" >> $LOG; exit 1; }
$P model/export_coreml.py --version v4b --out build/model_v4/InvasiveClassifierB.mlpackage --no-labels >> $LOG 2>&1 || { echo "EXPORT v4b FAILED" >> $LOG; exit 1; }
$P model/field_eval.py --version v4b --n 1500 >> $LOG 2>&1
$P model/field_eval.py --version v4 --ensemble v4b --n 1500 >> $LOG 2>&1
echo "V4B CHAIN DONE $(date)" >> $LOG
