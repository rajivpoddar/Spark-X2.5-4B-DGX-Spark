# Spark-X2.5-4B on one DGX Spark

This profile stages Spark-X2.5 alongside the active inference service. It does
not switch Claude Code slots automatically.

## Defaults

| Setting | Value |
| --- | --- |
| Runtime | `lmsysorg/sglang:nightly-dev-cu13-20260827-20621aa1` |
| Model | `XHToken/Spark-X2.5-4B` (BF16) |
| DGX API | `http://0.0.0.0:30001/v1` |
| CLIProxyAPI | `http://127.0.0.1:8319` |
| Tensor parallelism | 1 |
| Context | 262,144 tokens |
| Static memory fraction | 0.70 |
| Thinking through Claude route | off |

The upstream recipe advertises a 1,048,576-token context at a static memory
fraction of 0.8. This fork begins lower to establish stability on the shared
DGX Spark before growing the KV cache.

## DGX deployment

Copy this repository to `/home/user/serve/spark-x25-dgx`, then:

```bash
cd /home/user/serve/spark-x25-dgx/dgx-spark
cp spark25.env.example spark25.env
docker pull lmsysorg/sglang:nightly-dev-cu13-20260827-20621aa1
./download-model.sh
./start-server.sh
```

For a persistent service:

```bash
sudo ./install-service.sh
sudo systemctl start spark-x25-sglang.service
```

The launcher refuses to start if port 30001 is already occupied, the model is
incomplete, or another container already owns the configured name.

## Direct validation

```bash
./smoke-test.sh http://127.0.0.1:30001 spark2.5
```

The smoke test checks model discovery, thinking-off output, streaming, and a
tool-call request.

## CLIProxyAPI bridge for Claude Code

On the Mac running Claude Code:

```bash
mkdir -p ~/.config/cliproxyapi ~/.cli-proxy-api-spark25
cp cliproxyapi/spark25.conf.example ~/.config/cliproxyapi/spark25.conf
cp cliproxyapi/com.heydonna.cliproxyapi-spark25.plist.example \
  ~/Library/LaunchAgents/com.heydonna.cliproxyapi-spark25.plist
launchctl bootstrap gui/$(id -u) \
  ~/Library/LaunchAgents/com.heydonna.cliproxyapi-spark25.plist
```

Then validate the Anthropic-compatible route:

```bash
curl -fsS http://127.0.0.1:8319/v1/messages \
  -H 'x-api-key: local-spark25-loopback' \
  -H 'anthropic-version: 2023-06-01' \
  -H 'content-type: application/json' \
  -d '{"model":"spark25/spark-x2.5-4b","max_tokens":64,"messages":[{"role":"user","content":"Reply with exactly SPARK25_OK"}]}'
```

The proxy configuration overrides
`chat_template_kwargs.enable_thinking=false` after translating the Claude
request to the OpenAI chat-completions upstream. It also advertises only the
`none` thinking level, preventing clients from silently requesting unsupported
effort levels.

## Expanding context

Increase one variable at a time after stable 1-stream and 4-stream tests:

1. `SPARK25_CONTEXT=524288`
2. `SPARK25_MEM_FRACTION=0.75`
3. `SPARK25_CONTEXT=1048576`
4. `SPARK25_MEM_FRACTION=0.80` only if required

At each step check container restarts, host memory, GPU temperature, queue
growth, TTFT, and server logs for allocation or CUDA errors.

## Rollback

Stopping this staged service does not touch the service on port 30000:

```bash
sudo systemctl stop spark-x25-sglang.service
launchctl bootout gui/$(id -u)/com.heydonna.cliproxyapi-spark25
```
