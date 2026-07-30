# Railway-tuned Open WebUI image, paired with ../ollama.
#
# Same reason as the Ollama wrapper: a literal-valued template variable loses its
# default when Railway generates the template, and publishes as a required field
# with nothing in it. Everything the deployer should never have to type lives
# here instead, so the published deploy form stays empty.
FROM openwebui/open-webui:0.11.0

ENV PORT=8080 \
    WEBUI_AUTH=true \
    ENABLE_SIGNUP=true \
    ENABLE_LOGIN_FORM=true \
    DEFAULT_USER_ROLE=pending \
    ENABLE_OPENAI_API=false \
    SCARF_NO_ANALYTICS=true \
    DO_NOT_TRACK=true \
    ANONYMIZED_TELEMETRY=false

EXPOSE 8080
