#!/usr/bin/env bash
#
# Usage:
#   ./install.sh         full macOS setup, then symlink dotfiles
#   ./install.sh link    only symlink dotfiles

set -uo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d-%H%M%S)"
BACKED_UP=0

print_success()  { printf "\e[0;32m  [✔] %s\e[0m\n" "$1"; }
print_error()    { printf "\e[0;31m  [✖] %s\e[0m\n" "$1"; }
print_question() { printf "\e[0;33m  [?] %s\e[0m" "$1"; }
step()           { printf "\n%s\n" "$1"; }

# Link $1 (in the repo) to $2. Anything already at $2 is moved into
# $BACKUP_DIR after confirmation, never deleted.
link_file() {
    local source_file="$1" target_file="$2"

    if [ "$(readlink "$target_file")" == "$source_file" ]; then
        print_success "$target_file → $source_file"
        return
    fi

    if [ -e "$target_file" ] || [ -L "$target_file" ]; then
        print_question "'$target_file' already exists, back it up and replace it? (y/n) "
        read -r -n 1 reply
        printf "\n"
        if [[ ! "$reply" =~ ^[Yy]$ ]]; then
            print_error "skipped $target_file"
            return
        fi
        mkdir -p "$BACKUP_DIR"
        mv "$target_file" "$BACKUP_DIR/"
        BACKED_UP=1
    fi

    mkdir -p "$(dirname "$target_file")"
    if ln -sfn "$source_file" "$target_file"; then
        print_success "$target_file → $source_file"
    else
        print_error "$target_file → $source_file"
    fi
}

link_dotfiles() {
    step "Symlinking dotfiles..."

    local path name
    for path in "$DOTFILES"/.[!.]*; do
        name="$(basename "$path")"
        case "$name" in
            .git|.gitignore|.githooks|.DS_Store) continue ;;
        esac
        link_file "$path" "$HOME/$name"
    done

    # Claude Code: link individual files, not the whole ~/.claude dir (it holds sessions and auth)
    link_file "$DOTFILES/claude/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
    link_file "$DOTFILES/claude/settings.json" "$HOME/.claude/settings.json"
    link_file "$DOTFILES/claude/hooks" "$HOME/.claude/hooks"
    link_file "$DOTFILES/claude/bin" "$HOME/.claude/bin"
    link_file "$DOTFILES/claude/agents" "$HOME/.claude/agents"
    link_file "$DOTFILES/claude/references" "$HOME/.claude/references"
    # Skills one by one: ~/.claude/skills also holds org-synced skills
    for path in "$DOTFILES"/claude/skills/*/; do
        link_file "${path%/}" "$HOME/.claude/skills/$(basename "$path")"
    done
    git -C "$DOTFILES" config core.hooksPath .githooks

    # Local-only Claude files, never committed
    mkdir -p "$HOME/.claude/private"
    [ -f "$HOME/.claude/private/client-terms.txt" ] ||
        printf '# Client terms the search guard blocks in outbound queries, one per line.\n' > "$HOME/.claude/private/client-terms.txt"

    [ "$BACKED_UP" -eq 1 ] && printf "\nReplaced files were backed up to %s\n" "$BACKUP_DIR"
}

install_macos() {
    if [ "$(uname)" != "Darwin" ]; then
        print_error "Full install only supports macOS. Run './install.sh link' to symlink only."
        exit 1
    fi

    if ! xcode-select -p &>/dev/null; then
        step "Installing Xcode CLI tools (re-run this script once they finish)..."
        xcode-select --install
        exit 0
    fi

    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        step "Installing Oh My Zsh..."
        RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    fi

    local zsh_path
    zsh_path="$(command -v zsh)"
    if [ "$SHELL" != "$zsh_path" ]; then
        step "Setting Zsh as the default shell..."
        chsh -s "$zsh_path"
    fi

    if ! command -v brew &>/dev/null; then
        step "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
    else
        step "Updating Homebrew and packages..."
        brew update && brew upgrade
    fi

    step "Installing packages from Brewfile..."
    brew bundle --file="$DOTFILES/Brewfile"

    step "Installing Python support for Neovim..."
    pip3 install pynvim || print_error "pynvim install failed; install it into your pyenv Python manually"

    if ! command -v rustup &>/dev/null && [ ! -x "$HOME/.cargo/bin/rustup" ]; then
        step "Installing Rust (rustup)..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
    fi

    step "Installing cargo tools..."
    "$HOME/.cargo/bin/cargo" install cargo-hack cargo-watch

    if [ ! -d "$HOME/.rvm" ]; then
        step "Installing RVM..."
        curl -sSL https://get.rvm.io | bash -s stable
    fi

    step "Installing fzf key bindings..."
    "$(brew --prefix)/opt/fzf/install" --key-bindings --completion --no-update-rc

    link_dotfiles

    printf "\nReload your terminal (source ~/.zshrc), then run 'nvim +PlugInstall' to install Neovim plugins.\n"
}

case "${1:-}" in
    link) link_dotfiles ;;
    "")   install_macos ;;
    *)    printf "Usage: %s [link]\n" "$0"; exit 1 ;;
esac
