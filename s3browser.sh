#!/bin/bash

# Check if required tools are installed
command -v aws >/dev/null 2>&1 || { echo "aws cli is required but not installed. Aborting." >&2; exit 1; }
command -v fzf >/dev/null 2>&1 || { echo "fzf is required but not installed. Aborting." >&2; exit 1; }

if [ "$1" = "--clear-cache" ]; then
    echo "Clearing cache..."
    rm -rf "$HOME/.s3browser"
    exit 0
fi

# Parse the input arguments
if [ $# -ge 1 ]; then
    input="$1"
    
    # Handle s3:// prefix
    if [[ "$input" == s3://* ]]; then
        # Remove s3:// prefix
        input="${input#s3://}"
    fi
    
    # Handle bucket/path format
    if [[ "$input" == */* ]]; then
        start_bucket="${input%%/*}"
        start_prefix="${input#*/}"
    else
        start_bucket="$input"
    fi
    
    # Handle second argument if provided (legacy format)
    if [ $# -ge 2 ]; then
        start_prefix="$2"
    fi
    
    # Split prefix into components for step-by-step navigation
    if [ -n "$start_prefix" ]; then
        split_start_prefix=(${start_prefix//\// })
    fi
fi

# Check if AWS CLI is properly configured and connected
aws sts get-caller-identity >/dev/null 2>&1 || { echo "AWS CLI is not properly configured or connected. $(aws sts get-caller-identity 2>&1)" >&2; exit 1; }

# Cache directory and file
CACHE_DIR="$HOME/.s3browser"
BUCKETS_CACHE="$CACHE_DIR/buckets.txt"
RECENT_BUCKETS_CACHE="$CACHE_DIR/recent_buckets.txt"

# Create cache directory if it doesn't exist
mkdir -p "$CACHE_DIR"
touch "$RECENT_BUCKETS_CACHE" 2>/dev/null

# Function to update recent buckets list
update_recent_buckets() {
    local bucket=$1
    local temp_file=$(mktemp)
    
    # Add current bucket at the top, remove duplicates, keep only last 20
    echo "$bucket" > "$temp_file"
    grep -v "^$bucket$" "$RECENT_BUCKETS_CACHE" | head -n 19 >> "$temp_file"
    mv "$temp_file" "$RECENT_BUCKETS_CACHE"
}

# Function to list buckets
list_buckets() {
    # Always get fresh bucket list and update cache
    aws s3 ls s3:// | awk '{printf "%-90s %s\n", $3, $1" "$2}' | sed 's/\/$//' | tee "$BUCKETS_CACHE"
    
    # Extract just the bucket names for completion
    awk '{print $1}' "$BUCKETS_CACHE" > "$CACHE_DIR/bucket_names.txt"
}

# Function to list objects in a bucket/path
list_objects() {
    local path=$1
    
    # Add .. option if not at bucket root
    if [[ "$path" != s3:// ]]; then
        echo ".."
    fi
    
    # List directories with <DIR> label
    aws s3 ls "$path/" | grep PRE | awk '{printf "%-90s <DIR>\n", $2}'
    
    # List files with date and size
    aws s3 ls --human-readable "$path/" | grep -v PRE | awk '{printf "%-90s %s %s %-5s %s\n", $5, $1, $2, $3, $4}'
}

# Extract name only from the formatted listing
extract_name() {
    echo "$1" | awk '{print $1}' | sed 's/\/$//'
}

# Function to handle file actions
handle_file_action() {
    local filepath=$1
    local filename=$(basename "$filepath")
    local isZip=false
    
    # Check if file is a zip
    if [[ "$filename" == *.zip ]]; then
        isZip=true
    fi
    
    # Create action menu with options
    options=(
        "Open in VSCode"
        "Open in Vi"
        "Open in Nano"
        "Open in Less"
        "Cat"
        "Copy S3 path"
        "Download"
        "Download and show in Finder"
        "Download and open in VSCode"
        "Download and open in Vi"
        "Download and open in Nano"
        ".."
    )
    
    # Add zip-specific options if file is a zip
    if $isZip; then
        options+=(
            "Download and unzip"
            "Download, unzip and show in Finder"
        )
    fi
    
    # Present options using fzf
    action=$(printf "%s\n" "${options[@]}" | fzf --header="Choose action for $filename:")
    [ -z "$action" ] && return
    
    # Handle selected action
    case "$action" in
        "Open in VSCode")
            # Create a temporary named pipe and stream content to it
            tmp_pipe="/tmp/${filename}.pipe"
            mkfifo "$tmp_pipe"
            aws s3 cp "$filepath" "$tmp_pipe" &
            code "$tmp_pipe"
            rm "$tmp_pipe"
            exit 0
            ;;
        "Open in Vi")
            aws s3 cp "$filepath" - | vi -
            exit 0
            ;;
        "Open in Nano")
            aws s3 cp "$filepath" - | nano -
            exit 0
            ;;
        "Open in Less")
            aws s3 cp "$filepath" - | less
            exit 0
            ;;
        "Cat")
            aws s3 cp "$filepath" -
            exit 0
            ;;
        "Copy S3 path")
            echo "$filepath" | pbcopy
            echo "Path copied to clipboard: $filepath"
            exit 0
            ;;
        "Download")
            read -e -p "Download path [default: ./$(basename "$filepath")]: " download_path
            download_path=${download_path:-"./$(basename "$filepath")"}
            aws s3 cp "$filepath" "$download_path"
            echo "Downloaded to $download_path"
            exit 0
            ;;
        "Download and show in Finder")
            read -e -p "Download path [default: ./$(basename "$filepath")]: " download_path
            download_path=${download_path:-"./$(basename "$filepath")"}
            aws s3 cp "$filepath" "$download_path"
            open -R "$download_path"
            exit 0
            ;;
        "Download and open in VSCode")
            read -e -p "Download path [default: ./$(basename "$filepath")]: " download_path
            download_path=${download_path:-"./$(basename "$filepath")"}
            aws s3 cp "$filepath" "$download_path"
            code "$download_path"
            exit 0
            ;;
        "Download and open in Vi")
            read -e -p "Download path [default: ./$(basename "$filepath")]: " download_path
            download_path=${download_path:-"./$(basename "$filepath")"}
            aws s3 cp "$filepath" "$download_path"
            vi "$download_path"
            exit 0
            ;;
        "Download and open in Nano")
            read -e -p "Download path [default: ./$(basename "$filepath")]: " download_path
            download_path=${download_path:-"./$(basename "$filepath")"}
            aws s3 cp "$filepath" "$download_path"
            nano "$download_path"
            exit 0
            ;;
        "Download and unzip")
            read -e -p "Download path [default: ./]: " download_dir
            download_dir=${download_dir:-"./"}
            aws s3 cp "$filepath" "$download_dir/$filename"
            unzip "$download_dir/$filename" -d "$download_dir"
            echo "Downloaded and unzipped to $download_dir"
            exit 0
            ;;
        "Download, unzip and show in Finder")
            read -e -p "Download path [default: ./]: " download_dir
            download_dir=${download_dir:-"./"}
            aws s3 cp "$filepath" "$download_dir/$filename"
            unzip "$download_dir/$filename" -d "$download_dir"
            open "$download_dir"
            exit 0
            ;;
        "..")
            return
            ;;
    esac
}

