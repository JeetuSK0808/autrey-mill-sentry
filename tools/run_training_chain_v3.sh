#!/bin/bash
# v3: waits for the cultivated-plant fetch, then trains, evaluates (no bundling), embeds, computes centroids and
# exports to a side path. Bundling is a separate decision after comparing with v2. Log: data/logs/train_v3.log
cd "$(dirname "$0")/.."
export VECLIB_MAXIMUM_THREADS=1
until grep -q "\[other_plant/cultivated\] done" data/logs/fetch_inat_v3.log 2>/dev/null; do sleep 60; done
while pgrep -f "tools/fetch_inat.py" >/dev/null; do sleep 30; done
echo "fetch finished $(date)" > data/logs/train_v3.log
~/miniforge3/bin/python3 -I tools/attribution_summary.py >> data/logs/train_v3.log 2>&1
nice -n 10 model/.venv/bin/python -I model/train.py --arch efficientnet_b0 --size 256 --epochs 22 --version v3 --workers 4 >> data/logs/train_v3.log 2>&1 || { echo "TRAIN FAILED" >> data/logs/train_v3.log; exit 1; }
nice -n 10 model/.venv/bin/python -I model/evaluate.py --version v3 --target-precision 0.98 --no-bundle >> data/logs/train_v3.log 2>&1 || { echo "EVAL FAILED" >> data/logs/train_v3.log; exit 1; }
nice -n 10 model/.venv/bin/python -I model/embed.py --version v3 >> data/logs/train_v3.log 2>&1 || { echo "EMBED FAILED" >> data/logs/train_v3.log; exit 1; }
nice -n 10 model/.venv/bin/python -I model/compute_centroids.py --version v3 --keep 0.90 >> data/logs/train_v3.log 2>&1 || { echo "CENTROIDS FAILED" >> data/logs/train_v3.log; exit 1; }
mkdir -p build/model_v3
nice -n 10 model/.venv/bin/python -I model/export_coreml.py --version v3 --out build/model_v3/InvasiveClassifier.mlpackage >> data/logs/train_v3.log 2>&1 || { echo "EXPORT FAILED" >> data/logs/train_v3.log; exit 1; }
echo "V3 CHAIN DONE $(date)" >> data/logs/train_v3.log
