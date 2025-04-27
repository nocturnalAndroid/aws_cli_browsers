#!/bin/bash

# Function to display help message
display_help() {
    cat << EOF
Usage: $(basename "$0") [<log-group-name> [<log-stream-name>]] | [--help] | [--uninstall] | [--clear-cache [--all]] | [--search-stream|-s <stream_name>]

Interactively browse CloudWatch Logs groups and streams using fzf.

Arguments:
  <log-group-name>      Optional. Start browsing directly in the specified log group.
  <log-stream-name>     Optional. If <log-group-name> is provided, start directly at this log stream.

Options:
  --help, -h            Display this help message and exit.
  --uninstall           Uninstall the s3browser and cwbrowser tools.
  --clear-cache [--all] Clear the cache directory (~/.cwbrowser/$AWS_PROFILE_NAME).
                        Use --all to clear the cache for all profiles (~/.cwbrowser).
  --search-stream, -s <stream_name>
                        Search for <stream_name> within recent log groups and navigate directly if found.

Environment Variables:
  AWS_PROFILE           Specifies the AWS profile to use (defaults to 'default'). Caching is profile-specific.

Dependencies:
  aws cli               Required for CloudWatch Logs operations.
  fzf                   Required for interactive navigation.

Examples:
  $(basename "$0")                               # Start browsing from the log group list.
  $(basename "$0") /aws/lambda/my-function       # Start browsing in the specified log group.
  $(basename "$0") /aws/lambda/my-function 2024/07/21/[$LATEST]abcdef
                                               # Start browsing specific stream in the group.
  $(basename "$0") -s my-specific-stream-id      # Search for 'my-specific-stream-id' in recent groups.
EOF
    exit 0
}

# Check if required tools are installed
command -v aws >/dev/null 2>&1 || { echo "aws cli is required but not installed. Aborting." >&2; exit 1; }
command -v fzf >/dev/null 2>&1 || { echo "fzf is required but not installed. Aborting." >&2; exit 1; }

if [ "$1" = "--uninstall" ]; then
    echo "WARNING: This will uninstall both s3browser and cwbrowser commands."
    read -p "Do you want to continue? (y/n): " confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        echo "Running uninstall script..."
        "$HOME/.local/bin/awsclibrowser-uninstall"
        exit 0
    else
        echo "Uninstall cancelled."
        exit 1
    fi
fi

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    display_help
fi

# Get current AWS profile
AWS_PROFILE_NAME=${AWS_PROFILE:-default}

# Cache directory and files
CACHE_DIR="$HOME/.cwbrowser/$AWS_PROFILE_NAME"
GROUPS_CACHE="$CACHE_DIR/log_groups.txt"
RECENT_GROUPS_CACHE="$CACHE_DIR/recent_groups.txt"
CACHE_ERROR_LOG="$CACHE_DIR/cache_errors.log"

# Create cache directory if it doesn't exist
mkdir -p "$CACHE_DIR"

# Check for previous cache update errors
if [ -s "$CACHE_ERROR_LOG" ]; then
    echo "⚠️  WARNING: Previous cache update had errors:"
    cat "$CACHE_ERROR_LOG"
    echo ""
    read -p "Would you like to clear the error log and continue? (y/n): " choice
    if [[ $choice =~ ^[Yy]$ ]]; then
        rm -f "$CACHE_ERROR_LOG"
        echo "Error log cleared. Continuing..."
    else
        echo "Exiting due to previous errors. Use --clear-cache to reset cache."
        exit 1
    fi
fi

if [ "$1" = "--clear-cache" ]; then
    echo "Clearing cache..."
    if [ "$2" = "--all" ]; then
        rm -rf "$HOME/.cwbrowser"
    else
        rm -rf "$HOME/.cwbrowser/$AWS_PROFILE_NAME"
    fi
    exit 0
fi

