#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COLLECTION_DIR="$SCRIPT_DIR/tests/bruno"

if [ ! -d "$COLLECTION_DIR" ]; then
  echo "Error: No se encontró el directorio $COLLECTION_DIR"
  exit 1
fi

cd "$COLLECTION_DIR"
bru run -r --env local --reporter-junit results-bruno.xml --reporter-html results-bruno.html "$@"
