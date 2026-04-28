from __future__ import annotations

import json
from pathlib import Path

import pandas as pd
from sklearn.tree import DecisionTreeClassifier


DATA_PATH = (
    Path(__file__).resolve().parents[2]
    / "week-01-foundations"
    / "data"
    / "system_metrics.csv"
)
OUTPUT_PATH = Path(__file__).resolve().parent / "retraining_report.json"


def retrain() -> dict:
    data = pd.read_csv(DATA_PATH)
    model = DecisionTreeClassifier(random_state=42)
    features = data[["cpu", "memory", "latency"]]
    labels = data["healthy"]
    model.fit(features, labels)
    return {
        "rows_used": len(data),
        "feature_names": list(features.columns),
        "tree_depth": model.get_depth(),
        "leaf_count": model.get_n_leaves(),
    }


if __name__ == "__main__":
    report = retrain()
    OUTPUT_PATH.write_text(json.dumps(report, indent=2))
    print(json.dumps(report, indent=2))
