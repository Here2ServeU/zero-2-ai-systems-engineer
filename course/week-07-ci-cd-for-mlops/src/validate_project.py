from __future__ import annotations

import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def run(command: list[str]) -> None:
    completed = subprocess.run(command, cwd=ROOT, check=False)
    if completed.returncode != 0:
        raise SystemExit(completed.returncode)


if __name__ == "__main__":
    run([sys.executable, "week-01-foundations/src/train_model.py"])
    run([sys.executable, "week-02-regulated-environments/src/generate_risk_report.py"])
    run([sys.executable, "week-10-aiops/src/detect_anomalies.py"])
