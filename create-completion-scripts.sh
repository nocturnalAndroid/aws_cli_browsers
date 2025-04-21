#!/bin/bash

# This script creates shell completion scripts for s3browser
# It's used by the installer if the completion scripts aren't found

COMPLETION_DIR="$HOME/.s3browser/completion"
mkdir -p "$COMPLETION_DIR"

# Create bash completion script
echo "Creating bash completion script..."
cat > "$COMPLETION_DIR/s3browser-completion.bash" << 'EOF'
_s3browser_complete() {
    local cur prev
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Complete bucket names from cache if it's the first argument
    if [[ $COMP_CWORD -eq 1 && -f "$HOME/.s3browser/bucket_names.txt" ]]; then
        COMPREPLY=( $(compgen -W "$(cat "$HOME/.s3browser/bucket_names.txt")" -- "$cur") )
        return 0
    fi

    return 0
}

complete -F _s3browser_complete s3browser
EOF

# Create zsh completion script
echo "Creating zsh completion script..."
cat > "$COMPLETION_DIR/s3browser-completion.zsh" << 'EOF'
#compdef s3browser

_s3browser() {
    local -a buckets
    local cache_file="$HOME/.s3browser/bucket_names.txt"

    # Complete bucket names from cache if it's the first argument
    if [[ $CURRENT -eq 2 && -f "$cache_file" ]]; then
        buckets=( ${(f)"$(<$cache_file)"} )
        _describe -t buckets 'S3 buckets' buckets
        return 0
    fi

    return 1
}

_s3browser "$@"
EOF

echo "Completion scripts created in $COMPLETION_DIR" 