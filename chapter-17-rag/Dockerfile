# Dockerfile: Chapter 17's RAG pipeline as a web API (rag_api.py).
#
# Two size/speed tricks:
#   1. CPU-only PyTorch (the GPU build is ~4 GB bigger and EKS nodes have no GPU)
#   2. The embedding model is downloaded at BUILD time, so pods start fast and
#      never need to reach the model website.
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HF_HOME=/opt/hf \
    HF_HUB_OFFLINE=1 \
    ANONYMIZED_TELEMETRY=False \
    HOME=/tmp

WORKDIR /app
RUN pip install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cpu
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

RUN HF_HUB_OFFLINE=0 python -c "from sentence_transformers import SentenceTransformer; SentenceTransformer('all-MiniLM-L6-v2')"

COPY knowledge_base.txt index_corpus.py retrieval.py rag_query.py rag_api.py ./

RUN useradd -m -u 1000 appuser && mkdir -p /app/vector_db && chown 1000:1000 /app/vector_db
USER 1000

EXPOSE 5000
# Build the index, then serve. (On Kubernetes, an init container builds it.)
CMD ["sh", "-c", "python index_corpus.py && python rag_api.py"]
