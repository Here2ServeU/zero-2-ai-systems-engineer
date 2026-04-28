FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY capstone-nawex-ai-reliability-platform capstone-nawex-ai-reliability-platform

WORKDIR /app/capstone-nawex-ai-reliability-platform/src

EXPOSE 8080

CMD ["python", "serve.py"]
