# rag_api.py
# Puts Chapter 17's RAG pipeline behind a small web API, so it can run on
# Kubernetes like the other chapters' apps.
#   GET  /health  -> {"status": "healthy"}
#   POST /ask     -> {"question": "..."}  =>  answer + the passages it used
#
# The search index (./vector_db) must already exist: run index_corpus.py first.
# On Kubernetes an init container does that before this app starts.
from flask import Flask, request, jsonify
import logging, uuid

logging.basicConfig(level=logging.INFO,
    format='%(asctime)s %(levelname)s %(message)s')
log = logging.getLogger(__name__)

from rag_query import answer   # loads the index + embedding model once

app = Flask(__name__)


@app.route('/health')
def health():
    return jsonify({'status': 'healthy'})


@app.route('/ask', methods=['POST'])
def ask():
    rid = str(uuid.uuid4())[:8]
    data = request.get_json(silent=True) or {}
    question = data.get('question', '').strip()
    if not question:
        return jsonify({'error': 'Missing question', 'request_id': rid}), 422
    log.info(f'[{rid}] Q: {question[:60]}')
    try:
        result = answer(question)
    except Exception as e:
        log.error(f'[{rid}] Failed: {e}')
        return jsonify({'error': 'RAG call failed', 'request_id': rid}), 503
    result['request_id'] = rid
    return jsonify(result)


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
