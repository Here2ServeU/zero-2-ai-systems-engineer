from __future__ import annotations

import json
from pathlib import Path


def build_report() -> dict:
    data_path = Path(__file__).resolve().parent.parent / "data" / "compliance_controls.json"
    controls = json.loads(data_path.read_text())
    return {
        "week": 2,
        "focus": "regulated environments",
        "domains": [
            {
                "name": domain,
                "control_count": len(items),
                "controls": items,
            }
            for domain, items in controls.items()
        ],
    }


if __name__ == "__main__":
    report = build_report()
    print(json.dumps(report, indent=2))
