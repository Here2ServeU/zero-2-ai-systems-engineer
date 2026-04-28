# Capstone Data

Seed datasets for the Nawex AI Reliability Platform. These are small, synthetic, safe to commit, and sufficient for every script under `../src/` to run end-to-end on a laptop.

| File | Used by | Purpose |
|---|---|---|
| `transactions.csv` | `train_models.py`, `drift_check.py` | Synthetic transaction stream with `is_fraud` label |
| `vitals.csv` | `train_models.py` | Synthetic patient vitals with `is_anomaly` label |
| `knowledge_base/*.md` | `ingest_kb.py` | Source documents for the RAG pipeline |
| `eval_set.json` | `eval.py` | Question / must-contain pairs for the LLM and RAG endpoints |
| `drift_sample.csv` | `drift_check.py` | A shifted slice of `transactions.csv` used to demonstrate drift detection |

Replace these with real datasets in production. Real data must never be committed.
