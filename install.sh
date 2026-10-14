#!/bin/bash
#
# Provisionador de ambiente do workspace coder.
# Otimizado: upgrade condicional, idempotente, installers de home em
# background durante o apt, apt consolidado (1 update + 1 install),
# DEBIAN_FRONTEND=noninteractive (mata os debconf retries).
#
# Flags:
#   SKIP_UPGRADE=1    pula `apt upgrade` (sistema inteiro — o passo mais lento)
#   SKIP_PLAYWRIGHT=1 pula o download do Chromium (E2E não precisa)
#   FORCE=1           re-instala mesmo se já presente
#
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

log_step() {
    printf "\n\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"
    printf "\033[1;36m  ▶ %s\033[0m\n" "$1"
    printf "\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"
}

# ────────────────────────────────────────────────────────────────────────
#  Installers de home — disparam AGORA, rodam em background enquanto o
#  apt trabalha (não usam apt; o wait fica depois do apt).
# ────────────────────────────────────────────────────────────────────────

log_step "Installers em background (bun, starship, zoxide, deno, uv, claude, beads, timetrace, worktrunk, yq)"
(
    command -v bun >/dev/null 2>&1 && [ "${FORCE:-}" != "1" ] || curl -fsSL https://bun.sh/install | bash
) &
(
    command -v starship >/dev/null 2>&1 && [ "${FORCE:-}" != "1" ] || curl -sS https://starship.rs/install.sh | sh -s -- -y
) &
(
    command -v zoxide >/dev/null 2>&1 && [ "${FORCE:-}" != "1" ] || curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
) &
(
    command -v deno >/dev/null 2>&1 && [ "${FORCE:-}" != "1" ] || curl -fsSL https://deno.land/install.sh | sh
) &
(
    command -v uv >/dev/null 2>&1 && [ "${FORCE:-}" != "1" ] || curl -LsSf https://astral.sh/uv/install.sh | sh
) &
(
    command -v claude >/dev/null 2>&1 && [ "${FORCE:-}" != "1" ] || curl -fsSL https://claude.ai/install.sh | bash
) &
(
    command -v beads >/dev/null 2>&1 && [ "${FORCE:-}" != "1" ] || curl -fsSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash
) &
(
    [ -x /usr/local/bin/timetrace ] && [ "${FORCE:-}" != "1" ] || curl -fsSL https://github.com/dominikbraun/timetrace/releases/download/v0.14.3/timetrace-linux-amd64.tar.gz | sudo tar -xz -C /usr/local/bin
) &
# worktrunk (wt): tarball tem dir versionado → strip-components=1
(
    [ -x /usr/local/bin/wt ] && [ "${FORCE:-}" != "1" ] || curl -fsSL https://github.com/max-sixty/worktrunk/releases/latest/download/worktrunk-x86_64-unknown-linux-musl.tar.xz | sudo tar -xJ -C /usr/local/bin --strip-components=1 worktrunk-x86_64-unknown-linux-musl/wt
) &
(
    command -v yq >/dev/null 2>&1 && [ "${FORCE:-}" != "1" ] || curl -fsSL -o /tmp/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && sudo install -m 0755 /tmp/yq /usr/local/bin/yq
) &
# open-design (workspace de design com agentes): build nativo do source. É o
# passo mais pesado daqui (pnpm install + build de ~20 pacotes), então roda
# junto do apt. O daemon é iniciado depois do `wait`, lá embaixo.
(
    [ -f "$HOME/open-design/apps/daemon/dist/cli.js" ] && [ -d "$HOME/open-design/apps/web/out" ] && [ "${FORCE:-}" != "1" ] || bash "$(dirname "$0")/scripts/install-open-design.sh"
) &

# ────────────────────────────────────────────────────────────────────────
#  Apt — repos primeiro (idempotente), 1 update, upgrade condicional,
#  1 install com tudo.
# ────────────────────────────────────────────────────────────────────────

log_step "Adicionando repos (fish, gh)"
sudo apt-add-repository ppa:fish-shell/release-4
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null

log_step "apt update"
sudo apt-get update

if [ "${SKIP_UPGRADE:-}" != "1" ]; then
    # Simula antes: upgrade só roda se houver pacotes a atualizar.
    # No restart do workspace, sem updates pendentes = pula em segundos.
    UPGRADES=$(apt-get -s upgrade 2>/dev/null | grep -c '^Inst' || true)
    if [ "$UPGRADES" -gt 0 ]; then
        log_step "System upgrade ($UPGRADES pacotes)"
        sudo apt upgrade -y
    else
        log_step "System upgrade (nada a atualizar — pulado)"
    fi
else
    log_step "System upgrade (SKIPPED — SKIP_UPGRADE=1)"
fi

