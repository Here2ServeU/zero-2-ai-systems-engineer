"""Promote a model artifact through staging stages.

Wires Week 13 (Advanced Deployment and Model Promotion) into the
capstone. Real promotion would update the MLflow Model Registry and
flip a Kubernetes Service selector; this scaffold writes the staging
state to a registry JSON so the rest of the platform has something
to read.
"""

import argparse
import datetime as dt
import json

import paths

REGISTRY = paths.ARTIFACTS_DIR / "registry.json"
STAGES = ("staging", "canary", "production", "rollback")


def load() -> dict:
    if REGISTRY.exists():
        return json.loads(REGISTRY.read_text())
    return {"fraud": {}, "anomaly": {}}


def save(data: dict) -> None:
    paths.ARTIFACTS_DIR.mkdir(parents=True, exist_ok=True)
    REGISTRY.write_text(json.dumps(data, indent=2))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", required=True, choices=["fraud", "anomaly"])
    parser.add_argument("--stage", required=True, choices=STAGES)
    parser.add_argument("--version", required=True)
    args = parser.parse_args()

    registry = load()
    registry[args.model][args.stage] = {
        "version": args.version,
        "promoted_at": dt.datetime.utcnow().isoformat(timespec="seconds") + "Z",
    }
    save(registry)
    print(f"{args.model} {args.version} -> {args.stage}")


if __name__ == "__main__":
    main()
