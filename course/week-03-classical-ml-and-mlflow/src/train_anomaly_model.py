"""Train a baseline anomaly detection model on patient/system telemetry.

Placeholder for Chapter 4. The chapter walks through Isolation Forest
on synthetic vitals; replace the data loader with the real dataset
when extending this lab.
"""

import mlflow
import pandas as pd
from sklearn.ensemble import IsolationForest
from sklearn.metrics import classification_report

DATA_PATH = "course/week-03-classical-ml-and-mlflow/data/vitals.csv"


def main() -> None:
    df = pd.read_csv(DATA_PATH)
    features = df.drop(columns=["is_anomaly"])
    labels = df["is_anomaly"]

    mlflow.set_experiment("healthcare_anomaly_detection")
    with mlflow.start_run():
        params = {"n_estimators": 150, "contamination": 0.05, "random_state": 42}
        model = IsolationForest(**params)
        model.fit(features)
        raw = model.predict(features)
        preds = (raw == -1).astype(int)

        mlflow.log_params(params)
        report = classification_report(labels, preds, output_dict=True)
        mlflow.log_metric("precision_anomaly", report["1"]["precision"])
        mlflow.log_metric("recall_anomaly", report["1"]["recall"])
        mlflow.sklearn.log_model(model, "model")


if __name__ == "__main__":
    main()
