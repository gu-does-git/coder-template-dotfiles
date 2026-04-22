# Starship prompt
eval "$(starship init fish)"

# Zoxide (smart cd)
zoxide init fish | source
alias cd z

# PATH
fish_add_path $HOME/.bun/bin
fish_add_path $HOME/.local/bin
fish_add_path $HOME/.deno/bin

