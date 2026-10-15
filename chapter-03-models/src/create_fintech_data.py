# create_fintech_data.py
import pandas as pd, numpy as np, os
np.random.seed(42); n = 2000

amounts   = np.random.exponential(150, n)
times     = np.random.uniform(0, 24, n)
locations = np.random.randint(0, 50, n)
is_fraud  = ((amounts>600)&((times<5)|(times>23))).astype(int)

df = pd.DataFrame({'amount':amounts.round(2),
    'time_of_day':times.round(2),
    'merchant_loc':locations,
    'is_fraud':is_fraud})

data_dir = os.path.join(os.path.dirname(__file__), '..', 'data')
os.makedirs(data_dir, exist_ok=True)
df.to_csv(os.path.join(data_dir, 'fintech_transactions.csv'), index=False)
print(f'{len(df)} transactions, {is_fraud.sum()} fraud')
