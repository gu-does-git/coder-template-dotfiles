# Sem banner de boas-vindas
set -g fish_greeting

# Starship prompt
eval "$(starship init fish)"

# PATH
fish_add_path $HOME/.bun/bin
fish_add_path $HOME/.local/bin
fish_add_path $HOME/.deno/bin

# Aliases
alias cat bat
alias ls eza
alias ll "eza -la"
alias la "eza -a"
