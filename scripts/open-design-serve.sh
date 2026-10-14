#!/usr/bin/env bash
#
# Sobe o daemon do OpenDesign instalado por install-open-design.sh.
#
# Idempotente (no-op se já está rodando) → pode ser chamado em todo start da
# workspace e também à mão. Bind em 127.0.0.1: quem consome é o harness (omp,
# via MCP stdio) e, se for exposto, o NPM do homelab por cima.
#
# Não usamos cron: a workspace Coder não tem cron daemon (PID 1 é o agent).
set -euo pipefail

OD_HOME="${OD_HOME:-$HOME/open-design}"
OD_PORT="${OD_PORT:-7456}"
OD_DATA_DIR="${OD_DATA_DIR:-$HOME/.od}"
# Log dentro de $OD_DATA_DIR (home, persistente): /tmp é do container e some
# quando a workspace reinicia — foi o que aconteceu em 2026-10-14.
LOG="${OD_LOG:-$OD_DATA_DIR/open-design.log}"
PATTERN="apps/daemon/dist/cli.js"

# Liveness por porta, não por pgrep: `pgrep -f` casa com qualquer shell cujo
# cmdline contenha o padrão (um `bash -lc "… dist/cli.js …"` basta) e aí o
# script conclui "já rodando" e nunca sobe nada. O health responde de verdade.
if curl -sf -o /dev/null --max-time 3 "http://127.0.0.1:$OD_PORT/api/health"; then
    echo "open-design-serve: já rodando (porta $OD_PORT)"
    exit 0
fi

[ -f "$OD_HOME/.od-node" ] || { echo "open-design-serve: rode install-open-design.sh antes" >&2; exit 1; }
IFS= read -r NODE_BIN < "$OD_HOME/.od-node"
[ -x "$NODE_BIN" ] || { echo "open-design-serve: node inválido ($NODE_BIN)" >&2; exit 1; }

cd "$OD_HOME"
mkdir -p "$OD_DATA_DIR"
# Origens do proxy: o guard de CSRF do app (`origin-validation.ts`) compara a
# origem recebida com o que ele escuta (loopback); atrás de reverse proxy
# (Coder) a checagem de same-origin não fecha — sem esta lista, PUT/POST
# devolvem 403 (`/api/app-config`, `/api/test/connection`). Origens, sem
# wildcard: uma entrada por forma de URL.
#
# Loopback basta para o bind: quem disca o app é o agent, de dentro da workspace
# (`Type=workspace_app ... 200`). Não trocar por 0.0.0.0 sem medir, que aí o
# guard do `server.ts` exige OD_DISABLE_API_AUTH e a porta passa a responder em
# toda interface.
#
# Nada de comentário DENTRO da cadeia de `\`: o `#` engole o resto da linha já
# concatenada e as variáveis seguintes nunca chegam ao processo.
OD_ALLOWED_ORIGINS="${OD_ALLOWED_ORIGINS:-https://open-design--work--gu-does-git.gupve.dev,https://open-design--main--work--gu-does-git.gupve.dev}" \
NODE_ENV=production \
OD_PORT="$OD_PORT" \
OD_DATA_DIR="$OD_DATA_DIR" \
OD_BIND_HOST=127.0.0.1 \
    nohup "$NODE_BIN" "$PATTERN" --no-open >> "$LOG" 2>&1 &

echo "open-design-serve: iniciado (porta $OD_PORT, log $LOG)"