# Parse the input arguments
if [ $# -ge 1 ]; then
    input="$1"
    
    # Check if group name is provided directly
    start_group="$input"
    
    # Handle second argument as stream name if provided
    if [ $# -ge 2 ]; then
        start_stream="$2"
    fi
fi

# Check if AWS CLI is properly configured and connected
aws sts get-caller-identity >/dev/null 2>&1 || { echo "AWS CLI is not properly configured or connected. $(aws sts get-caller-identity 2>&1)" >&2; exit 1; }

# Create cache directory if it doesn't exist
mkdir -p "$CACHE_DIR"
touch "$RECENT_GROUPS_CACHE" 2>/dev/null

# Add option to search for a log stream across recent groups
if [ "$1" = "--search-stream" ] || [ "$1" = "-s" ]; then
    if [ $# -lt 2 ]; then echo "Usage: $0 --search-stream|-s <stream_name>"; exit 1; fi
    search_stream="$2"
    if [ ! -s "$RECENT_GROUPS_CACHE" ]; then echo "No recent groups to search"; exit 1; fi
    while IFS= read -r grp; do
        if aws logs describe-log-streams --log-group-name "$grp" \
           --log-stream-name-prefix "$search_stream" --limit 50 \
           --query 'logStreams[?logStreamName==`'"$search_stream"'`].logStreamName' \
           --output text | grep -q "$search_stream"; then
            start_group="$grp"
            start_stream="$search_stream"
            break
        fi
    done < "$RECENT_GROUPS_CACHE"
    if [ -z "$start_group" ]; then echo "Stream '$search_stream' not found in recent groups"; exit 1; fi
fi

# Function to update recent log groups list
update_recent_groups() {
    local group=$1
    local temp_file=$(mktemp)
    
    # Add current group at the top, remove duplicates, keep only last 20
    echo "$group" > "$temp_file"
    grep -v "^$group$" "$RECENT_GROUPS_CACHE" | head -n 200 >> "$temp_file"
    mv "$temp_file" "$RECENT_GROUPS_CACHE"
}

# Function to list log groups
list_log_groups() {
    # Use cached list if available, update cache in background
    if [ -s "${GROUPS_CACHE}" ]; then
        # Output cached content immediately
        cat "${GROUPS_CACHE}"
        # Update cache in background with nohup to ensure it runs independently
        {
            # Clear previous error log
            rm -f "$CACHE_ERROR_LOG"
            
            # Attempt to update cache, logging any errors
            if ! aws logs describe-log-groups --query 'logGroups[*].[logGroupName,storedBytes]' --output text |
                awk '{printf "%-90s %s bytes\n", $1, $2}' |
                tee "${GROUPS_CACHE}" > /dev/null &&
                awk '{print $1}' "${GROUPS_CACHE}" > "${CACHE_DIR}/group_names.txt"; then
                echo "Error updating cache at $(date)" > "$CACHE_ERROR_LOG"
                echo "AWS command failed. Try running with --clear-cache to reset." >> "$CACHE_ERROR_LOG"
            fi
        } </dev/null >/dev/null 2>>"$CACHE_ERROR_LOG" &
        disown
    else
        # No cache: fetch synchronously
        if ! aws logs describe-log-groups --query 'logGroups[*].[logGroupName,storedBytes]' --output text |
            awk '{printf "%-90s %s bytes\n", $1, $2}' | tee "${GROUPS_CACHE}"; then
            echo "Error: Failed to fetch CloudWatch log groups." >&2
            echo "AWS command failed. Try running with --clear-cache to reset." >&2
            exit 1
        else
            # Build group names list
            awk '{print $1}' "${GROUPS_CACHE}" > "${CACHE_DIR}/group_names.txt"
            # Clear any previous error log on success
            rm -f "$CACHE_ERROR_LOG"
        fi
    fi
}

# Function to format timestamp
format_timestamp() {
    # Convert timestamp to date format using date command instead of awk's strftime
    date -r $(($1/1000)) "+%Y-%m-%d %H:%M:%S" 2>/dev/null || 
    date -d @$(($1/1000)) "+%Y-%m-%d %H:%M:%S" 2>/dev/null ||
    echo "Unknown time"
}

# Function to list log streams in a group
list_log_streams() {
    local group=$1
    
    echo ".."
    # List streams with creation time
    aws logs describe-log-streams --log-group-name "$group" --order-by LastEventTime --descending --query 'logStreams[*].[logStreamName,lastEventTimestamp]' --output text | while read -r stream timestamp; do
        formatted_time=$(format_timestamp "$timestamp")
        printf "%-90s %s\n" "$stream" "$formatted_time"
    done
}

# Extract name only from the formatted listing
extract_name() {
    echo "$1" | awk '{print $1}'
}

# Function to display log events
display_log_events() {
    local group=$1
    local stream=$2
    local output_format=$3
    
    # Check for output format
    case "$output_format" in
        "Raw JSON")
            aws logs get-log-events --log-group-name "$group" --log-stream-name "$stream" --start-from-head | less
            ;;
        "Message only")
            aws logs get-log-events --log-group-name "$group" --log-stream-name "$stream" --start-from-head --query 'events[*].message' --output text | less
            ;;
        "Timestamp + Message")
            aws logs get-log-events --log-group-name "$group" --log-stream-name "$stream" --start-from-head --query 'events[*].[timestamp,message]' --output text | while read -r ts message; do
                formatted_time=$(format_timestamp "$ts")
                echo "$formatted_time: $message"
            done | less
            ;;
        *)
            return
            ;;
    esac
}

