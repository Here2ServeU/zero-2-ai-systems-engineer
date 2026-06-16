# aiops_engine.py
import numpy as np

def detect_anomaly(metrics, threshold=2.0):
    mean = np.mean(metrics)
    std = np.std(metrics) or 0.001
    return [
        (i, v, abs(v-mean)/std)
        for i, v in enumerate(metrics)
        if abs(v-mean)/std > threshold
    ]

def analyze_trend(metrics):
    if len(metrics) < 3:
        return 0.0
    x = np.arange(len(metrics))
    slope = np.polyfit(x, metrics, 1)[0]
    return slope

def predict_failure(cpu, mem):
    cpu_anom = detect_anomaly(cpu)
    mem_anom = detect_anomaly(mem)
    cpu_trend = analyze_trend(cpu)
    mem_trend = analyze_trend(mem)

    warnings = []
    if cpu_anom:
        warnings.append(
            f'CPU spike: {cpu_anom[-1][1]:.1f}%'
        )
    if mem_anom:
        warnings.append(
            f'Memory spike: {mem_anom[-1][1]:.1f}%'
        )
    if cpu_trend > 1.5:
        warnings.append(
            f'CPU trend up: {cpu_trend:.1f}%/reading'
        )
    if mem_trend > 1.5:
        warnings.append(
            f'Mem trend up: {mem_trend:.1f}%/reading'
        )

    if warnings:
        return {'status':'WARNING',
            'warnings': warnings,
            'action':'Scale up now'}
    return {'status':'STABLE','warnings':[],
        'action':'No action needed'}

# Simulate system metrics over time:
cpu = [45,47,46,48,50,52,55,60,65,
       70,72,75,80,85,91]
mem = [60,61,60,62,63,64,65,66,68,
       70,72,75,80,85,92]

result = predict_failure(cpu, mem)
print(f'Status: {result["status"]}')
for w in result['warnings']:
    print(f'  WARNING: {w}')
print(f'Action: {result["action"]}')
