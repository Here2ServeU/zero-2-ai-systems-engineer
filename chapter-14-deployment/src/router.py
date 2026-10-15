# router.py
import random
from models import old_model, new_model

usage = {'old':0, 'new':0}
CANARY = 0.20

def route_request(data):
    if random.random() < CANARY:
        usage['new'] += 1
        return 'new_model', new_model(data)
    usage['old'] += 1
    return 'old_model', old_model(data)

def get_usage_stats():
    total = usage['old'] + usage['new'] or 1
    return {
        'old_pct': usage['old']/total*100,
        'new_pct': usage['new']/total*100,
        'total': total
    }
