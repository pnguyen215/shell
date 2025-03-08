#!/bin/bash
# oh_my_zsh.sh

# install_oh_my_zsh function
# Installs Oh My Zsh if it is not already present on the system.
#
# Usage:
#   install_oh_my_zsh [-n]
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, the installation command is printed using on_evict instead of executed.
#
# Description:
#   The function checks whether the Oh My Zsh directory ($HOME/.oh-my-zsh) exists.
#   If it exists, it prints a message indicating that Oh My Zsh is already installed.
#   Otherwise, it proceeds to install Oh My Zsh by executing the installation script fetched via curl.
#   In dry-run mode, the command is displayed using on_evict; otherwise, it is executed using run_cmd_eval.
#
# Example:
#   install_oh_my_zsh         # Installs Oh My Zsh if needed.
#   install_oh_my_zsh -n      # Prints the installation command without executing it.
install_oh_my_zsh() {
    local dry_run="false"

    # Check for the optional dry-run flag (-n)
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    local oh_my_zsh_dir="$HOME/.oh-my-zsh"

    if [ -d "$oh_my_zsh_dir" ]; then
        colored_echo "🍺 Oh My Zsh is already installed." 46
    else
        colored_echo "🚀 Installing Oh My Zsh..." 33
        # Build the installation command
        local install_cmd="sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)\""

        if [ "$dry_run" = "true" ]; then
            on_evict "$install_cmd"
        else
            run_cmd_eval "$install_cmd"
        fi

        # Optionally, customize Zsh theme and plugins after installation:
        # sed -i.bak 's/ZSH_THEME="robbyrussell"/ZSH_THEME="your_custom_theme"/' "$HOME/.zshrc"
        # plugins=(your_plugin1 your_plugin2)
        # sed -i.bak '/^plugins=(/a \ \ your_custom_plugin' "$HOME/.zshrc"
        colored_echo "🟢 Oh-My-Zsh installed successfully!" 46
    fi
}
