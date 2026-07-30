# Railway-tuned Ollama image.
#
# Three things this changes about a stock `ollama/ollama` deployment on Railway:
#
#  0. Inference threads are sized to the container's CPU quota rather than to the
#     host's core count, which is what a container actually reports. Measured on
#     Railway with llama3.2:1b (2026-07-31): 1.11 tok/s auto-detected against
#     87 tok/s capped. See railway-entrypoint.sh.
#
#  1. Every setting a deployer would otherwise have to type is baked in as ENV.
#     Railway's `templateGenerate` keeps a template variable's default ONLY when
#     the live value is a Railway expression -- a literal is dropped and the
#     variable publishes as "required, no value", so the deploy form opens asking
#     for settings the image already knows. Baking them here keeps the form empty.
#
#  2. A model is pulled on first boot. Every other Ollama template on the Railway
#     marketplace deploys an empty model store, so the deployer opens the chat UI,
#     finds no models, and has to go find the pull screen. Here the server comes up
#     immediately and the model downloads behind it (see railway-entrypoint.sh).
FROM ollama/ollama:0.32.5

# `::` binds every interface, v4 and v6. Ollama's own default is loopback-only,
# which is why a private Ollama service on Railway looks healthy while a sibling
# container cannot reach it at all.
ENV OLLAMA_HOST=:: \
    OLLAMA_MODELS=/root/.ollama/models \
    OLLAMA_MAX_LOADED_MODELS=1 \
    OLLAMA_PRELOAD_MODEL=llama3.2:1b

COPY railway-entrypoint.sh /usr/local/bin/railway-entrypoint.sh
RUN chmod +x /usr/local/bin/railway-entrypoint.sh

EXPOSE 11434

# A Railway start command REPLACES the image ENTRYPOINT rather than appending to
# it, so the template that uses this image must set NO start command or the
# preload below silently never runs.
ENTRYPOINT ["/usr/local/bin/railway-entrypoint.sh"]
