"""Train a baseline fraud detection model and log the run to MLflow.

Placeholder for Chapter 4. Replace the synthetic-data block with the
real transaction dataset described in the chapter.
"""

import mlflow
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import f1_score, precision_score, recall_score
from sklearn.model_selection import train_test_split

DATA_PATH = "course/week-03-classical-ml-and-mlflow/data/transactions.csv"


def load_data() -> pd.DataFrame:
    return pd.read_csv(DATA_PATH)


def main() -> None:
    df = load_data()
    X = df.drop(columns=["is_fraud"])
    y = df["is_fraud"]
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, stratify=y, random_state=42
    )

    mlflow.set_experiment("fraud_detection")
    with mlflow.start_run():
        params = {"n_estimators": 200, "max_depth": 8, "random_state": 42}
        model = RandomForestClassifier(**params)
        model.fit(X_train, y_train)
        preds = model.predict(X_test)

        mlflow.log_params(params)
        mlflow.log_metrics({
            "precision": precision_score(y_test, preds),
            "recall": recall_score(y_test, preds),
            "f1": f1_score(y_test, preds),
        })
        mlflow.sklearn.log_model(model, "model")


if __name__ == "__main__":
    main()
