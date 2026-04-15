#!/usr/bin/env bash
set -euo pipefail

docker build -f week-04-containerization-with-docker/Dockerfile -t nawex/week-03-api:latest .
