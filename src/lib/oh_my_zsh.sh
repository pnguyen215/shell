#!/bin/bash
# oh_my_zsh.sh

# install_oh_my_zsh function
# Installs Oh My Zsh if it is not already present on the system.
#
# Usage:
#   install_oh_my_zsh [-n]
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, the installation command is printed using shell::on_evict instead of executed.
#
# Description:
#   The function checks whether the Oh My Zsh directory ($HOME/.oh-my-zsh) exists.
#   If it exists, it prints a message indicating that Oh My Zsh is already installed.
#   Otherwise, it proceeds to install Oh My Zsh by executing the installation script fetched via curl.
#   In dry-run mode, the command is displayed using shell::on_evict; otherwise, it is executed using shell::run_cmd_eval.
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
        shell::colored_echo "🍺 Oh My Zsh is already installed." 46
    else
        shell::colored_echo "🚀 Installing Oh My Zsh..." 33
        # Build the installation command
        local install_cmd="sh -c \"\$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)\""

        if [ "$dry_run" = "true" ]; then
            shell::on_evict "$install_cmd"
        else
            shell::run_cmd_eval "$install_cmd"
        fi

        # Optionally, customize Zsh theme and plugins after installation:
        # sed -i.bak 's/ZSH_THEME="robbyrussell"/ZSH_THEME="your_custom_theme"/' "$HOME/.zshrc"
        # plugins=(your_plugin1 your_plugin2)
        # sed -i.bak '/^plugins=(/a \ \ your_custom_plugin' "$HOME/.zshrc"
        shell::colored_echo "🟢 Oh-My-Zsh installed successfully!" 46
    fi
}

# shell::removal_oh_my_zsh function
# Uninstalls Oh My Zsh by removing its directory and restoring the original .zshrc backup if available.
#
# Usage:
#   shell::removal_oh_my_zsh [-n]
#
# Parameters:
#   - -n : Optional dry-run flag. If provided, the uninstallation commands are printed using shell::on_evict instead of executed.
#
# Description:
#   This function checks whether the Oh My Zsh directory ($HOME/.oh-my-zsh) exists.
#   If it does, the function proceeds to remove it using 'rm -rf'. Additionally, if a backup of the original .zshrc
#   (stored as $HOME/.zshrc.pre-oh-my-zsh) exists, it restores that backup by moving it back to $HOME/.zshrc.
#   In dry-run mode, the commands are displayed using shell::on_evict; otherwise, they are executed using shell::run_cmd_eval.
#
# Example:
#   shell::removal_oh_my_zsh         # Uninstalls Oh My Zsh if installed.
#   shell::removal_oh_my_zsh -n      # Displays the uninstallation commands without executing them.
shell::removal_oh_my_zsh() {
    local dry_run="false"

    # Check for the optional dry-run flag (-n)
    if [ "$1" = "-n" ]; then
        dry_run="true"
        shift
    fi

    local oh_my_zsh_dir="$HOME/.oh-my-zsh"

    if [ ! -d "$oh_my_zsh_dir" ]; then
        shell::colored_echo "🍺 Oh My Zsh is not installed." 46
        return 0
    fi

    shell::colored_echo "🚀 Uninstalling Oh My Zsh..." 33

    # Remove the Oh My Zsh directory
    local remove_cmd="rm -rf \"$oh_my_zsh_dir\""
    if [ "$dry_run" = "true" ]; then
        shell::on_evict "$remove_cmd"
    else
        shell::run_cmd_eval "$remove_cmd"
    fi

    # Restore the original .zshrc from backup if available
    local backup_zshrc="$HOME/.zshrc.pre-oh-my-zsh"
    local zshrc="$HOME/.zshrc"
    if [ -f "$backup_zshrc" ]; then
        local restore_cmd="mv \"$backup_zshrc\" \"$zshrc\""
        if [ "$dry_run" = "true" ]; then
            shell::on_evict "$restore_cmd"
            return 0
        else
            shell::run_cmd_eval "$restore_cmd"
        fi
        shell::colored_echo "🟢 Original .zshrc restored from backup." 46
    else
        shell::colored_echo "🍺 No backup .zshrc found. Please manually update your .zshrc if necessary." 33
    fi

    shell::colored_echo "🟢 Oh My Zsh uninstalled successfully!" 46
}