# Function to handle stream actions
handle_stream_action() {
    local group=$1
    local stream=$2
    
    # Create action menu with options
    options=(
        "View logs (Message only)"
        "View logs (Timestamp + Message)"
        "View logs (Raw JSON)"
        "Download logs as JSON"
        "Download logs as Text (Message only)"
        "Download logs as CSV"
        "Copy stream name"
        ".."
    )
    
    # Present options using fzf
    action=$(printf "%s\n" "${options[@]}" | fzf --header="Choose action for $stream:")
    [ -z "$action" ] && return
    
    # Handle selected action
    case "$action" in
        "View logs (Message only)")
            display_log_events "$group" "$stream" "Message only"
            ;;
        "View logs (Timestamp + Message)")
            display_log_events "$group" "$stream" "Timestamp + Message"
            ;;
        "View logs (Raw JSON)")
            display_log_events "$group" "$stream" "Raw JSON"
            ;;
        "Download logs as JSON")
            read -e -p "Download path [default: ./${stream}.json]: " download_path
            download_path=${download_path:-"./${stream}.json"}
            aws logs get-log-events --log-group-name "$group" --log-stream-name "$stream" --start-from-head > "$download_path"
            echo "Downloaded to $download_path"
            exit 0
            ;;
        "Download logs as Text (Message only)")
            read -e -p "Download path [default: ./${stream}.txt]: " download_path
            download_path=${download_path:-"./${stream}.txt"}
            aws logs get-log-events --log-group-name "$group" --log-stream-name "$stream" --start-from-head --query 'events[*].message' --output text > "$download_path"
            echo "Downloaded to $download_path"
            exit 0
            ;;
        "Download logs as CSV")
            read -e -p "Download path [default: ./${stream}.csv]: " download_path
            download_path=${download_path:-"./${stream}.csv"}
            echo "timestamp,message" > "$download_path"
            aws logs get-log-events --log-group-name "$group" --log-stream-name "$stream" --start-from-head --query 'events[*].[timestamp,message]' --output text | while read -r ts message; do
                formatted_time=$(format_timestamp "$ts")
                echo "\"$formatted_time\",\"${message//,/\\,}\"" >> "$download_path"
            done
            echo "Downloaded to $download_path"
            exit 0
            ;;
        "Copy stream name")
            echo "$stream" | pbcopy
            echo "Stream name copied to clipboard: $stream"
            exit 0
            ;;
        "..")
            return
            ;;
    esac
}

# Main loop
while true; do
    if [ -z "$start_group" ]; then
        # Get all log groups
        all_groups=$(list_log_groups)
        
        # Combine recent groups with all groups
        recent_with_details=""
        if [ -s "$RECENT_GROUPS_CACHE" ]; then
            while IFS= read -r recent_group; do
                group_line=$(echo "$all_groups" | grep "^$recent_group " || echo "")
                if [ -n "$group_line" ]; then
                    recent_with_details+="$group_line [RECENT]\n"
                fi
            done < "$RECENT_GROUPS_CACHE"
        fi
        
        # Display recent groups first, then all groups
        group_line=$(printf "%b\n%s" "$recent_with_details" "$all_groups" | fzf --header="Select a log group (Ctrl+C to exit):")
        [ -z "$group_line" ] && break

        group=$(extract_name "$group_line")
    else
        group="$start_group"
        unset start_group
    fi
    
    # Update recent groups list
    update_recent_groups "$group"
    
    while true; do
        if [ -z "$start_stream" ]; then
            # List streams in current group
            stream_line=$(list_log_streams "$group" | fzf --header="Log Group: $group (Ctrl+C to go to group selection)")
            [ -z "$stream_line" ] && break
            # Extract stream name
            stream=$(extract_name "$stream_line")
        else
            stream="$start_stream"
            unset start_stream
        fi
        
        # Handle .. navigation
        if [ "$stream" = ".." ]; then
            break
        fi
        
        # Handle stream selection
        handle_stream_action "$group" "$stream"
    done
done 