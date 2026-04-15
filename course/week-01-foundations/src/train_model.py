from pathlib import Path

import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.tree import DecisionTreeClassifier


data_path = Path(__file__).resolve().parent.parent / "data" / "system_metrics.csv"
data = pd.read_csv(data_path)

X = data[["cpu", "memory", "latency"]]
y = data["healthy"]

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42
)

model = DecisionTreeClassifier(random_state=42)
model.fit(X_train, y_train)

accuracy = model.score(X_test, y_test)
print(f"Model Accuracy: {accuracy}")

sample = pd.DataFrame([[85, 90, 450]], columns=["cpu", "memory", "latency"])
prediction = model.predict(sample)

print("Prediction (0=Unhealthy, 1=Healthy):", prediction)
