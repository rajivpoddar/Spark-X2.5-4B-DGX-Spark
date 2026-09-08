#!/usr/bin/env bash
set -euo pipefail

BASE_URL=${1:-http://127.0.0.1:30001}
MODEL=${2:-spark2.5}

curl -fsS "${BASE_URL}/v1/models" | grep -q "$MODEL"

response=$(curl -fsS "${BASE_URL}/v1/chat/completions" \
  -H 'content-type: application/json' \
  -d "{\"model\":\"${MODEL}\",\"max_tokens\":32,\"temperature\":0,\"messages\":[{\"role\":\"user\",\"content\":\"Reply with exactly SPARK25_OK\"}]}")
grep -q 'SPARK25_OK' <<<"$response"
python3 -c 'import json, sys; message=json.load(sys.stdin)["choices"][0]["message"]; assert message.get("reasoning_content") in (None, ""), message' <<<"$response"

stream_response=$(curl -fsS -N "${BASE_URL}/v1/chat/completions" \
  -H 'content-type: application/json' \
  -d "{\"model\":\"${MODEL}\",\"stream\":true,\"max_tokens\":16,\"temperature\":0,\"chat_template_kwargs\":{\"enable_thinking\":false},\"messages\":[{\"role\":\"user\",\"content\":\"Reply OK\"}]}")
grep -q 'data:' <<<"$stream_response"

curl -fsS "${BASE_URL}/v1/chat/completions" \
  -H 'content-type: application/json' \
  -d "{\"model\":\"${MODEL}\",\"max_tokens\":64,\"temperature\":0,\"chat_template_kwargs\":{\"enable_thinking\":false},\"messages\":[{\"role\":\"user\",\"content\":\"Call get_status for spark\"}],\"tools\":[{\"type\":\"function\",\"function\":{\"name\":\"get_status\",\"description\":\"Get service status\",\"parameters\":{\"type\":\"object\",\"properties\":{\"service\":{\"type\":\"string\"}},\"required\":[\"service\"]}}}],\"tool_choice\":\"auto\"}" \
  | grep -Eq 'tool_calls|get_status'

echo "Spark-X2.5 direct smoke tests passed"
