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
if ! command -v fzf &>/dev/null; then
  case $(command -v brew apt-get dnf) in
    */brew) read -p "Install fzf using brew? ('brew install fzf') (y/n) " ans
            [[ $ans =~ ^[Yy]$ ]] && brew install fzf || { echo "Please install manually"; exit 1; };;
    */apt-get) read -p "Install fzf using apt-get? ('sudo apt-get install fzf') (y/n) " ans
               [[ $ans =~ ^[Yy]$ ]] && sudo apt-get install fzf || { echo "Please install manually"; exit 1; };;
    */dnf) read -p "Install fzf using dnf? ('sudo dnf install fzf') (y/n) " ans
           [[ $ans =~ ^[Yy]$ ]] && sudo dnf install fzf || { echo "Please install manually"; exit 1; };;
    *) echo "Install fzf manually"; exit 1;;
  esac
fi

# Create install directory
INSTALL_DIR="$HOME/.local/bin"
mkdir -p "$INSTALL_DIR"

# Determine the source directory
if [ -n "$1" ]; then
  DIR="$1"
else
  DIR=$(dirname "$0")
fi

# Copy the s3browser script to install directory
install -m755 "$DIR/s3browser.sh" "$INSTALL_DIR/s3browser"

# Copy the cwbrowser script to install directory
install -m755 "$DIR/cloudwatch-browser.sh" "$INSTALL_DIR/cwbrowser"

# Copy the uninstall script to install directory
install -m755 "$DIR/uninstall.sh" "$INSTALL_DIR/awsclibrowser-uninstall"

# Create completion directory if it doesn't exist
COMPLETION_DIR="$HOME/.s3browser/completion"
mkdir -p "$COMPLETION_DIR"

# Copy bash completion script
for ext in bash zsh; do
  install -m644 "$DIR/s3browser-completion.$ext" "$COMPLETION_DIR/s3browser-completion.$ext"
done

# Create env script to set PATH and completions
ENV_SCRIPT="$INSTALL_DIR/aws-browser-init.sh"
printf "export PATH=\"\$PATH:%s\"\n" "$INSTALL_DIR" > "$ENV_SCRIPT"

# Source env script from shell config
if [[ "$SHELL" == *"zsh"* ]]; then
  SHELL_CONFIG="$HOME/.zshrc"
  # Set up zsh completion
  COMP_DIR="$HOME/.zsh/completions"
  mkdir -p "$COMP_DIR"
  ln -sf "$COMPLETION_DIR/s3browser-completion.zsh" "$COMP_DIR/_s3browser"
  
  # Add completion setup to env script
  printf "fpath=(\$fpath %s)\nautoload -U compinit && compinit\n" "$COMP_DIR" >> "$ENV_SCRIPT"
elif [[ "$SHELL" == *"bash"* ]]; then
  SHELL_CONFIG="$HOME/.bashrc"
  if [[ "$(uname)" == "Darwin" && -f "$HOME/.bash_profile" ]]; then
    SHELL_CONFIG="$HOME/.bash_profile"
  fi
  # Add bash completion to env script
  printf "source \"%s\"\n" "$COMPLETION_DIR/s3browser-completion.bash" >> "$ENV_SCRIPT"
else
  echo "Unsupported shell. Please source $ENV_SCRIPT manually."
  exit 0
fi

if ! grep -Fxq "source $ENV_SCRIPT" "$SHELL_CONFIG"; then
  echo "source $ENV_SCRIPT" >> "$SHELL_CONFIG"
  echo "Added source $ENV_SCRIPT to $SHELL_CONFIG"
fi

echo "s3browser and cwbrowser have been installed successfully!"
echo "Run 's3browser' to start browsing your S3 buckets."
echo "Run 'cwbrowser' to start browsing your CloudWatch logs."
echo "Shell completion will be available after restarting your terminal or running: source $SHELL_CONFIG" 