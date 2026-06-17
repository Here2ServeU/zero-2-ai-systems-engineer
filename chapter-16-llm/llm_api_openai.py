# llm_api_openai.py
# Same /chat endpoint as llm_api.py, but powered by OpenAI.
from flask import Flask, request, jsonify
from openai import OpenAI
import os, uuid, logging
from datetime import datetime

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s %(message)s')
log = logging.getLogger(__name__)

app = Flask(__name__)
client = OpenAI(api_key=os.environ['OPENAI_API_KEY'])

SYSTEM_PROMPT = (
    'You are a helpful customer support agent '
    'for Zero2AI Bank. Answer in two short '
    'paragraphs. If the question is outside '
    'banking topics, politely decline.')

@app.route('/chat', methods=['POST'])
def chat():
    rid = str(uuid.uuid4())[:8]
    data = request.get_json(silent=True) or {}
    question = data.get('question', '').strip()
    if not question:
        return jsonify({
            'error': 'Missing question',
            'request_id': rid}), 422
    log.info(f'[{rid}] Q: {question[:60]}')
    resp = client.chat.completions.create(
        model='gpt-4o',
        max_tokens=512,
        messages=[
            {'role': 'system', 'content': SYSTEM_PROMPT},
            {'role': 'user', 'content': question}
        ])
    answer = resp.choices[0].message.content
    tokens_in = resp.usage.prompt_tokens
    tokens_out = resp.usage.completion_tokens
    log.info(f'[{rid}] tokens in/out: {tokens_in}/{tokens_out}')
    return jsonify({
        'answer': answer,
        'tokens_in': tokens_in,
        'tokens_out': tokens_out,
        'request_id': rid,
        'ts': datetime.utcnow().isoformat()})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
