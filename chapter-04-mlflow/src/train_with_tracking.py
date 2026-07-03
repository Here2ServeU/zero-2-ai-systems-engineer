# train_with_tracking.py
import os
import pandas as pd, mlflow, mlflow.sklearn, argparse
from sklearn.tree import DecisionTreeClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import (
    accuracy_score, precision_score,
    recall_score, f1_score
)

parser = argparse.ArgumentParser()
parser.add_argument('--max_depth', type=int, default=5)
parser.add_argument('--min_samples', type=int, default=2)
# nargs='?' means the value is optional: leave the flag off and it's 'gini';
# write just --criterion (no value) and it's 'entropy'; or pick one yourself.
parser.add_argument('--criterion', nargs='?',
                    default='gini', const='entropy')
args = parser.parse_args()

DATA_PATH = os.path.join(
    os.path.dirname(__file__), '..', 'data', 'transactions.csv')
df = pd.read_csv(DATA_PATH)
X = df[['amount','time']]
y = df['is_fraud']
X_tr, X_te, y_tr, y_te = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y)

mlflow.set_experiment('fraud-detection-v1')
with mlflow.start_run():
    mlflow.log_param('max_depth', args.max_depth)
    mlflow.log_param('min_samples', args.min_samples)
    mlflow.log_param('criterion', args.criterion)

    clf = DecisionTreeClassifier(
        max_depth=args.max_depth,
        min_samples_split=args.min_samples,
        criterion=args.criterion,
        random_state=42)
    clf.fit(X_tr, y_tr)
    y_pred = clf.predict(X_te)

    acc = accuracy_score(y_te, y_pred)
    rec = recall_score(y_te, y_pred, zero_division=0)
    f1v = f1_score(y_te, y_pred, zero_division=0)
    mlflow.log_metric('accuracy', acc)
    mlflow.log_metric('recall', rec)
    mlflow.log_metric('f1', f1v)
    mlflow.sklearn.log_model(clf, name='fraud_model')
    print(f'Recall: {rec:.3f}')
