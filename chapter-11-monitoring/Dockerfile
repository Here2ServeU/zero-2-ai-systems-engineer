# Dockerfile: packs app_with_metrics.py (Chapter 11) the Chapter 06 way.
# Port 5000 = the app, port 8000 = Prometheus metrics.
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app_with_metrics.py anomaly_detection.py ./

RUN useradd -m -u 1000 appuser
USER 1000

EXPOSE 5000 8000
CMD ["python", "app_with_metrics.py"]