# Main loop
while true; do
    if [ -z "$start_bucket" ]; then
        # Get all buckets
        all_buckets=$(list_buckets)
        
        # Combine recent buckets with all buckets
        recent_with_details=""
        if [ -s "$RECENT_BUCKETS_CACHE" ]; then
            while IFS= read -r recent_bucket; do
                bucket_line=$(echo "$all_buckets" | grep "^$recent_bucket " || echo "")
                if [ -n "$bucket_line" ]; then
                    recent_with_details+="$bucket_line [RECENT]\n"
                fi
            done < "$RECENT_BUCKETS_CACHE"
        fi
        
        # Display recent buckets first, then all buckets
        tmp_buckets=$(printf "%b\n%s" "$recent_with_details" "$all_buckets")
        while true; do
            bucket_line=$(printf "Include pattern\nExclude pattern\n%s" "$tmp_buckets" | fzf --header="Select a bucket (Ctrl+C to exit):")
            [ -z "$bucket_line" ] && break 2
            if [ "$bucket_line" = "Include pattern" ]; then
                read -e -p "Include grep pattern: " pattern
                tmp_buckets=$(printf "%s\n" "$tmp_buckets" | grep -E "$pattern")
                continue
            elif [ "$bucket_line" = "Exclude pattern" ]; then
                read -e -p "Exclude grep pattern: " pattern
                tmp_buckets=$(printf "%s\n" "$tmp_buckets" | grep -Ev "$pattern")
                continue
            fi
            break
        done
        bucket=$(extract_name "$bucket_line")
    else
        bucket="$start_bucket"
        unset start_bucket
    fi
    
    # Update recent buckets list
    update_recent_buckets "$bucket"
        
    # Start with bucket root
    current_path="s3://$bucket"
    
    while true; do
        if [ -z "$split_start_prefix" ]; then
            # List objects in current path
            tmp_objects=$(list_objects "$current_path")
            while true; do
                selection_line=$(printf "Include pattern\nExclude pattern\n%s" "$tmp_objects" | fzf --header="Current path: $current_path (Ctrl+C to go to bucket selection)")
                [ -z "$selection_line" ] && break 2
                if [ "$selection_line" = "Include pattern" ]; then
                    read -e -p "Include grep pattern: " pattern
                    tmp_objects=$(printf "%s\n" "$tmp_objects" | grep -E "$pattern")
                    continue
                elif [ "$selection_line" = "Exclude pattern" ]; then
                    read -e -p "Exclude grep pattern: " pattern
                    tmp_objects=$(printf "%s\n" "$tmp_objects" | grep -Ev "$pattern")
                    continue
                fi
                break
            done
            selection=$(extract_name "$selection_line")
        else
            # select the first value from split_start_prefix
            selection=${split_start_prefix[0]}
            selection_line="$selection <DIR>"
            # ff split_start_prefix is of length 1 unset it
            echo "split_start_prefix: ${split_start_prefix[@]}"
            if [ ${#split_start_prefix[@]} -eq 1 ]; then
                unset split_start_prefix
            else
                # remove the first value from split_start_prefix
                split_start_prefix=("${split_start_prefix[@]:1}")
            fi
            # List objects in current path
        fi

        # Handle .. navigation
        if [ "$selection" = ".." ]; then
            # If at bucket root, break to bucket selection
            if [ "$current_path" = "s3://$bucket" ]; then
                break
            fi
            current_path=$(dirname "$current_path")
            continue
        fi
        
        # Check if selection is a directory
        if [[ "$selection_line" == *"<DIR>"* ]]; then
            current_path="$current_path/$selection"
        else
            # Handle file selection
            filepath="$current_path/$selection"
            handle_file_action "$filepath"
            break
        fi
    done
done
