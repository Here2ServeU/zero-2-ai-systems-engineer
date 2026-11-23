# Dockerfile: the Chapter 12 AIOps engine as a container.
# Default command = the laptop demo (simulated numbers).
# The cloud track runs aiops_watcher.py instead (real Prometheus numbers).
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY aiops_engine.py automated_response.py aiops_watcher.py ./

RUN useradd -m -u 1000 appuser
USER 1000

CMD ["python", "automated_response.py"]
