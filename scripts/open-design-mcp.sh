#!/usr/bin/env bash
#
# Entrypoint do MCP do OpenDesign para agentes locais (FALA stdio no stdout).
#
# Garante o daemon (open-design-serve.sh é no-op se já roda), cai para o diretório
# do build e entrega o stdio pro `cli.js mcp`. Existe para o config do harness
# apontar num caminho estável (~/.local/bin) em vez do node do nvm, que muda de
# versão.
#
# Atenção: nada aqui pode escrever no stdout antes do exec — stdout É o canal
# JSON-RPC. Mensagens vão para stderr.
set -euo pipefail

OD_HOME="${OD_HOME:-$HOME/open-design}"
OD_PORT="${OD_PORT:-7456}"

[ -r "$OD_HOME/.od-node" ] || { echo "open-design-mcp: rode install-open-design.sh antes" >&2; exit 1; }
IFS= read -r NODE_BIN < "$OD_HOME/.od-node"
[ -x "$NODE_BIN" ] || { echo "open-design-mcp: node inválido ($NODE_BIN)" >&2; exit 1; }

"$HOME/.local/bin/open-design-serve.sh" >&2 || true

cd "$OD_HOME"
exec "$NODE_BIN" apps/daemon/dist/cli.js mcp --daemon-url "http://127.0.0.1:$OD_PORT"
