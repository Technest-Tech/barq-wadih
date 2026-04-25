#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "Starting Barq Wadih dev services..."
if [ -f "$ROOT_DIR/.env.docker" ]; then
  set -a; source "$ROOT_DIR/.env.docker"; set +a
fi
cd "$ROOT_DIR"
docker compose up -d
echo "Services started: MySQL:3306  Redis:6379  Meilisearch:7700"
