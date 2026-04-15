from pathlib import Path

import pandas as pd
from fastapi import FastAPI
from pydantic import BaseModel
from sklearn.tree import DecisionTreeClassifier


DATA_PATH = (
    Path(__file__).resolve().parents[2]
    / "week-01-foundations"
    / "data"
    / "system_metrics.csv"
)


def train_model() -> DecisionTreeClassifier:
    data = pd.read_csv(DATA_PATH)
    features = data[["cpu", "memory", "latency"]]
    labels = data["healthy"]
    model = DecisionTreeClassifier(random_state=42)
    model.fit(features, labels)
    return model


model = train_model()
app = FastAPI(title="NAWEX System Health API", version="0.1.0")


class MetricsPayload(BaseModel):
    cpu: float
    memory: float
    latency: float


@app.get("/health")
def health() -> dict:
    return {"status": "ok", "service": "week-03-serving-models-via-apis"}


@app.post("/predict")
def predict(payload: MetricsPayload) -> dict:
    sample = pd.DataFrame(
        [[payload.cpu, payload.memory, payload.latency]],
        columns=["cpu", "memory", "latency"],
    )
    prediction = int(model.predict(sample)[0])
    return {"healthy": prediction}
