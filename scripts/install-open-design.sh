#!/usr/bin/env bash
#
# OpenDesign (https://github.com/nexu-io/open-design) — build nativo a partir
# do source, dentro da workspace.
#
# Por que source: o projeto não publica artefato Linux nem pacote npm
# (`@open-design/daemon` é unpublished); o README manda `pnpm install` + build.
# Antes isto rodava como container no host `alpine` (stack `ai-stack`), mas o
# harness (omp) roda DENTRO da workspace — então o daemon precisa viver aqui
# para o MCP falar por loopback, sem ssh/docker no meio.
#
# Idempotente: se `apps/daemon/dist/cli.js` já existe, não faz nada.
#   FORCE=1  → git fetch/reset + rebuild.
#
# Node: o repo declara `engines ~24` e o node da workspace é 26. better-sqlite3
# é módulo nativo (ABI): quem builda tem que ser quem roda, então pinamos o
# node 24 do nvm e gravamos o caminho em `.od-node` (lido pelo serve).
set -euo pipefail

OD_HOME="${OD_HOME:-$HOME/open-design}"
OD_REPO="${OD_REPO:-https://github.com/nexu-io/open-design.git}"

# ── node 24 (nvm já está instalado pela workspace) ──────────────────────────
NODE_BIN="${NODE_BIN:-$(ls -d "$HOME"/.nvm/versions/node/v24.*/bin/node 2>/dev/null | sort -V | tail -1 || true)}"
if [ ! -x "${NODE_BIN:-}" ]; then
    echo "install-open-design: node 24 não encontrado no nvm — instalando"
    if [ -s "$HOME/.nvm/nvm.sh" ]; then
        # shellcheck disable=SC1091
        . "$HOME/.nvm/nvm.sh"
        nvm install 24
        NODE_BIN="$(dirname "$(nvm which 24)")/node"
    fi
fi
[ -x "${NODE_BIN:-}" ] || { echo "install-open-design: ERRO — sem node 24" >&2; exit 1; }
export PATH="$(dirname "$NODE_BIN"):$PATH"
export COREPACK_ENABLE_DOWNLOAD_PROMPT=0

echo "install-open-design: node $( "$NODE_BIN" -v ) ($NODE_BIN)"

# ── clone ───────────────────────────────────────────────────────────────────
if [ ! -d "$OD_HOME/.git" ]; then
    echo "install-open-design: clonando em $OD_HOME"
    git clone --depth 1 "$OD_REPO" "$OD_HOME"
fi

cd "$OD_HOME"

if [ "${FORCE:-}" = "1" ]; then
    echo "install-open-design: FORCE=1 → atualizando working tree"
    git fetch --depth 1 origin main
    git reset --hard FETCH_HEAD
fi

# esbuild procura tsconfig/jsconfig subindo a árvore e a raiz deste repo não
# tem nenhum dos dois, então a busca SAI do repo e bate em ~/jsconfig.json —
# que o sn-scriptsync cria só com um comentário /* */ (JSON inválido) e derruba
# o postinstall com "Unexpected end of file in JSON". O arquivo é do
# sn-scriptsync, então não sobrescrevemos: movemos durante o build e o trap
# devolve no fim (inclusive se o build falhar).
STRAY="$HOME/jsconfig.json"
BAK="$HOME/.jsconfig.json.open-design-bak"
if [ -f "$STRAY" ] && ! "$NODE_BIN" -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$STRAY" 2>/dev/null; then
    mv "$STRAY" "$BAK"
    trap 'mv "$BAK" "$STRAY"' EXIT
    echo "install-open-design: ~/jsconfig.json inválido (sn-scriptsync) movido durante o build"
fi

# ── build (pnpm 10.33.2 vem do `packageManager` via corepack) ───────────────
if [ "${FORCE:-}" = "1" ] || [ ! -f apps/daemon/dist/cli.js ] || [ ! -d apps/web/out ]; then
    echo "install-open-design: pnpm install"
    corepack pnpm install --frozen-lockfile
    echo "install-open-design: build do daemon"
    corepack pnpm --filter @open-design/daemon build
    echo "install-open-design: build do web (export estático p/ o daemon servir)"
    corepack pnpm --filter @open-design/web build
fi

printf '%s\n' "$NODE_BIN" > "$OD_HOME/.od-node"
echo "install-open-design: ok → $OD_HOME (node: $NODE_BIN)"
