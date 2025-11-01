#!/bin/bash
#
# Scheduler script for running the Mastodon bot at regular intervals
#

# Get schedule interval from environment variable (default to 4 hours)
SCHEDULE_INTERVAL=${SCHEDULE_INTERVAL:-4h}

echo "Mastodon Bot Scheduler starting..."
echo "Schedule interval: $SCHEDULE_INTERVAL"
echo ""

# Function to run the bot
run_bot() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running bot..."
    python bot.py
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Bot completed successfully"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Bot exited with code $exit_code"
    fi
    echo ""
}

# Run immediately on startup
run_bot

# Convert interval to seconds for sleep
convert_to_seconds() {
    local interval=$1
    local value=${interval%?}
    local unit=${interval: -1}
    
    case $unit in
        s) echo $value ;;
        m) echo $((value * 60)) ;;
        h) echo $((value * 3600)) ;;
        d) echo $((value * 86400)) ;;
        *) echo 14400 ;; # Default to 4 hours if format is invalid
    esac
}

SLEEP_SECONDS=$(convert_to_seconds "$SCHEDULE_INTERVAL")

# Main loop
while true; do
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Sleeping for $SCHEDULE_INTERVAL ($SLEEP_SECONDS seconds)..."
    sleep $SLEEP_SECONDS
    run_bot
done
