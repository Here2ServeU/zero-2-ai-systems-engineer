# Healthcare Anomaly Detection

The healthcare anomaly detection model is an Isolation Forest trained on patient vitals: heart rate, systolic blood pressure, oxygen saturation, and body temperature. The model flags vitals that deviate from the learned distribution as anomalies for clinician review.

The model is served through a Flask `/predict/anomaly` endpoint. Because false negatives in healthcare carry clinical consequences, the threshold is tuned for high recall on the validation set, even at the cost of some additional false positives. Every prediction is logged with a hashed patient identifier — never raw PHI — and a clinician's acknowledgement state is captured for downstream evaluation.

Healthcare workloads run inside a dedicated Kubernetes namespace with stricter network policies and PHI-aware logging. The platform's PII redactor strips sensitive fields before any log line leaves the namespace.
