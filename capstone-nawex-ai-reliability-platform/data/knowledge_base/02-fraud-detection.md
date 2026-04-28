# Fraud Detection Pipeline

The fraud detection model is a Random Forest classifier trained on transaction features: amount, hour-of-day, merchant risk score, and country risk score. Every training run is logged to MLflow with parameters, metrics, and the resulting model artifact.

The model is served through a Flask `/predict/fraud` endpoint that accepts a JSON payload of transaction features and returns a probability of fraud plus a binary decision. The endpoint enforces input validation, structured logging, and per-request latency tracking exposed at `/metrics` for Prometheus to scrape.

When drift is detected — defined as a meaningful shift in the input feature distribution compared to the training distribution — the retraining pipeline triggers automatically. The new model is staged through a canary rollout before being promoted to full production traffic.
