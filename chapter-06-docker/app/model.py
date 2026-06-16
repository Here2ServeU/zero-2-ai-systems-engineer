# model.py
import numpy as np
from sklearn.tree import DecisionTreeClassifier
from sklearn.model_selection import train_test_split

MODEL_VERSION = 'v1.0.0'
FEATURES = ['amount','hour','is_weekend',
    'amount_vs_avg','is_large_txn',
    'is_late_night','merch_txn_ct']

def load_model():
    np.random.seed(42); n = 2000
    import pandas as pd
    df = pd.DataFrame({
        'amount':       np.random.exponential(200,n),
        'hour':         np.random.randint(0,24,n),
        'is_weekend':   np.random.randint(0,2,n),
        'amount_vs_avg':np.random.uniform(0.5,3,n),
        'is_large_txn': (np.random.rand(n)>0.9).astype(int),
        'is_late_night':(np.random.rand(n)>0.85).astype(int),
        'merch_txn_ct': np.random.randint(1,100,n),
        'is_fraud': (np.random.rand(n)<0.05).astype(int)
    })
    X = df[FEATURES]; y = df['is_fraud']
    X_tr,X_te,y_tr,y_te = train_test_split(
        X,y,test_size=0.2,random_state=42)
    clf = DecisionTreeClassifier(max_depth=6,random_state=42)
    clf.fit(X_tr, y_tr)
    print(f'Model accuracy: {clf.score(X_te, y_te):.3f}')
    return clf

def predict_one(model, data):
    row = [[data[f] for f in FEATURES]]
    pred = int(model.predict(row)[0])
    proba = model.predict_proba(row)[0]
    return {
        'prediction': pred,
        'label': 'FRAUD' if pred==1 else 'LEGIT',
        'confidence': round(float(max(proba)), 4),
        'model_version': MODEL_VERSION
    }
