# retrain_pipeline.py
import pandas as pd, numpy as np, mlflow
import mlflow.sklearn
from sklearn.tree import DecisionTreeClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import recall_score, f1_score

RECALL_THRESHOLD = 0.70

def retrain_and_validate():
    np.random.seed(99)
    n = 2000
    amounts = np.random.exponential(220, n)
    times = np.random.uniform(0, 24, n)
    fraud = ((amounts>650)&(times<5)).astype(int)
    df = pd.DataFrame({
        'amount':amounts.round(2),
        'time':times.round(2),
        'is_fraud':fraud})
    X = df[['amount','time']]
    y = df['is_fraud']
    X_tr,X_te,y_tr,y_te = train_test_split(
        X,y,test_size=0.2,random_state=42)

    mlflow.set_experiment('fraud-auto-retrain')
    with mlflow.start_run() as run:
        clf = DecisionTreeClassifier(
            max_depth=6, random_state=42)
        clf.fit(X_tr, y_tr)
        y_pred = clf.predict(X_te)
        recall = recall_score(
            y_te, y_pred, zero_division=0)
        f1 = f1_score(
            y_te, y_pred, zero_division=0)
        mlflow.log_metric('recall', recall)
        mlflow.log_metric('f1', f1)
        mlflow.sklearn.log_model(clf,'model')

        if recall >= RECALL_THRESHOLD:
            uri = f'runs:/{run.info.run_id}/model'
            mlflow.register_model(
                uri, 'FraudDetectionModel')
            print(f'PROMOTED: recall={recall:.3f}')
            return True
        else:
            print(f'REJECTED: recall={recall:.3f}')
            print(f'Required: {RECALL_THRESHOLD}')
            return False

success = retrain_and_validate()
exit(0 if success else 1)
