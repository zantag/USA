#!/bin/bash

# === SSH login alert for Unraid ===
# Monitors /var/log/syslog for any SSH activity and sends notification to ntfy.sh
# Customize NTFY_TOPIC with your own topic/channel name

NTFY_TOPIC="put-your-ntfy-topic"   # 🔹 change with your ntfy.sh topic
HOSTNAME=$(hostname)

LOGFILE="/var/log/syslog"
TMPFILE="/tmp/ssh-alert.last"

touch "$TMPFILE"

tail -Fn0 "$LOGFILE" | \
grep --line-buffered -E "sshd.*(Accepted|Failed|Invalid user|Disconnected from)" | \
while read LINE; do
    # Extract IP address if present
    IP=$(echo "$LINE" | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}" | head -n1)
    [ -z "$IP" ] && IP="unknown"

    # Extract username if present
    USER=$(echo "$LINE" | grep -oE "(for|user) [^ ]+" | awk '{print $2}')
    [ -z "$USER" ] && USER="unknown"

    # Determine event type and set appropriate message
    if echo "$LINE" | grep -q "Accepted"; then
        EVENT_TYPE="Login"
        EVENT="✅ SSH Login"
        MESSAGE="User: $USER from $IP"
        PRIORITY=3
    elif echo "$LINE" | grep -q "Failed\|Invalid user"; then
        EVENT_TYPE="Failed"
        EVENT="❌ Failed SSH Login"
        MESSAGE="User: $USER from $IP"
        PRIORITY=4
    elif echo "$LINE" | grep -q "Disconnected from"; then
        EVENT_TYPE="Logout"
        EVENT="🚪 SSH Logout" 
        MESSAGE="User: $USER from $IP"
        PRIORITY=2
    else
        continue
    fi

    # Create unique identifier for this event
    EVENT_ID="${EVENT_TYPE}:${USER}:${IP}"

    # Set duplicate check time: 5 seconds for failed attempts, 30 for others
    if [ "$EVENT_TYPE" = "Failed" ]; then
        DUP_TIME=5
    else
        DUP_TIME=30
    fi

    current_time=$(date +%s)

    # Remove events older than DUP_TIME seconds
    awk -v now="$current_time" -v dup_time="$DUP_TIME" -F: '$1 > now-dup_time' "$TMPFILE" > "$TMPFILE.tmp" 2>/dev/null && mv "$TMPFILE.tmp" "$TMPFILE"

    # Check for duplicate event in the last DUP_TIME seconds
    if grep -q ":$EVENT_ID$" "$TMPFILE"; then
        continue
    fi

    # Add current event to TMPFILE
    echo "$current_time:$EVENT_ID" >> "$TMPFILE"

    # Send notification to ntfy.sh
    curl -s -d "$MESSAGE" \
         -H "Title: $HOSTNAME: $EVENT" \
         -H "Priority: $PRIORITY" \
         "https://ntfy.sh/$NTFY_TOPIC" >/dev/null 2>&1
done