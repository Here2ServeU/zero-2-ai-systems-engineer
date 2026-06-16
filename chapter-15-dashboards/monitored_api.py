# monitored_api.py
from flask import Flask, request, jsonify
from prometheus_client import (
    Counter, Histogram, Gauge,
    start_http_server
)
import time, random

app = Flask(__name__)

FRAUD_PREDICTIONS = Counter(
    'fraud_predictions_total',
    'Total fraud predictions',
    ['result']
)
MODEL_LATENCY = Histogram(
    'model_inference_seconds',
    'Model inference time',
    buckets=[.001,.005,.01,.05,.1,.25,.5,1,2]
)
ACTIVE_REQUESTS = Gauge(
    'active_requests',
    'Number of requests being processed'
)

start_http_server(8000)

@app.route('/predict', methods=['POST'])
def predict():
    ACTIVE_REQUESTS.inc()
    start = time.time()
    data = request.get_json() or {}
    amount = data.get('amount', 0)
    hour = data.get('hour', 12)
    time.sleep(random.uniform(0.001, 0.01))
    is_fraud = (amount > 800 and hour < 6)
    label = 'fraud' if is_fraud else 'legit'
    MODEL_LATENCY.observe(time.time() - start)
    FRAUD_PREDICTIONS.labels(result=label).inc()
    ACTIVE_REQUESTS.dec()
    return jsonify({'prediction':int(is_fraud),
        'label':label})

@app.route('/health')
def health():
    return jsonify({'status':'healthy'})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
