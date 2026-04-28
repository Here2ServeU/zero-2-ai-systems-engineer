#!/usr/bin/env bash
set -euo pipefail

docker build -f course/week-05-containerization-with-docker/Dockerfile -t nawex/week-04-api:latest .
