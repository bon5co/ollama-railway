# ollama-railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/ollama-open-webui-or-fast-cpu-inference-?referralCode=Z1xivh&utm_medium=integration&utm_source=template&utm_campaign=generic)

**Deploy on Railway:** [Ollama + Open WebUI template](https://railway.com/deploy/ollama-open-webui-or-fast-cpu-inference-?referralCode=Z1xivh&utm_medium=integration&utm_source=template&utm_campaign=generic)

Two thin wrapper images that make a private Ollama + Open WebUI stack deploy on
Railway with nothing to fill in and a model already downloaded.

| Image | Base | What it changes |
| --- | --- | --- |
| `ghcr.io/bon5co/ollama-railway` | `ollama/ollama:0.32.5` | binds all interfaces, one loaded model at a time, pulls `OLLAMA_PRELOAD_MODEL` on first boot |
| `ghcr.io/bon5co/ollama-railway-webui` | `openwebui/open-webui:0.11.0` | auth on, OpenAI connector off, telemetry off, `PORT=8080` |

Both exist for the same mechanical reason. Railway's `templateGenerate` keeps a
template variable's default **only** when the live value is a Railway expression
(`${{secret(48)}}`, `${{svc.VAR}}`). A literal is dropped, and the variable
publishes as *required with no value* — so the deploy form opens asking the user
to type settings the image already knows. Baking those literals into the image
is what keeps the published form empty.

## Ollama

`OLLAMA_HOST=::` binds every interface, v4 and v6. Ollama's own default is
loopback-only, which is the usual reason a private Ollama service on Railway
reports healthy while the sibling container talking to it gets connection
refused.

**Threads are sized to the container, not to the host.** A container reports the
host's core count, so llama-server auto-detects dozens of threads and
oversubscribes the cgroup quota it actually has. Measured on Railway with
`llama3.2:1b` on 2026-07-31: **1.11 tok/s** with auto-detection against
**87 tok/s** with the count capped at the plan's vCPU — the same box, the same
model, ~78x. `railway-entrypoint.sh` reads the cgroup quota and exports
`LLAMA_ARG_THREADS`, which llama-server picks up for every model, not just the
preloaded one. Set `LLAMA_ARG_THREADS` yourself to override it.

`OLLAMA_PRELOAD_MODEL` (default `llama3.2:1b`) is pulled by
`railway-entrypoint.sh` **after** the server is already listening, so the service
is reachable immediately and the model shows up in the list when the download
finishes. Set it to an empty string to skip the preload, or to any tag from the
[Ollama library](https://ollama.com/library) to preload something else. A failed
pull is logged and ignored — the server stays up either way.

Inference here is CPU-only; Railway has no GPU. 1B–8B models are the practical
range, and the 1B default is chosen so the first chat works on a small instance.

A Railway **start command replaces the image ENTRYPOINT** rather than appending
to it, so a template using this image must set no start command — otherwise the
preload silently never runs.

## Open WebUI

The first account registered becomes the admin; every later signup lands in the
`pending` role and needs the admin to approve it. `ENABLE_OPENAI_API=false`
because the stack has no OpenAI key and the connector would only produce errors.

Mount volumes at `/root/.ollama` (weights) and `/app/backend/data` (accounts,
chats, settings). Open WebUI reads `DATA_DIR=/app/backend/data`; a volume
anywhere else is a volume it never writes to.

Built for [railwaytemplate2](https://github.com/bon5co/railwaytemplate2).
