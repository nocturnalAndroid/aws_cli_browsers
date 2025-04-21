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