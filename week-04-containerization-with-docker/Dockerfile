FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY week-01-foundations week-01-foundations
COPY week-03-serving-models-via-apis week-03-serving-models-via-apis

WORKDIR /app/week-03-serving-models-via-apis/src

EXPOSE 8000

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
