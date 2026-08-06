# Raw .zshrc
# This file is symlinked by Home Manager from your dotfiles repository.
# You can edit this file directly in your Git repository.

# Custom PATH and environment configurations
export PATH="$HOME/.local/bin:$HOME/.opencode/bin:$PATH"
export DYLD_FALLBACK_LIBRARY_PATH="/opt/homebrew/lib"

# Dotfiles repository root (override via env var if needed)
export DOTFILES_DIR="${DOTFILES_DIR:-$HOME/workspace/dotfiles}"

# Nix Daemon Setup
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
  . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi

# Retro DOS / 1dir+ Color Scheme
export LS_COLORS="di=1;33:ex=1;32:ln=1;36:*.txt=1;38;5;231:*.md=1;38;5;231:*.pdf=1;38;5;231:*.doc=1;38;5;231:*.docx=1;38;5;231:*.rtf=1;38;5;231:*.odt=1;38;5;231:*.epub=1;38;5;231:*.py=1;36:*.js=1;36:*.ts=1;36:*.nix=1;36:*.rs=1;36:*.go=1;36:*.c=1;36:*.cpp=1;36:*.h=1;36:*.json=1;36:*.xml=1;36:*.png=1;35:*.jpg=1;35:*.jpeg=1;35:*.gif=1;35:*.svg=1;35:*.bmp=1;35:*.mp3=1;35:*.mp4=1;35:*.wav=1;35:*.mov=1;35:*.mkv=1;35:*.zip=1;31:*.tar=1;31:*.gz=1;31:*.tgz=1;31:*.rar=1;31:*.7z=1;31:*.bz2=1;31:*.conf=1;30:*.ini=1;30:*.yaml=1;30:*.yml=1;30:*.env=1;30:*.plist=1;30"
export EZA_COLORS="$LS_COLORS"

# Enable colors and syntax highlighting for ls (using eza if available)
if command -v eza &> /dev/null; then
  alias ls="eza --color=always --icons -F"
  alias ll="eza -lah --icons"
  alias la="eza -a --icons"
  alias l="eza -F --icons"
else
  # Fallback to standard ls colors
  if [ "$(uname)" = "Darwin" ]; then
    export CLICOLOR=1
    export LSCOLORS=GxFxCxDxBxegedabagaced
    alias ls="ls -GF"
  else
    alias ls="ls --color=auto -F"
  fi
  alias ll="ls -lah"
  alias la="ls -A"
  alias l="ls -CF"
fi

# Custom Aliases
alias g="git"
alias gs="git status"
alias gd="git diff"
alias gp="git push"
alias gc="git commit"
alias lgit="lazygit"

# Navigation shortcuts (useful for Warp which bypasses ZLE widgets)
alias ..="cd .."
alias -g ...="../.."
alias -g ....="../../.."
alias -g .....="../../../.."

# Colorize grep and diff output
alias grep="grep --color=auto"
alias egrep="egrep --color=auto"
alias fgrep="fgrep --color=auto"

if diff --color /dev/null /dev/null &> /dev/null; then
  alias diff="diff --color=auto"
fi

# Use dust instead of du for disk usage charts
alias du="dust"

# Home Manager Helper Aliases
alias hms='home-manager switch --flake "$DOTFILES_DIR#macbook" --impure'
alias hms-linux='home-manager switch --flake "$DOTFILES_DIR#linux-workstation" --impure'

# Set up interactive prompt
if command -v starship &> /dev/null; then
  eval "$(starship init zsh)"
else
  PROMPT='%F{cyan}%n%f@%F{blue}%m%f %F{green}%~%f %# '
fi

# Syntax highlighting for less and cat using bat (falls back to source-highlight)
if command -v bat &> /dev/null; then
  alias cat="bat"
  export LESSOPEN="| bat --color=always --style=plain %s"
  export LESS="-R"
elif command -v src-hilite-lesspipe.sh &> /dev/null; then
  export LESSOPEN="| src-hilite-lesspipe.sh %s"
  export LESS="-R"
fi

# Colorized man pages in less
export LESS_TERMCAP_mb=$'\E[1;31m'
export LESS_TERMCAP_md=$'\E[1;36m'
export LESS_TERMCAP_me=$'\E[0m'
export LESS_TERMCAP_se=$'\E[0m'
export LESS_TERMCAP_so=$'\E[01;44;33m'
export LESS_TERMCAP_ue=$'\E[0m'
export LESS_TERMCAP_us=$'\E[1;4;32m'

# Set up fzf (command-line fuzzy finder)
if command -v fzf &> /dev/null; then
  source <(fzf --zsh)
  export FZF_DEFAULT_OPTS="--preview 'bat --color=always --style=numbers --line-range :500 {}'"
fi

# Load zsh-syntax-highlighting (must be sourced at the very end of .zshrc)
for highlight_path in "$HOME/.nix-profile/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
  "$HOME/.local/state/nix/profile/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
  "/opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
  "/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"; do
  if [ -f "$highlight_path" ]; then
    source "$highlight_path"
    break
  fi
done

# Load zsh-autosuggestions (sourced after syntax highlighting)
for suggestions_path in "$HOME/.nix-profile/share/zsh-autosuggestions/zsh-autosuggestions.zsh" \
  "$HOME/.local/state/nix/profile/share/zsh-autosuggestions/zsh-autosuggestions.zsh" \
  "/opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh" \
  "/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh"; do
  if [ -f "$suggestions_path" ]; then
    source "$suggestions_path"
    break
  fi
done

# Load direnv hook (automatically loads directory-local nix environments)
if command -v direnv &> /dev/null; then
  eval "$(direnv hook zsh)"
fi

# Launch fastfetch on startup for interactive shells
if [[ -o interactive ]] && command -v fastfetch &> /dev/null; then
  fastfetch
fi

# Enable auto-cd (typing directory path will cd into it)
setopt autocd

# Dynamically expand ... to ../.. and .... to ../../..
expand-dots() {
  if [[ $LBUFFER = *.. ]]; then
    LBUFFER+=/..
  else
    LBUFFER+=.
  fi
}
zle -N expand-dots
bindkey -M emacs . expand-dots
bindkey -M viins . expand-dots
bindkey -M main . expand-dots
