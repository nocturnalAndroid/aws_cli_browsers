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