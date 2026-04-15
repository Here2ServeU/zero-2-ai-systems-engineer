# Week 1 - Foundations of Production AI Systems

## Objective

Understand how AI systems operate in real-world environments and build a simple system health prediction model.

## What I Built

- Dataset from system metrics (CPU, memory, latency)
- Basic ML model to predict system health
- Initial structure for FinTech and Healthcare use cases

## Use Cases

### FinTech

Predict system failure in transaction systems

### Healthcare

Predict anomalies in patient/system monitoring

## Outcome

A working ML model that predicts system health conditions.

## Local Run

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python3 course/week-01-foundations/src/train_model.py
```

## Deployment Path

- Package the service with Docker
- Deploy it with Helm on Kubernetes
- Extend monitoring with Prometheus and Grafana
