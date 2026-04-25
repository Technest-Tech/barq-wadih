#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "Stopping Barq Wadih dev services..."
cd "$ROOT_DIR"
docker compose down
echo "All services stopped. Data volumes preserved."
echo "To remove volumes too: docker compose down -v"
