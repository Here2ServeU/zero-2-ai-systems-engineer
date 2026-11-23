# Dockerfile: an MLflow tracking server (the "tidy notebook" from Chapter 04)
# that can store model files in S3. boto3 is what lets it talk to S3; it gets
# AWS permissions from EKS Pod Identity, so no keys are baked in.
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HOME=/tmp

RUN pip install --no-cache-dir "mlflow==2.22.0" boto3

RUN useradd -m -u 1000 appuser
USER 1000
WORKDIR /data

EXPOSE 5000
# The chart passes the real arguments (where to keep runs and artifacts).
CMD ["mlflow", "server", "--host", "0.0.0.0", "--port", "5000"]
