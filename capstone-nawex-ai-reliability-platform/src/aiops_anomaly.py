"""AIOps anomaly detector for platform telemetry.

Wires Week 11 (AIOps) into the capstone. Reads recent latency and
error-rate samples (synthetic for the scaffold), fits an Isolation
Forest, and flags spikes that an oncall engineer should look at.
"""

import numpy as np
from sklearn.ensemble import IsolationForest


def synthetic_telemetry(n: int = 200, seed: int = 7) -> np.ndarray:
    rng = np.random.default_rng(seed)
    latency = rng.normal(0.150, 0.02, size=n)
    error_rate = rng.normal(0.005, 0.001, size=n).clip(min=0)
    spikes = rng.choice(n, size=4, replace=False)
    latency[spikes] = rng.uniform(0.8, 1.2, size=4)
    error_rate[spikes] = rng.uniform(0.05, 0.10, size=4)
    return np.column_stack([latency, error_rate])


def main() -> None:
    telemetry = synthetic_telemetry()
    model = IsolationForest(contamination=0.03, random_state=42)
    flags = model.fit_predict(telemetry)
    incident_idx = np.where(flags == -1)[0]
    print(f"Flagged {len(incident_idx)} incidents at indices: {incident_idx.tolist()}")
    for i in incident_idx:
        latency_ms = telemetry[i, 0] * 1000
        error_pct = telemetry[i, 1] * 100
        print(f"  t={i}  latency={latency_ms:.0f}ms  error_rate={error_pct:.2f}%")


if __name__ == "__main__":
    main()
