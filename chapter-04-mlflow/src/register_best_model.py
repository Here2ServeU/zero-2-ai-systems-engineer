# register_best_model.py
import mlflow
from mlflow.tracking import MlflowClient

client = MlflowClient()
exp = mlflow.get_experiment_by_name(
    'fraud-detection-v1')
runs = client.search_runs(
    experiment_ids=[exp.experiment_id],
    order_by=['metrics.recall DESC'])
best_id = runs[0].info.run_id
uri = f'runs:/{best_id}/fraud_model'
result = mlflow.register_model(
    uri, 'FraudDetectionModel')
print(f'Registered version: {result.version}')
