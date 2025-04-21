#!/bin/bash

echo "Installing s3browser and cwbrowser..."

# Check if required tools are installed
echo "Checking dependencies..."

# Check for AWS CLI
if ! command -v aws &> /dev/null; then
    echo "AWS CLI not found. Please install it first."
    echo "Visit: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
    exit 1
fi

# Check for FZF
if ! command -v fzf &> /dev/null; then
    echo "FZF not found. Would you like to install it? (y/n)"
    read -r answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        # Install FZF based on available package manager
        if command -v brew &> /dev/null; then
            brew install fzf
        elif command -v apt-get &> /dev/null; then
            sudo apt-get install fzf
        elif command -v dnf &> /dev/null; then
            sudo dnf install fzf
        else
            echo "Please install FZF manually: https://github.com/junegunn/fzf#installation"
            exit 1
        fi
    else
        echo "FZF is required. Please install it manually."
        echo "Visit: https://github.com/junegunn/fzf#installation"
        exit 1
    fi
fi

# Create install directory
INSTALL_DIR="$HOME/.local/bin"
mkdir -p "$INSTALL_DIR"

# Copy the s3browser script to install directory
cp "$(dirname "$0")/s3browser.sh" "$INSTALL_DIR/s3browser"
chmod +x "$INSTALL_DIR/s3browser"

# Copy the cwbrowser script to install directory
cp "$(dirname "$0")/cloudwatch-browser.sh" "$INSTALL_DIR/cwbrowser"
chmod +x "$INSTALL_DIR/cwbrowser"

# Create completion directory if it doesn't exist
COMPLETION_DIR="$HOME/.s3browser/completion"
mkdir -p "$COMPLETION_DIR"

# Copy bash completion script
if [ -f "$(dirname "$0")/s3browser-completion.bash" ]; then
    cp "$(dirname "$0")/s3browser-completion.bash" "$COMPLETION_DIR/s3browser-completion.bash"
else
    echo "Bash completion script not found, creating one..."
    cp -f "$(dirname "$0")/create-completion-scripts.sh" "$COMPLETION_DIR/create-completion-scripts.sh" 2>/dev/null || true
    chmod +x "$COMPLETION_DIR/create-completion-scripts.sh" 2>/dev/null || true
fi

# Copy zsh completion script
if [ -f "$(dirname "$0")/s3browser-completion.zsh" ]; then
    cp "$(dirname "$0")/s3browser-completion.zsh" "$COMPLETION_DIR/s3browser-completion.zsh"
else
    echo "Zsh completion script not found, creating one..."
    # Will be created by create-completion-scripts.sh
fi

# Check if install directory is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    echo "Adding $INSTALL_DIR to your PATH..."
    
    # Determine shell config file
    SHELL_CONFIG=""
    if [[ "$SHELL" == *"zsh"* ]]; then
        SHELL_CONFIG="$HOME/.zshrc"
    elif [[ "$SHELL" == *"bash"* ]]; then
        SHELL_CONFIG="$HOME/.bashrc"
        # Also check for .bash_profile on macOS
        if [[ "$(uname)" == "Darwin" && -f "$HOME/.bash_profile" ]]; then
            SHELL_CONFIG="$HOME/.bash_profile"
        fi
    else
        echo "Unsupported shell. Please add $INSTALL_DIR to your PATH manually."
    fi
    
    if [[ -n "$SHELL_CONFIG" ]]; then
        echo "export PATH=\"\$PATH:$INSTALL_DIR\"" >> "$SHELL_CONFIG"
        echo "Added $INSTALL_DIR to $SHELL_CONFIG"
    fi
fi

# Add shell completion
if [[ "$SHELL" == *"zsh"* ]]; then
    COMPLETION_PATH="$COMPLETION_DIR/s3browser-completion.zsh"
    COMP_DIR="$HOME/.zsh/completions"
    mkdir -p "$COMP_DIR"
    
    # Create symlink to completion file
    ln -sf "$COMPLETION_PATH" "$COMP_DIR/_s3browser"
    
    # Check if completions dir is in fpath
    if ! grep -q "fpath=(\$fpath $COMP_DIR)" "$HOME/.zshrc"; then
        echo "# S3Browser completion" >> "$HOME/.zshrc"
        echo "fpath=(\$fpath $COMP_DIR)" >> "$HOME/.zshrc"
        echo "autoload -U compinit && compinit" >> "$HOME/.zshrc"
    fi
    
    echo "Added zsh completion for s3browser"
elif [[ "$SHELL" == *"bash"* ]]; then
    COMPLETION_PATH="$COMPLETION_DIR/s3browser-completion.bash"
    
    # Source completion file in bash config
    if [[ -f "$SHELL_CONFIG" ]]; then
        if ! grep -q "source $COMPLETION_PATH" "$SHELL_CONFIG"; then
            echo "# S3Browser completion" >> "$SHELL_CONFIG"
            echo "source $COMPLETION_PATH" >> "$SHELL_CONFIG"
        fi
    fi
    
    echo "Added bash completion for s3browser"
fi

echo "s3browser and cwbrowser have been installed successfully!"
echo "Run 's3browser' to start browsing your S3 buckets."
echo "Run 'cwbrowser' to start browsing your CloudWatch logs."
echo "Shell completion will be available after restarting your terminal or running: source $SHELL_CONFIG" 