#!/usr/bin/env bash
set -euo pipefail

uvicorn app:app --app-dir course/week-03-serving-models-via-apis/src --host 0.0.0.0 --port 8000 --reload
