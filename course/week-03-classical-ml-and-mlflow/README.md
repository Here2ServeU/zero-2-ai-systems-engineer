# Week 3 - Classical ML and Experiment Tracking with MLflow

> Chapter 4 of *Zero 2 AI Systems Engineer*. Layer 2 — Data & Models.

## Objective

Build the first production-style classical machine learning models for the platform — a fraud detection classifier (FinTech) and an anomaly detection model (Healthcare) — and track every training run in MLflow so each model is reproducible and auditable.

## What I Will Build

- A fraud detection model trained on transaction-style data
- An anomaly detection model trained on patient/system monitoring data
- An MLflow experiment that records parameters, metrics, and artifacts for every run
- A reproducible training script that other weeks (API, Docker, Kubernetes) consume

## Use Cases

### FinTech

Detect fraudulent transactions on a synthetic transaction stream.

### Healthcare

Flag anomalous patient vitals or device telemetry for clinician review.

## Outcome

Two trained model artifacts plus an MLflow run history that proves what was trained, on what data, with what parameters, and how well it scored.

## Local Run

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python3 course/week-03-classical-ml-and-mlflow/src/train_fraud_model.py
python3 course/week-03-classical-ml-and-mlflow/src/train_anomaly_model.py
mlflow ui --backend-store-uri ./mlruns
```

## Layered Position

- Depends on: Week 1 (Foundations), Week 2 (Regulated Environments)
- Feeds into: Week 4 (Serving Models via APIs), Week 5 (Containerization), Week 12 (Retraining Pipelines)
