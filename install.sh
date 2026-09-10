#!/bin/bash
#
# Provisionador de ambiente do workspace coder.
# Otimizado: upgrade opcional, idempotente, downloads paralelos.
#
# Flags:
#   SKIP_UPGRADE=1   pula `apt upgrade` (sistema inteiro — o passo mais lento)
#   SKIP_PLAYWRIGHT=1 pula o download do Chromium (E2E não precisa)
#   FORCE=1          re-instala mesmo se já presente
#
set -euo pipefail

log_step() {
    printf "\n\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"
    printf "\033[1;36m  ▶ %s\033[0m\n" "$1"
    printf "\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"
}

# ────────────────────────────────────────────────────────────────────────
#  Apt (sequencial — apt não paraleliza)
# ────────────────────────────────────────────────────────────────────────

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

log_step "Fish shell"
if ! command -v fish >/dev/null 2>&1 || [ "${FORCE:-}" = "1" ]; then
    sudo apt-add-repository ppa:fish-shell/release-4
    sudo apt update
fi
sudo apt install fish --yes --no-install-recommends

log_step "GitHub CLI"
if ! command -v gh >/dev/null 2>&1 || [ "${FORCE:-}" = "1" ]; then
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update
fi
sudo apt install gh -y --no-install-recommends

log_step "CLI tools"
sudo apt install -y --no-install-recommends jq bat fzf eza ripgrep fd-find bubblewrap

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
#  Installers independentes — paralelo
# ────────────────────────────────────────────────────────────────────────

log_step "Installers em paralelo (bun, starship, zoxide, deno, uv, claude, beads, timetrace)"
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
wait

export PATH="$HOME/.bun/bin:$HOME/.local/bin:$PATH"

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
sudo chsh -s /usr/bin/fish
cp "$(dirname "$0")/bash_profile" ~/.bash_profile
cp "$(dirname "$0")/bashenv" ~/.bashenv

log_step "Fisher + fish plugins"
fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher"
fish -c "fisher install icezyclon/zoxide.fish"

# ────────────────────────────────────────────────────────────────────────
#  Tailscale (opcional — só com OAUTH_CLIENT_SECRET)
# ────────────────────────────────────────────────────────────────────────

if [ "${OAUTH_CLIENT_SECRET:-}" != "" ]; then
    log_step "Tailscale"
    curl -fsSL https://tailscale.com/install.sh | sh
    sudo nohup /usr/sbin/tailscaled > ~/tailscaled.log 2>&1 & disown
    sudo tailscale up --auth-key=$OAUTH_CLIENT_SECRET --advertise-tags=tag:coder
else
    log_step "Tailscale (SKIPPED — sem OAUTH_CLIENT_SECRET)"
fi

# ────────────────────────────────────────────────────────────────────────
#  Pipx
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