log_step "apt install (fish, gh, CLI tools)"
sudo apt install -y --no-install-recommends \
    fish gh jq bat fzf eza ripgrep fd-find bubblewrap

# ────────────────────────────────────────────────────────────────────────
#  Espera os installers de home terminarem
# ────────────────────────────────────────────────────────────────────────

wait

export PATH="$HOME/.bun/bin:$HOME/.local/bin:$PATH"

# open-design: sobe o daemon (loopback 7456). Só aqui, depois do `wait`, o
# build em background já terminou; o script é no-op se não há build ou se já
# está rodando.
if [ -f "$HOME/open-design/apps/daemon/dist/cli.js" ]; then
    bash "$(dirname "$0")/scripts/open-design-serve.sh" || true
fi

# ────────────────────────────────────────────────────────────────────────
#  NVM + Node (sequencial — nvm precisa do shell)
# ────────────────────────────────────────────────────────────────────────

log_step "NVM + Node"
if [ ! -s "$HOME/.nvm/nvm.sh" ] || [ "${FORCE:-}" = "1" ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
fi
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
# shellcheck disable=SC1091
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm install node
nvm use node

# ────────────────────────────────────────────────────────────────────────
#  Configuração de shell (depende de fish + starship + nvm)
# ────────────────────────────────────────────────────────────────────────

log_step "Configuração de shell"
mkdir -p ~/.config/fish
cp "$(dirname "$0")/config.fish" ~/.config/fish/config.fish
# Idempotente: só adiciona a linha do node se ainda não existir
# (restart do workspace = home persiste = config.fish já tem).
NODE_BIN_DIR=$(dirname "$(nvm which current)")
if ! grep -qF "fish_add_path $NODE_BIN_DIR" ~/.config/fish/config.fish; then
  echo "fish_add_path $NODE_BIN_DIR" >> ~/.config/fish/config.fish
fi
starship preset no-runtime-versions -o ~/.config/starship.toml --force
# O preset não define add_newline e o default do starship é true → linha em
# branco antes de cada prompt. `starship config` edita a chave no arquivo.
starship config add_newline false
sudo chsh -s /usr/bin/fish
cp "$(dirname "$0")/bash_profile" ~/.bash_profile
cp "$(dirname "$0")/bashenv" ~/.bashenv

log_step "Fisher + fish plugins"
# Idempotente: só baixa o fisher se não estiver instalado (home persiste).
fish -c "if not functions -q fisher; curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source; end; fisher install jorgebucaran/fisher"
fish -c "fisher install icezyclon/zoxide.fish"

# Integração de shell do worktrunk: sem ela `wt switch` não faz cd.
# Idempotente (reescreve functions/wt.fish + completions).
log_step "Worktrunk shell integration"
mkdir -p ~/.config/fish/functions
wt config shell install fish --yes

# ────────────────────────────────────────────────────────────────────────
#  ~/.local/bin/env — shim de PATH do dotfiles do Coder. Como ~/.local/bin
#  vem antes de /usr/bin no PATH, o shim shadowa o env(1) real e (sem
#  passthrough) todo `env VAR=x cmd` vira no-op silencioso — é exatamente o
#  que o wrapper de shell do wt chama (env WORKTRUNK_DIRECTIVE_CD_FILE=...).
#  ~/.bashrc e ~/.profile dão `source` nele; só remenda a versão antiga.
# ────────────────────────────────────────────────────────────────────────

ENV_SHIM="$HOME/.local/bin/env"
if [ -f "$ENV_SHIM" ] && ! grep -qF 'exec /usr/bin/env "$@"' "$ENV_SHIM"; then
    log_step "Remendando shim ~/.local/bin/env (shadow de /usr/bin/env)"
    # Append (não overwrite): quando executado, delega ao env(1) real;
    # quando fonteado, $0 é o nome do shell e o append não roda.
    cat >> "$ENV_SHIM" <<'SHIM'

# Passthrough para o env(1) real quando este arquivo é EXECUTADO. O shell não
# executa ao dar `source` ($0 = nome do shell), então o PATH acima continua ok.
case "$0" in
    *env) exec /usr/bin/env "$@" ;;
esac
SHIM
fi

# ────────────────────────────────────────────────────────────────────────
#  Tailscale (idempotente; install.sh detecta a versão do ubuntu)
# ────────────────────────────────────────────────────────────────────────

if ! command -v tailscale >/dev/null 2>&1 || [ "${FORCE:-}" = "1" ]; then
    log_step "Tailscale install"
    curl -fsSL https://tailscale.com/install.sh | sh
fi

