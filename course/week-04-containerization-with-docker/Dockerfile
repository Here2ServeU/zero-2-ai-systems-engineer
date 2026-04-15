FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY course/week-01-foundations course/week-01-foundations
COPY course/week-03-serving-models-via-apis course/week-03-serving-models-via-apis

WORKDIR /app/course/week-03-serving-models-via-apis/src

EXPOSE 8000

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
