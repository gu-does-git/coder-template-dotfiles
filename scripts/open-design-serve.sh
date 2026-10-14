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

if pgrep -f "$PATTERN" >/dev/null 2>&1; then
    echo "open-design-serve: já rodando (porta $OD_PORT)"
    exit 0
fi

[ -f "$OD_HOME/.od-node" ] || { echo "open-design-serve: rode install-open-design.sh antes" >&2; exit 1; }
IFS= read -r NODE_BIN < "$OD_HOME/.od-node"
[ -x "$NODE_BIN" ] || { echo "open-design-serve: node inválido ($NODE_BIN)" >&2; exit 1; }

cd "$OD_HOME"
mkdir -p "$OD_DATA_DIR"
NODE_ENV=production \
OD_PORT="$OD_PORT" \
OD_BIND_HOST=127.0.0.1 \
OD_DATA_DIR="$OD_DATA_DIR" \
    nohup "$NODE_BIN" "$PATTERN" --no-open >> "$LOG" 2>&1 &

echo "open-design-serve: iniciado (porta $OD_PORT, log $LOG)"
