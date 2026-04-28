from __future__ import annotations

import json
from datetime import datetime, UTC


def snapshot() -> dict:
    return {
        "timestamp": datetime.now(UTC).isoformat(),
        "service": "system-health-api",
        "metrics": {
            "requests_total": 128,
            "prediction_latency_ms_p95": 142,
            "error_rate": 0.01,
            "healthy_predictions": 96,
        },
    }


if __name__ == "__main__":
    print(json.dumps(snapshot(), indent=2))
