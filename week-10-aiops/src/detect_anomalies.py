from __future__ import annotations

from pathlib import Path

import pandas as pd


DATA_PATH = Path(__file__).resolve().parent.parent / "data" / "operations_metrics.csv"


def detect_anomalies() -> pd.DataFrame:
    data = pd.read_csv(DATA_PATH)
    thresholds = {"cpu": 85, "memory": 90, "latency": 450}
    mask = (
        (data["cpu"] >= thresholds["cpu"])
        | (data["memory"] >= thresholds["memory"])
        | (data["latency"] >= thresholds["latency"])
    )
    return data.loc[mask]


if __name__ == "__main__":
    anomalies = detect_anomalies()
    print(anomalies.to_string(index=False))
