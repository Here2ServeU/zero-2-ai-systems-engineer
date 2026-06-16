# drift_detector.py
import numpy as np
from scipy import stats

def detect_drift(baseline, current, threshold=0.05):
    stat, pvalue = stats.ks_2samp(baseline, current)
    drift_detected = pvalue < threshold
    return {
        'drift_detected': drift_detected,
        'ks_statistic': round(stat, 4),
        'p_value': round(pvalue, 4),
        'interpretation': (
            'DRIFT DETECTED: retrain required'
            if drift_detected else
            'No significant drift'
        )
    }

# Simulate: baseline vs new data
baseline = np.random.normal(200, 50, 1000)
new_data = np.random.normal(300, 70, 500)
result   = detect_drift(baseline, new_data)
print(result)
