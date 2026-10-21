# production_llm.py
from flask import Flask, request, jsonify
from prometheus_client import (
    Counter, Histogram, start_http_server)
from tenacity import (
    retry, stop_after_attempt,
    wait_exponential)
import anthropic, os, time, hashlib
import logging, uuid

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s %(message)s')
log = logging.getLogger(__name__)

CALLS = Counter('llm_calls_total',
    'Total LLM API calls', ['status'])
TOKENS = Counter('llm_tokens_total',
    'Total tokens used', ['type'])
LATENCY = Histogram('llm_latency_seconds',
    'LLM API latency in seconds')

client = anthropic.Anthropic(
    api_key=os.environ['ANTHROPIC_API_KEY'])

CACHE = {}
USER_BUDGETS = {}
DAILY_TOKEN_LIMIT = 50000

BLOCKED_PATTERNS = ['ssn:', 'credit card:',
    'password:', 'api key:']

def is_safe_input(text):
    lower = text.lower()
    for p in BLOCKED_PATTERNS:
        if p in lower:
            return False
    return True

def cache_key(prompt):
    return hashlib.sha256(
        prompt.encode()).hexdigest()

@retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential(
        multiplier=1, min=2, max=30))
def call_anthropic(prompt):
    return client.messages.create(
        model='claude-opus-4-7',
        max_tokens=512,
        messages=[
            {'role':'user','content':prompt}
        ])

app = Flask(__name__)
start_http_server(8000)

@app.route('/llm', methods=['POST'])
def llm():
    rid = str(uuid.uuid4())[:8]
    data = request.get_json(silent=True) or {}
    user_id = data.get('user_id','anonymous')
    prompt = data.get('prompt','').strip()
    if not prompt:
        return jsonify({
            'error':'Missing prompt',
            'request_id':rid}), 422
    if not is_safe_input(prompt):
        log.warning(f'[{rid}] Blocked input')
        CALLS.labels(status='blocked').inc()
        return jsonify({
            'error':'Input rejected by safety filter',
            'request_id':rid}), 422
    used = USER_BUDGETS.get(user_id, 0)
    if used >= DAILY_TOKEN_LIMIT:
        log.warning(f'[{rid}] Budget exceeded '
            f'for {user_id}')
        CALLS.labels(status='budget_exceeded').inc()
        return jsonify({
            'error':'Daily token budget exceeded',
            'request_id':rid}), 429
    key = cache_key(prompt)
    if key in CACHE:
        log.info(f'[{rid}] Cache hit')
        CALLS.labels(status='cache_hit').inc()
        return jsonify({
            **CACHE[key],
            'cached':True,
            'request_id':rid})
    start = time.time()
    try:
        msg = call_anthropic(prompt)
    except Exception as e:
        log.error(f'[{rid}] Failed: {e}')
        CALLS.labels(status='error').inc()
        return jsonify({
            'error':'LLM call failed',
            'request_id':rid}), 503
    LATENCY.observe(time.time() - start)
    in_t = msg.usage.input_tokens
    out_t = msg.usage.output_tokens
    TOKENS.labels(type='input').inc(in_t)
    TOKENS.labels(type='output').inc(out_t)
    USER_BUDGETS[user_id] = used + in_t + out_t
    CALLS.labels(status='success').inc()
    response = {
        'answer': msg.content[0].text,
        'tokens_in': in_t,
        'tokens_out': out_t,
        'cached': False,
        'request_id': rid}
    CACHE[key] = {
        'answer': response['answer'],
        'tokens_in': in_t,
        'tokens_out': out_t}
    log.info(f'[{rid}] Success: '
        f'{in_t}/{out_t} tokens')
    return jsonify(response)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
