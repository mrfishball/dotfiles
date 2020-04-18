#!/usr/bin/env bash

command_exists() {
    type "$1" > /dev/null 2>&1
}

echo "Installing dotfiles."

# only perform macOS-specific install
if [ "$(uname)" == "Darwin" ]; then
    echo -e "\\n\\nRunning on macOS"
    sudo xcode-select --install
    sudo xcodebuild -license

    if test ! "$( command -v brew )"; then
        echo "Installing homebrew"
        ruby -e "$( curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install )"
    fi

    brew tap Homebrew/bundle

    # install brew dependencies from Brewfile
    brew bundle

    # after the install, install neovim python libraries
    echo -e "\\n\\nRunning Neovim Python install"
    echo "=============================="
    pip3 install pynvim

    if ! command_exists zsh; then
        echo "zsh not found. Please install and then re-run installation scripts"
        exit 1
    elif ! [[ $SHELL =~ .*zsh.* ]]; then
        echo "Configuring zsh as default shell"
        chsh -s "$(command -v zsh)"
    fi

    # Change the default shell to zsh
    zsh_path="$( command -v zsh )"
    if ! grep "$zsh_path" /etc/shells; then
        echo "adding $zsh_path to /etc/shells"
        echo "$zsh_path" | sudo tee -a /etc/shells
    fi

    if [[ "$SHELL" != "$zsh_path" ]]; then
        chsh -s "$zsh_path"
        echo "default shell changed to $zsh_path"
    fi

    echo "Done. Reload your terminal."
fi

source link.sh