if [ "${OAUTH_CLIENT_SECRET:-}" != "" ]; then
    log_step "Tailscale up"
    # --state na home (NFS) e não no /var/lib/tailscale do container: sem isso
    # cada start registra um NÓ NOVO no tailnet ("work", "work-1", … "work-4")
    # porque o nome antigo fica preso num nó offline. O Coder disca o agent
    # pelo nome do nó, então a pilha de órfãos vira 502 intermitente
    # (`dial context: connect tcp [fd7a:…]:7456: connection was refused`).
    mkdir -p "$HOME/.tailscale"
    sudo nohup /usr/sbin/tailscaled --state="$HOME/.tailscale/tailscaled.state" > ~/tailscaled.log 2>&1 & disown
    # --accept-dns=false: container não tem systemd-resolved; sem a flag o
    # MagicDNS reescreve /etc/resolv.conf p/ 100.100.100.100 e todo lookup
    # externo (pypi, etc.) quebra após o `up`.
    sudo tailscale up --auth-key=$OAUTH_CLIENT_SECRET --advertise-tags=tag:coder --accept-dns=false
else
    log_step "Tailscale (SKIPPED — sem OAUTH_CLIENT_SECRET)"
fi

# ────────────────────────────────────────────────────────────────────────
#  DNS do container — o Docker herda o resolv.conf do host, que aponta para
#  100.100.100.100 (MagicDNS do host). Aqui dentro esse IP roteia pelo
#  tailscaled LOCAL, que está com --accept-dns=false e sem upstream →
#  SERVFAIL em toda query (pypi, crates, npm). Probe ativo: só reescreve se
#  a resolução de fato falhar, então é inofensivo onde o DNS funciona.
# ────────────────────────────────────────────────────────────────────────

if ! getent hosts pypi.org >/dev/null 2>&1; then
    log_step "DNS do container quebrado — trocando resolv.conf"
    printf 'nameserver 1.1.1.1\nnameserver 9.9.9.9\n' | sudo tee /etc/resolv.conf > /dev/null
fi

# ────────────────────────────────────────────────────────────────────────
#  uv tool packages
# ────────────────────────────────────────────────────────────────────────

log_step "uv tool packages"
# uv tool install: substituto do pipx (uv já instalado no bloco de installers).
# --force: venv quebrado de restart anterior (home persiste) seria pulado
# sem ele, e o binário apontaria pra um venv sem o módulo.
uv tool install --force skill-seekers
uv tool install --force code-review-graph
code-review-graph install

# ────────────────────────────────────────────────────────────────────────
#  Scripts + crontab
# ────────────────────────────────────────────────────────────────────────

log_step "copying scripts"
mkdir -p ~/.local/bin
cp -r "$(dirname "$0")"/scripts/* ~/.local/bin/ 2>/dev/null || true
chmod +x ~/.local/bin/* 2>/dev/null || true

log_step "copying crontab"
{
  if [ -n "${S3_ACCESS_KEY_ID:-}" ] && [ -n "${S3_SECRET_ACCESS_KEY:-}" ]; then
    echo "S3_ACCESS_KEY_ID=$S3_ACCESS_KEY_ID"
    echo "S3_SECRET_ACCESS_KEY=$S3_SECRET_ACCESS_KEY"
    echo "S3_ENDPOINT=${S3_ENDPOINT:-https://s3.gupve.dev}"
    echo "S3_BUCKET=${S3_BUCKET:-lobe}"
    echo "PATH=$HOME/.bun/bin:/usr/local/bin:/usr/bin:/bin"
  fi
  cat "$(dirname "$0")/crontab"
} | sudo tee /etc/cron.d/coder-template > /dev/null

# ────────────────────────────────────────────────────────────────────────
#  Bun globais + Playwright (E2E)
# ────────────────────────────────────────────────────────────────────────

log_step "bun global packages"
bun install -g @servicenow/sdk @oh-my-pi/pi-coding-agent playwright vercel skillkit bun-docx
# OpenDesign (e outros) só sabem procurar o runtime pelo comando `pi`; neste
# workspace o binário é `omp` (`pi-coding-agent` não expõe mais o nome `pi`).
# O shim faz `pi` resolver para o omp — as flags que o adapter do OpenDesign
# passa (`--mode rpc`, `--model`, `--thinking`, `--append-system-prompt`) são
# exatamente as que o omp aceita, e o handshake pi-RPC responde
# (`{"type":"ready","protocolVersion":1,...}`).
ln -sf "$HOME/.bun/bin/omp" "$HOME/.local/bin/pi"
# pi-caveman: plugin npm do omp (instalado via omp plugin install, não via
# comando `pi` — binário não existe no omp v18+). Já presente no home.
omp plugin install pi-caveman 2>/dev/null || true

if [ "${SKIP_PLAYWRIGHT:-}" != "1" ]; then
    log_step "Playwright Chromium (E2E)"
    bunx playwright install --with-deps chromium
else
    log_step "Playwright Chromium (SKIPPED — SKIP_PLAYWRIGHT=1)"
fi

log_step "✅ Provisionamento completo"
