# app_with_metrics.py
from flask import Flask, request, jsonify
from prometheus_client import (
    Counter, Histogram, start_http_server
)
import time

app = Flask(__name__)

REQUEST_COUNT = Counter(
    'api_requests_total',
    'Total API requests',
    ['method','endpoint','status']
)
REQUEST_LATENCY = Histogram(
    'api_request_duration_seconds',
    'Request duration in seconds'
)

start_http_server(8000)

@app.route('/health')
def health():
    REQUEST_COUNT.labels(
        method='GET',endpoint='/health',
        status='200').inc()
    return jsonify({'status':'healthy'})

@app.route('/predict', methods=['POST'])
def predict():
    start = time.time()
    data = request.get_json()
    result = 1 if data.get('amount',0) > 800 else 0
    latency = time.time() - start
    REQUEST_LATENCY.observe(latency)
    REQUEST_COUNT.labels(
        method='POST',endpoint='/predict',
        status='200').inc()
    return jsonify({'prediction':result})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
