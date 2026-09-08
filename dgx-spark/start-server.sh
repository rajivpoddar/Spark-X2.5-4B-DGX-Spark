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

min_available_gib=${SPARK25_MIN_AVAILABLE_GIB:-96}
available_kib=$(awk '/^MemAvailable:/ { print $2 }' /proc/meminfo)
required_kib=$((min_available_gib * 1024 * 1024))
if (( available_kib < required_kib )); then
  available_gib=$((available_kib / 1024 / 1024))
  echo "refusing to start Spark-X2.5: ${available_gib} GiB available, ${min_available_gib} GiB required" >&2
  echo "stop the active inference backend in a maintenance window before retrying" >&2
  exit 1
fi

for required in config.json chat_template.jinja; do
  if [[ ! -s "${SPARK25_MODEL_DIR}/${required}" ]]; then
    echo "model is incomplete: missing ${SPARK25_MODEL_DIR}/${required}" >&2
    exit 1
  fi
done

if ss -H -ltn "sport = :${SPARK25_PORT}" | grep -q .; then
  echo "refusing to start Spark-X2.5: port ${SPARK25_PORT} is already in use" >&2
  exit 1
fi

if docker container inspect "$SPARK25_CONTAINER" >/dev/null 2>&1; then
  echo "refusing to replace existing container ${SPARK25_CONTAINER}" >&2
  exit 1
fi

exec docker run --rm \
  --name "$SPARK25_CONTAINER" \
  --gpus '"device=0"' \
  --ipc=host \
  --network=host \
  -v "${SPARK25_MODEL_DIR}:/models/Spark-X2.5-4B:ro" \
  "$SPARK25_IMAGE" \
  python -m sglang.launch_server \
    --model-path /models/Spark-X2.5-4B \
    --served-model-name "$SPARK25_SERVED_MODEL" \
    --tool-call-parser spark25 \
    --reasoning-parser qwen3 \
    --default-chat-template-kwargs '{"enable_thinking":false}' \
    --tp-size 1 \
    --mem-fraction-static "$SPARK25_MEM_FRACTION" \
    --context-length "$SPARK25_CONTEXT" \
    --chat-template /models/Spark-X2.5-4B/chat_template.jinja \
    --host "$SPARK25_HOST" \
    --port "$SPARK25_PORT"
