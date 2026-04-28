from __future__ import annotations

import json
from pathlib import Path


OUTPUT_PATH = (
    Path(__file__).resolve().parent.parent
    / "dashboards"
    / "system_health_dashboard.json"
)


def build_spec() -> dict:
    return {
        "title": "System Health Dashboard",
        "panels": [
            {"name": "Request Volume", "metric": "requests_total"},
            {"name": "Latency P95", "metric": "prediction_latency_ms_p95"},
            {"name": "Error Rate", "metric": "error_rate"},
            {"name": "Healthy Predictions", "metric": "healthy_predictions"},
        ],
    }


if __name__ == "__main__":
    spec = build_spec()
    OUTPUT_PATH.write_text(json.dumps(spec, indent=2))
    print(json.dumps(spec, indent=2))
