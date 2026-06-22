# open-webui-rock

OCI rock image for [Open WebUI](https://github.com/open-webui/open-webui), built with [Rockcraft](https://documentation.ubuntu.com/rockcraft).

Open WebUI is an extensible, feature-rich self-hosted AI chat interface supporting OpenAI-compatible APIs, Ollama, and many more backends.

## Rock layout

```
open-webui/
└── 0.9-24.04/          # version-base directory
    ├── rockcraft.yaml   # Rock build recipe
    ├── spread.yaml      # Spread integration test config
    └── spread/
        ├── .extension   # Backend lifecycle helpers
        └── general/
            ├── test_health/          # Health endpoint liveness check
            ├── test_api/             # REST API smoke tests
            ├── test_model_list/      # Model discovery via qwen3 snap
            └── test_llm_connection/  # End-to-end chat completion
```

## Build

```bash
sudo snap install rockcraft --classic
cd open-webui/0.9-24.04
rockcraft pack
```

The build clones the Open WebUI source at tag `v0.9.6`, builds the SvelteKit
frontend with Node.js 22, installs the Python backend dependencies (CPU-only
PyTorch, no pre-baked ML models), and packages everything as an OCI image
managed by Pebble.

## Run

```bash
# Load into Docker
sudo rockcraft.skopeo --insecure-policy copy \
  oci-archive:open-webui_0.9_amd64.rock \
  docker-daemon:open-webui:0.9

# Start (point at an OpenAI-compatible API, e.g. qwen3 snap)
docker run -d \
  --name open-webui \
  -p 8080:8080 \
  -e OPENAI_API_BASE_URL="http://localhost:11434/v1" \
  -e OPENAI_API_KEY="not-required" \
  -e WEBUI_SECRET_KEY="your-secret-here" \
  -v open-webui-data:/app/backend/data \
  open-webui:0.9
```

Open WebUI is then available at http://localhost:8080.

### Using with the qwen3 snap

```bash
sudo snap install qwen3 --edge
qwen3 status               # shows the API URL, e.g. http://localhost:<port>/v1

docker run -d \
  --name open-webui \
  --network=host \
  -e OPENAI_API_BASE_URL="$(qwen3 status | grep -oP 'openai:\s*\K\S+')" \
  -e OPENAI_API_KEY="not-required" \
  -e WEBUI_SECRET_KEY="$(head -c 12 /dev/random | base64)" \
  -v open-webui-data:/app/backend/data \
  open-webui:0.9
```

## Design notes

| Decision | Rationale |
|---|---|
| `base: ubuntu@24.04` | Open WebUI requires a full shell (`bash start.sh`), ffmpeg, pandoc, and 150+ Python packages. Chisel `bare` base is not practical here. |
| Slim build (no pre-baked models) | Sentence-transformers + Whisper add ~2 GB. Models are downloaded on first use to `/app/backend/data` (mount a volume). Set `USE_SLIM_DOCKER=false` to enable auto-download. |
| CPU-only PyTorch | CUDA support requires the NVIDIA container runtime; the rock targets general-purpose deployment. |
| `_daemon_` user (UID 584792) | Pebble best practice for rootless operation. |
| Pebble service | `bash /app/backend/start.sh` — the upstream entrypoint script handles secret key generation and uvicorn startup. |

## Tests

Integration tests use the [Spread](https://github.com/canonical/spread) framework and the [`qwen3`](https://snapcraft.io/qwen3) snap (text LLM, OpenAI-compatible API, published by Canonical IoT Labs).

```bash
# Run all spread tests
make test-all

# Or directly
cd open-webui/0.9-24.04
rockcraft test
```

| Test | What it verifies |
|---|---|
| `test_health` | `GET /health` returns `{"status": true}` |
| `test_api` | Version, config, and sign-in endpoints work |
| `test_model_list` | Open WebUI discovers qwen3 models via OpenAI passthrough |
| `test_llm_connection` | End-to-end chat completion via qwen3 returns a non-empty response |

## CI

GitHub Actions workflows (`.github/workflows/`) use the `canonical/oci-factory`
reusable workflows to build, test, and publish the rock to GHCR. CVE scanning
runs daily via Trivy.

## AI-assisted development

This repo includes the [rock-lab](https://github.com/alesancor1/rock-lab)
OpenCode agents and skills under `.opencode/`. Use the `/build-rock` slash
command or `@rock-builder` agent to iteratively build and fix the rock with
AI assistance.
