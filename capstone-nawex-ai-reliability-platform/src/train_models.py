"""Train the fraud and anomaly models, log to MLflow, persist artifacts.

Wires Layer 2 (Data & Models) into the capstone. Outputs the joblib
artifacts that `serve.py` loads at startup.
"""

import json

import joblib
import mlflow
import pandas as pd
from sklearn.ensemble import IsolationForest, RandomForestClassifier
from sklearn.metrics import f1_score, precision_score, recall_score
from sklearn.model_selection import train_test_split

import paths

FRAUD_FEATURES = ["amount", "hour", "merchant_risk", "country_risk"]
VITALS_FEATURES = ["heart_rate", "systolic_bp", "oxygen_sat", "temperature"]


def train_fraud() -> None:
    df = pd.read_csv(paths.TRANSACTIONS_CSV)
    X, y = df[FRAUD_FEATURES], df["is_fraud"]
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.25, stratify=y, random_state=42
    )

    mlflow.set_experiment("nawex_fraud_detection")
    with mlflow.start_run():
        params = {"n_estimators": 200, "max_depth": 6, "random_state": 42}
        model = RandomForestClassifier(**params)
        model.fit(X_train, y_train)
        preds = model.predict(X_test)

        mlflow.log_params(params)
        mlflow.log_metrics({
            "precision": precision_score(y_test, preds, zero_division=0),
            "recall": recall_score(y_test, preds, zero_division=0),
            "f1": f1_score(y_test, preds, zero_division=0),
        })
        mlflow.sklearn.log_model(model, "model")

    paths.ARTIFACTS_DIR.mkdir(parents=True, exist_ok=True)
    joblib.dump(model, paths.FRAUD_MODEL)
    paths.TRAIN_FEATURE_STATS.write_text(
        json.dumps(X.describe().to_dict(), indent=2)
    )


def train_anomaly() -> None:
    df = pd.read_csv(paths.VITALS_CSV)
    X = df[VITALS_FEATURES]

    mlflow.set_experiment("nawex_healthcare_anomaly")
    with mlflow.start_run():
        params = {"n_estimators": 150, "contamination": 0.15, "random_state": 42}
        model = IsolationForest(**params)
        model.fit(X)
        preds = (model.predict(X) == -1).astype(int)

        mlflow.log_params(params)
        mlflow.log_metric("flagged_rate", float(preds.mean()))
        mlflow.sklearn.log_model(model, "model")

    joblib.dump(model, paths.ANOMALY_MODEL)


def main() -> None:
    train_fraud()
    train_anomaly()
    print(f"Saved {paths.FRAUD_MODEL.name} and {paths.ANOMALY_MODEL.name}")


if __name__ == "__main__":
    main()
