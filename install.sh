#!/bin/bash

log_step() {
    printf "\n\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"
    printf "\033[1;36m  ▶ %s\033[0m\n" "$1"
    printf "\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m\n"
}

log_step "System update"
sudo apt update && sudo apt upgrade -y

log_step "Fish shell"
sudo apt-add-repository ppa:fish-shell/release-4
sudo apt update
sudo apt install fish --yes

log_step "NVM + Node"
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm
nvm install node
nvm use node

log_step "Bun"
curl -fsSL https://bun.sh/install | bash
export PATH="$HOME/.bun/bin:$HOME/.local/bin:$PATH"

log_step "Starship"
curl -sS https://starship.rs/install.sh | sh -s -- -y
mkdir -p ~/.config/fish
cp "$(dirname "$0")/config.fish" ~/.config/fish/config.fish
echo "fish_add_path $(dirname $(nvm which current))" >> ~/.config/fish/config.fish
starship preset no-runtime-versions -o ~/.config/starship.toml
sudo chsh -s /usr/bin/fish
cp "$(dirname "$0")/bash_profile" ~/.bash_profile
cp "$(dirname "$0")/bashenv" ~/.bashenv

log_step "Zoxide"
curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh

log_step "Fisher + fish plugins"
fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher"
fish -c "fisher install icezyclon/zoxide.fish"

log_step "Deno"
curl -fsSL https://deno.land/install.sh | sh

log_step "Tailscale"
if [ "$OAUTH_CLIENT_SECRET" != "" ] ; then
    curl -fsSL https://tailscale.com/install.sh | sh
    sudo nohup /usr/sbin/tailscaled > ~/tailscaled.log 2>&1 & disown
    sudo tailscale up --auth-key=$OAUTH_CLIENT_SECRET --advertise-tags=tag:coder
fi

log_step "UV"
curl -LsSf https://astral.sh/uv/install.sh | sh

log_step "Claude Code"
curl -fsSL https://claude.ai/install.sh | bash

log_step "Beads"
curl -fsSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash

log_step "pipx packages"
pipx install --force skill-seekers
pipx install code-review-graph
code-review-graph install

log_step "bun global packages"
bun install -g @servicenow/sdk @oh-my-pi/pi-coding-agent playwright
pi install git:github.com/jonjonrankin/pi-caveman
bunx playwright install --with-deps chromium
