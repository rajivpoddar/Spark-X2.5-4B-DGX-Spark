#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ENV_FILE=${SPARK25_ENV_FILE:-"${SCRIPT_DIR}/spark25.env"}

if [[ ! -f "$ENV_FILE" ]]; then
  echo "missing $ENV_FILE; copy spark25.env.example to spark25.env" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"
mkdir -p "$SPARK25_MODEL_DIR"

if command -v hf >/dev/null 2>&1; then
  exec hf download "$SPARK25_MODEL_ID" --local-dir "$SPARK25_MODEL_DIR"
fi

if docker image inspect "$SPARK25_IMAGE" >/dev/null 2>&1; then
  exec docker run --rm \
    -v "${SPARK25_MODEL_DIR}:/model" \
    --entrypoint /usr/local/bin/hf \
    "$SPARK25_IMAGE" \
    download "$SPARK25_MODEL_ID" --local-dir /model
fi

echo "the Hugging Face 'hf' CLI or the pulled SGLang image is required" >&2
exit 1
