#!/bin/bash

echo "Uninstalling s3browser and cwbrowser..."

# Define paths
INSTALL_DIR="$HOME/.local/bin"
COMPLETION_DIR="$HOME/.s3browser/completion"
ENV_SCRIPT="$INSTALL_DIR/aws-browser-init.sh"

# Remove binaries
rm -f "$INSTALL_DIR/s3browser"
rm -f "$INSTALL_DIR/cwbrowser"
echo "Removed binaries"

# Determine shell config file
if [[ "$SHELL" == *"zsh"* ]]; then
  SHELL_CONFIG="$HOME/.zshrc"
  COMP_DIR="$HOME/.zsh/completions"
  rm -f "$COMP_DIR/_s3browser"
  echo "Removed zsh completion"
elif [[ "$SHELL" == *"bash"* ]]; then
  SHELL_CONFIG="$HOME/.bashrc"
  if [[ "$(uname)" == "Darwin" && -f "$HOME/.bash_profile" ]]; then
    SHELL_CONFIG="$HOME/.bash_profile"
  fi
fi

# Remove source line from shell config
if [[ -f "$SHELL_CONFIG" ]]; then
  sed -i.bak "/source $ENV_SCRIPT/d" "$SHELL_CONFIG"
  rm -f "${SHELL_CONFIG}.bak"
  echo "Removed source line from $SHELL_CONFIG"
fi

# Remove environment script
rm -f "$ENV_SCRIPT"
echo "Removed environment script"

# Remove completion directory 
rm -rf "$COMPLETION_DIR"
if [ -d "$HOME/.s3browser" ] && [ -z "$(ls -A "$HOME/.s3browser")" ]; then
  rmdir "$HOME/.s3browser"
fi
echo "Removed completion files"

echo "s3browser and cwbrowser have been uninstalled successfully!" 