# Dockerfile
FROM python:3.11-slim

LABEL maintainer="Rev Dr Emmanuel Naweji"
LABEL program="Zero2AI"
LABEL version="1.0.0"

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV FLASK_ENV=production

WORKDIR /app

# Copy requirements FIRST so Docker can cache the pip
# install layer. Subsequent code changes will not
# invalidate the dependency install step.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ .

# Security: never run production containers as root.
RUN useradd -m appuser
USER appuser

EXPOSE 5000
CMD ["python", "api.py"]
