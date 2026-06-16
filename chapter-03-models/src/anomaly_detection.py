# anomaly_detection.py
import pandas as pd, numpy as np
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler

np.random.seed(42); n = 1500
hr  = np.random.normal(75, 10, n)
bp  = np.random.normal(120, 15, n)
tmp = np.random.normal(98.6, 0.7, n)
o2  = np.random.normal(98, 1.5, n)

# inject realistic anomalies
idx = np.random.choice(n, 50, replace=False)
hr[idx] += np.random.choice([40, -35], 50)
bp[idx] += np.random.choice([60, -50], 50)

df = pd.DataFrame({'heart_rate':hr.round(1),
    'blood_pressure':bp.round(1),
    'temperature':tmp.round(1),
    'oxygen_sat':o2.round(1)})

X = df.values
X_scaled = StandardScaler().fit_transform(X)
preds = IsolationForest(
    contamination=0.04,
    random_state=42).fit_predict(X_scaled)

n_anom = (preds == -1).sum()
print(f'Normal: {(preds == 1).sum()}')
print(f'Anomalies: {n_anom} ({n_anom/n*100:.1f}%)')
