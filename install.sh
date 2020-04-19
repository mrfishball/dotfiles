#!/usr/bin/env bash

if [ "$(uname)" == "Darwin" ]; then
    echo "\\nMacOS detected..."
    echo "\\nInstalling XCode CLI tools..."
    sudo xcode-select --install
    sudo xcodebuild -license
    echo "Done"

    if test ! "$( command -v brew )"; then
        echo "\\nInstalling homebrew..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
        echo "Done"
    else
        echo "\\nHomebrew already installed..."

        echo "\\nUpdating Homebrew..."
        brew update
        echo "Done"

        echo "\\nUpdating all Homebrew Packages..."
        brew upgrade
        echo "Done"
    fi

    echo "\\nTapping Homebrew/bundle..."
    brew tap Homebrew/bundle
    echo "Done"

    # install brew dependencies from Brewfile
    echo "\\nInstall packages from Brewfile..."
    brew bundle
    echo "Done"

    echo "\\nInstalling Python for Neovim..."
    pip3 install pynvim
    echo "Done"

    echo "\\nInstaling Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    echo "Done"

    zsh_path="$( command -v zsh )"
    if [[ "$SHELL" != "$zsh_path" ]]; then
        echo "\\nSetting Zsh as the default shell..."
        chsh -s "$zsh_path"
        echo "Done"
    fi

    if test ! "$( command -v rvm )"; then
        echo "\\nInstalling RVM..."
        sh -c "$(curl -sSL https://get.rvm.io)"
        echo "Done"
    fi

    echo "\\nInstall fzf key bindings..."
    $(brew --prefix)/opt/fzf/install
    echo "\\nDone"

    source link.sh

    echo "\\n\\nYou'll need to reload your terminal with ($ source ~/.zshrc)"
    echo "After the terminal is reloaded, you'll need to run ($ nvim +PlugInstall) to install all the Neovim plugins."
fi
