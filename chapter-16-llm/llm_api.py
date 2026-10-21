# llm_api.py
from flask import Flask, request, jsonify
import anthropic, os, uuid, logging
from datetime import datetime

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s %(message)s')
log = logging.getLogger(__name__)

app = Flask(__name__)
client = anthropic.Anthropic(
    api_key=os.environ['ANTHROPIC_API_KEY'])

SYSTEM_PROMPT = (
    'You are a helpful customer support agent '
    'for Zero2AI Bank. Answer in two short '
    'paragraphs. If the question is outside '
    'banking topics, politely decline.')

@app.route('/chat', methods=['POST'])
def chat():
    rid = str(uuid.uuid4())[:8]
    data = request.get_json(silent=True) or {}
    question = data.get('question','').strip()
    if not question:
        return jsonify({
            'error':'Missing question',
            'request_id':rid}), 422
    log.info(f'[{rid}] Q: {question[:60]}')
    msg = client.messages.create(
        model='claude-opus-4-7',
        max_tokens=512,
        system=SYSTEM_PROMPT,
        messages=[
            {'role':'user','content':question}
        ])
    answer = msg.content[0].text
    log.info(f'[{rid}] tokens in/out: '
        f'{msg.usage.input_tokens}/'
        f'{msg.usage.output_tokens}')
    return jsonify({
        'answer': answer,
        'tokens_in': msg.usage.input_tokens,
        'tokens_out': msg.usage.output_tokens,
        'request_id': rid,
        'ts': datetime.utcnow().isoformat()})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
