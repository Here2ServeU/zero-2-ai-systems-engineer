# Dockerfile: Chapter 16's chat API. One image for all three robot companies;
# the command picks which: llm_api.py (Claude), llm_api_openai.py, llm_api_gemini.py.
# API keys are NEVER baked in: Kubernetes passes them in as environment variables.
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY llm_api.py llm_api_openai.py llm_api_gemini.py ./

RUN useradd -m -u 1000 appuser
USER 1000

EXPOSE 5000
CMD ["python", "llm_api.py"]
