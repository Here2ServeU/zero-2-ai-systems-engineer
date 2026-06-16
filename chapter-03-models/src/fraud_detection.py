# fraud_detection.py
import pandas as pd
from sklearn.tree import DecisionTreeClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import (
    classification_report, confusion_matrix,
    accuracy_score)

df = pd.read_csv('../data/fintech_transactions.csv')
X = df[['amount','time_of_day','merchant_loc']]
y = df['is_fraud']

X_tr,X_te,y_tr,y_te = train_test_split(
    X, y, test_size=0.2,
    random_state=42, stratify=y)

model = DecisionTreeClassifier(
    max_depth=6, min_samples_split=5,
    random_state=42)
model.fit(X_tr, y_tr)
y_pred = model.predict(X_te)

print(f'Accuracy: {accuracy_score(y_te,y_pred):.3f}')
print(classification_report(
    y_te, y_pred,
    target_names=['Legitimate','Fraud']))

cm = confusion_matrix(y_te, y_pred)
print(f'True Positives (fraud caught): {cm[1][1]}')
print(f'False Negatives (fraud missed): {cm[1][0]}')
print(f'False Positives (false alarms): {cm[0][1]}')
