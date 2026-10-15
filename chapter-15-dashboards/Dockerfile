# Dockerfile (follows the Chapter 6 containerization pattern so the
# docker-compose stack in this chapter has an image to build).
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY monitored_api.py .

RUN useradd -m appuser
USER appuser

EXPOSE 5000 8000
CMD ["python", "monitored_api.py"]
