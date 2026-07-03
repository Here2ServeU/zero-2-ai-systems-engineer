# generate_data.py
import pandas as pd
import numpy as np, os

HERE = os.path.dirname(os.path.abspath(__file__))
# scripts live in src/, so the data folder is one level up: ../data
DATA_DIR = os.path.join(HERE, '..', 'data')

np.random.seed(42)        # reproducibility — same rows every time
n = 1000                  # number of synthetic transactions

amounts  = np.random.exponential(scale=200, size=n)
times    = np.random.uniform(0, 24, size=n)
# A purchase is "fraud" when it is both big and in the dead of night:
# over 500 dollars AND before 5 a.m. -> 18 fake purchases out of 1000.
is_fraud = ((amounts > 500) & (times < 5)).astype(int)

df = pd.DataFrame({
    'amount':   amounts.round(2),
    'time':     times.round(2),
    'is_fraud': is_fraud
})
os.makedirs(DATA_DIR, exist_ok=True)
df.to_csv(os.path.join(DATA_DIR, 'transactions.csv'), index=False)
print(f'Generated {len(df)} rows, {is_fraud.sum()} fraud')
