"""Single source of truth for capstone filesystem paths."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = ROOT / "data"
ARTIFACTS_DIR = ROOT / "artifacts"
CHROMA_DIR = ROOT / "chroma"

TRANSACTIONS_CSV = DATA_DIR / "transactions.csv"
VITALS_CSV = DATA_DIR / "vitals.csv"
DRIFT_CSV = DATA_DIR / "drift_sample.csv"
KNOWLEDGE_BASE = DATA_DIR / "knowledge_base"
EVAL_SET = DATA_DIR / "eval_set.json"

FRAUD_MODEL = ARTIFACTS_DIR / "fraud_model.joblib"
ANOMALY_MODEL = ARTIFACTS_DIR / "anomaly_model.joblib"
TRAIN_FEATURE_STATS = ARTIFACTS_DIR / "train_feature_stats.json"
