# Dockerfile: Chapter 13's drift check + retraining as one container.
# Runs drift_detector.py, then retrain_pipeline.py (which fails the job if
# the new model's recall is too low: a weak model never gets promoted).
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HOME=/tmp \
    MLFLOW_TRACKING_URI=file:///tmp/mlruns

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY drift_detector.py retrain_pipeline.py ./

RUN useradd -m -u 1000 appuser
USER 1000

CMD ["sh", "-c", "python drift_detector.py && python retrain_pipeline.py"]
