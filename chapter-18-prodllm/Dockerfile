# Dockerfile: Chapter 18's production LLM service.
# Port 5000 = /llm and /health, port 8000 = Prometheus metrics.
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY production_llm.py .

RUN useradd -m -u 1000 appuser
USER 1000

EXPOSE 5000 8000
CMD ["python", "production_llm.py"]
