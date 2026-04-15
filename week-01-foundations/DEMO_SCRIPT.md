# Week 1 Demo Script

## Introduction

"Today I built a simple production AI system that predicts system health based on CPU, memory, and latency."

## Show Code

Open VS Code and show:

- `week-01-foundations/data/system_metrics.csv`
- `week-01-foundations/src/train_model.py`

Explain:

"This model learns patterns between system metrics and system health."

## Run It

Run:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python3 week-01-foundations/src/train_model.py
```

Explain the output and highlight the prediction result.

## Connect to Real World

"This applies to FinTech systems where we detect transaction system failures, and healthcare systems where we detect anomalies early."

## Close

"This is Week 1 of my journey building production AI systems."
