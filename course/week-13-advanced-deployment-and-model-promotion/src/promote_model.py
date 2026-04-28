from __future__ import annotations

import json
from pathlib import Path


REGISTRY_PATH = Path(__file__).resolve().parent.parent / "data" / "model_registry.json"


def promote(source_stage: str, target_stage: str) -> dict:
    registry = json.loads(REGISTRY_PATH.read_text())
    registry[target_stage] = registry[source_stage]
    REGISTRY_PATH.write_text(json.dumps(registry, indent=2))
    return registry


if __name__ == "__main__":
    updated = promote("staging", "production")
    print(json.dumps(updated, indent=2))
