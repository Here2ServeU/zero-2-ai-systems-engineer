"""Drift detector. Compares live feature stats to the training stats.

Wires Layer 7 (Continuous Delivery) into the capstone. Returns exit
code 0 when distributions are aligned, exit code 1 when drift is
detected — the CI pipeline reads the exit code to decide whether to
open a retraining PR.
"""

import json
import sys

import pandas as pd

import paths

DRIFT_THRESHOLD = 0.25  # mean shift threshold per feature


def main() -> int:
    if not paths.TRAIN_FEATURE_STATS.exists():
        print("No training stats found. Run train_models.py first.")
        return 2

    stats = json.loads(paths.TRAIN_FEATURE_STATS.read_text())
    live = pd.read_csv(paths.DRIFT_CSV)

    drifted = []
    for feature, ref in stats.items():
        if feature not in live.columns:
            continue
        ref_mean = ref["mean"]
        live_mean = float(live[feature].mean())
        denom = max(abs(ref_mean), 1.0)
        relative_shift = abs(live_mean - ref_mean) / denom
        if relative_shift > DRIFT_THRESHOLD:
            drifted.append((feature, ref_mean, live_mean, relative_shift))

    if not drifted:
        print("No drift detected.")
        return 0

    print("Drift detected:")
    for feature, ref_mean, live_mean, shift in drifted:
        print(f"  {feature}: ref={ref_mean:.3f} live={live_mean:.3f} shift={shift:.0%}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
