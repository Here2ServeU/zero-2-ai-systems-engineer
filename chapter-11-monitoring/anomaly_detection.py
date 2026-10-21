# anomaly_detection.py
import numpy as np

def detect_anomaly(data, threshold=2.0):
    mean = np.mean(data)
    std = np.std(data)
    anomalies = []
    for i, value in enumerate(data):
        if abs(value - mean) > threshold * std:
            anomalies.append({
                'index': i,
                'value': value,
                'zscore': abs(value-mean)/std
            })
    return anomalies

# Simulate API latency readings:
latencies = [0.10, 0.09, 0.11, 0.10, 0.12,
             0.09, 2.50, 0.11, 0.10, 0.09]
anomalies = detect_anomaly(latencies)
for a in anomalies:
    print(f'Anomaly at index {a["index"]}: '
          f'{a["value"]}s (z={a["zscore"]:.2f})')
