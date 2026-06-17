# llm_api_gemini.py
# Same /chat endpoint as llm_api.py, but powered by Google Gemini.
from flask import Flask, request, jsonify
from google import genai
from google.genai import types
import os, uuid, logging
from datetime import datetime

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s %(message)s')
log = logging.getLogger(__name__)

app = Flask(__name__)
client = genai.Client(api_key=os.environ['GEMINI_API_KEY'])

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
    resp = client.models.generate_content(
        model='gemini-2.5-flash',
        contents=question,
        config=types.GenerateContentConfig(
            system_instruction=SYSTEM_PROMPT,
            max_output_tokens=512))
    answer = resp.text
    tokens_in = resp.usage_metadata.prompt_token_count
    tokens_out = resp.usage_metadata.candidates_token_count
    log.info(f'[{rid}] tokens in/out: {tokens_in}/{tokens_out}')
    return jsonify({
        'answer': answer,
        'tokens_in': tokens_in,
        'tokens_out': tokens_out,
        'request_id': rid,
        'ts': datetime.utcnow().isoformat()})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
