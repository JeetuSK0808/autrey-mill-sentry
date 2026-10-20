#!/bin/bash
# Replacement second model: the B2@288 partner would take most of a day on this shared Mac, so v4b is a second
# EfficientNet-B0 @256 with a different seed (18 epochs, same classes and augmentation). Waits for V4 CHAIN DONE,
# stops the original chain's v4b step, then trains, evaluates, exports and runs the field eval.
cd "$(dirname "$0")/.."
export VECLIB_MAXIMUM_THREADS=1
LOG=data/logs/train_v4.log
until grep -q "V4 CHAIN DONE" $LOG 2>/dev/null; do sleep 60; done
sleep 5
pkill -f "tools/run_training_chain_v4.sh" 2>/dev/null
pkill -f "model/train.py .*--version v4b" 2>/dev/null
sleep 5
# loader workers of the stopped v4b run: children of a dead parent, from this project's venv only
for p in $(pgrep -f "autrey-mill-sentry/model/.venv/bin/python -I -c from multiprocessing"); do
  pp=$(ps -o ppid= -p $p | tr -d ' '); kill -0 "$pp" 2>/dev/null || kill -9 $p 2>/dev/null
done
echo "v4b (B0 seed 1) chain start $(date)" >> $LOG
P="nice -n 10 model/.venv/bin/python -I"
$P model/train.py --arch efficientnet_b0 --size 256 --epochs 18 --version v4b --workers 5 --field-aug --seed 1 >> $LOG 2>&1 || { echo "TRAIN v4b FAILED" >> $LOG; exit 1; }
$P model/evaluate.py --version v4b --target-precision 0.98 --no-bundle >> $LOG 2>&1 || { echo "EVAL v4b FAILED" >> $LOG; exit 1; }
mkdir -p build/model_v4
$P model/export_coreml.py --version v4b --out build/model_v4/InvasiveClassifierB.mlpackage --no-labels >> $LOG 2>&1 || { echo "EXPORT v4b FAILED" >> $LOG; exit 1; }
$P model/field_eval.py --version v4b --n 1500 >> $LOG 2>&1
$P model/field_eval.py --version v4 --ensemble v4b --n 1500 >> $LOG 2>&1
echo "V4B CHAIN DONE $(date)" >> $LOG
