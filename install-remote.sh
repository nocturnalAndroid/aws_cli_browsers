#!/bin/bash

# Define the repository base URL
REPO_URL="https://raw.githubusercontent.com/nocturnalAndroid/aws_cli_browsers/main"

# Files to download
FILES=(
  "install.sh"
  "s3browser.sh"
  "cloudwatch-browser.sh"
  "s3browser-completion.bash"
  "s3browser-completion.zsh"
  "uninstall.sh"
)

# Create a temporary directory
TMP_DIR=$(mktemp -d)
if [ ! -d "$TMP_DIR" ]; then
  echo "Failed to create temporary directory"
  exit 1
fi

echo "Downloading files to $TMP_DIR..."

# Download files
for file in "${FILES[@]}"; do
  echo "Downloading $file..."
  if ! curl -fsSL "$REPO_URL/$file" -o "$TMP_DIR/$file"; then
    echo "Error downloading $file"
    rm -rf "$TMP_DIR" # Clean up
    exit 1
  fi
done

echo "Making install.sh executable..."
chmod +x "$TMP_DIR/install.sh"

echo "Running installer..."
# Pass the temporary directory path to install.sh so it knows where the other scripts are
bash "$TMP_DIR/install.sh" "$TMP_DIR"

echo "Cleaning up..."
rm -rf "$TMP_DIR"

echo "Installation complete." 