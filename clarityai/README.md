# ClarityAI — Healthcare Clinical Intelligence Platform

**Book:** Capstone 2 (Signature Projects). A clinical intelligence platform for a fictional
hospital network, *St. Naweji Medical Center*. Scores incoming patient records with a
PyTorch risk model, triages CRITICAL/HIGH/MEDIUM/LOW, maintains full HIPAA compliance and
a tamper-evident audit trail, and meets FDA SaMD Class II pre-submission requirements. It
runs on the same cloud-agnostic Kubernetes infrastructure as NexaGuard.

> This is a **capstone scaffold**: each milestone reuses the scripts and patterns you
> already built in the `chapter-XX-*` labs, applied to the clinical domain.

## Eight-layer structure

| Folder | Layer | Built with skills from |
|---|---|---|
| `data/` | HL7 parsing, de-identified features (HIPAA §164.514) | chapter-03-models |
| `models/` | PyTorch clinical risk classifier + Isolation Forest, MLflow | chapter-03, chapter-04 |
| `api/` | Flask `/triage`, `/health`, `/patient/<id>`, `/audit` (Prometheus) | chapter-05, chapter-11 |
| `streaming/` | HL7/FHIR consumer, vital-sign enrichment, risk scorer | chapter-06, chapter-10 |
| `docker/` | Non-root Dockerfile, HIPAA-aligned secrets handling | chapter-06 |
| `terraform/` | EKS, VPC, KMS-encrypted S3, IAM roles | chapter-07, chapter-08 |
| `kubernetes/` | Deployment + Kyverno policies (no-root, network policies) | chapter-10, chapter-14 |
| `compliance/` | HIPAA gate checks, FDA SaMD evidence, IEC 62304 manifest | chapter-03 |
| `observability/` | Prometheus, Grafana, AIOps census/queue scaling | chapter-11, chapter-12, chapter-15 |
| `llm/` | Claude wrapper with PHI safety filter, audit logging | chapter-16, chapter-18 |
| `rag/` | ChromaDB over FDA SaMD / HIPAA / protocols, `/qa` citations | chapter-17 |

## The ten milestones

1. **Clinical data pipeline** — NEWS2 score, trend deltas, medication flags; de-identify
   per HIPAA §164.514 → 38 columns, zero PHI.
2. **Model training** — PyTorch risk classifier; 3 MLflow runs; register `clarityai-risk-classifier v1`
   (AUC-ROC > 0.96, **Sensitivity > 94%**, Specificity > 90%).
3. **Triage API** — `/triage` returns risk score/category, top features, confidence,
   `request_id`; p95 < 100ms; audit-log every prediction.
4. **Vital-sign streaming** — HL7 consumer → NEWS2 → SQS; KEDA-scaled pod; network policy.
5. **Container & cloud** — non-root image; EKS via Terraform with KMS-encrypted storage.
6. **CI/CD with clinical quality gates** — reject Sensitivity < 93% or AUC-ROC < 0.95;
   HIPAA gate fails on any PHI in features/logs.
7. **Observability & AIOps** — 6-panel clinical dashboard; auto-scale on CRITICAL census/queue depth.
8. **Compliance evidence** — signed evidence record per decision; FDA 21 CFR 820.30(g)
   checklist; IEC 62304 lifecycle docs.
9. **LLM clinical summary** — `/summary` with PHI safety filter, cache, per-physician budget, metrics.
10. **RAG regulatory** — ChromaDB over FDA SaMD / HIPAA §164.514/§164.530 / IEC 62304;
    `/regulatory/qa` with regulatory-section citations.

## Deliverables

Public GitHub repo + README + architecture diagram; `/triage` all-four-categories
screenshots; MLflow 3-run comparison; passing HIPAA PHI de-identification test; FDA SaMD
checklist mapped to evidence; live Grafana dashboard; KMS-encrypted EKS; `/summary` PHI
filter + `/regulatory/qa` responses; a 500-word written reflection.
