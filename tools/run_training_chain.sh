#!/bin/bash
# Waits for the dataset download, then trains, evaluates and exports v1. Logs to data/logs/train_v1.log
cd "$(dirname "$0")/.."
export VECLIB_MAXIMUM_THREADS=1
while pgrep -f "tools/fetch_inat.py" >/dev/null; do sleep 60; done
echo "download finished $(date)" > data/logs/train_v1.log
~/miniforge3/bin/python3 -I tools/attribution_summary.py >> data/logs/train_v1.log 2>&1
nice -n 10 model/.venv/bin/python -I model/train.py --epochs 14 --version v1 --workers 4 >> data/logs/train_v1.log 2>&1 || { echo "TRAIN FAILED" >> data/logs/train_v1.log; exit 1; }
nice -n 10 model/.venv/bin/python -I model/evaluate.py --version v1 --target-precision 0.95 >> data/logs/train_v1.log 2>&1 || { echo "EVAL FAILED" >> data/logs/train_v1.log; exit 1; }
nice -n 10 model/.venv/bin/python -I model/export_coreml.py --version v1 >> data/logs/train_v1.log 2>&1 || { echo "EXPORT FAILED" >> data/logs/train_v1.log; exit 1; }
echo "CHAIN DONE $(date)" >> data/logs/train_v1.log
