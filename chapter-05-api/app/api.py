# api.py
from flask import Flask, request, jsonify
from model import load_model, predict_one, FEATURES
import uuid, logging, datetime

logging.basicConfig(level=logging.INFO,
    format='%(asctime)s %(levelname)s %(message)s')
log = logging.getLogger(__name__)

app   = Flask(__name__)
model = load_model()

REQUIRED = {f: (int,float) if f in
    ['amount','amount_vs_avg'] else int
    for f in FEATURES}

def validate(data):
    errors = []
    for field, types in REQUIRED.items():
        if field not in data:
            errors.append(f'Missing: {field}')
        elif not isinstance(data[field], types):
            errors.append(f'Wrong type: {field}')
    h = data.get('hour')
    if h is not None and not 0 <= h <= 23:
        errors.append('hour must be 0-23')
    return errors

@app.route('/health')
def health():
    return jsonify({'status':'healthy',
        'ts':datetime.datetime.utcnow().isoformat()})

@app.route('/info')
def info():
    return jsonify({'name':'Nawex Fraud API',
        'version':'1.0.0',
        'author':'Rev Dr Emmanuel Naweji',
        'program':'Zero2AI'})

@app.route('/predict', methods=['POST'])
def predict():
    rid = str(uuid.uuid4())[:8]
    log.info(f'[{rid}] Request received')
    data = request.get_json(silent=True)
    if not data:
        return jsonify({'error':'Body must be JSON',
            'req_id':rid}), 400
    errors = validate(data)
    if errors:
        return jsonify({'error':'Validation failed',
            'details':errors,'req_id':rid}), 422
    result = predict_one(model, data)
    result.update({'req_id':rid,
        'ts':datetime.datetime.utcnow().isoformat()})
    log.info(f'[{rid}] Prediction: {result["label"]}')
    return jsonify(result), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
