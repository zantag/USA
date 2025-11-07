#!/bin/bash

# === SSH login alert for Unraid ===
# Monitors /var/log/syslog for any SSH activity and sends notification to ntfy.sh
# Customize NTFY_TOPIC with your own topic/channel name

NTFY_TOPIC="тест"   # 🔹 смени това с твоя ntfy.sh topic
NTFY_SERVER="https://ntfy.sh"  # 🔹 може да смениш с собствен сървър
NTFY_TOKEN="твоят токен"   # 🔹 добави твоя ntfy token (задължително)

HOSTNAME=$(hostname)
LOGFILE="/var/log/syslog"
TMPFILE="/tmp/ssh-alert.last"

# Проверка за зададен token
if [ -z "$NTFY_TOKEN" ] || [ "$NTFY_TOKEN" = "твоят_token_тук" ]; then
    echo "ГРЕШКА: NTFY_TOKEN не е зададен!"
    echo "Моля, задай валиден token в променливата NTFY_TOKEN"
    exit 1
fi

# --- Функция за получаване на държава и код по IP ---
get_country_info() {
    local ip=$1
    if [ "$ip" = "unknown" ] || [ -z "$ip" ]; then
        echo "Unknown|"
        return
    fi
    country_data=$(curl -s --max-time 3 "https://ipapi.co/$ip/json/" 2>/dev/null)
    country_name=$(echo "$country_data" | grep -o '"country_name": "[^"]*' | cut -d'"' -f4)
    country_code=$(echo "$country_data" | grep -o '"country_code": "[^"]*' | cut -d'"' -f4)
    if [ -n "$country_name" ] && [ "$country_name" != "null" ]; then
        echo "$country_name|$country_code"
    else
        echo "Unknown|"
    fi
}

# --- Функция за преобразуване на код на държава в emoji знаменце ---
country_code_to_flag() {
    local country_code=$1
    if [ -z "$country_code" ] || [ "${#country_code}" -ne 2 ]; then
        echo ""
        return
    fi
    first_char=$(echo "${country_code:0:1}" | tr '[:lower:]' '[:upper:]')
    second_char=$(echo "${country_code:1:1}" | tr '[:lower:]' '[:upper:]')
    base_code=127462
    first_flag=$((base_code + $(printf "%d" "'$first_char") - 65))
    second_flag=$((base_code + $(printf "%d" "'$second_char") - 65))
    printf "\\U$(printf '%08X' $first_flag)\\U$(printf '%08X' $second_flag)"
}

touch "$TMPFILE"

tail -Fn0 "$LOGFILE" | \
grep --line-buffered -E "sshd.*(Accepted|Failed|Invalid user|Invalid password|Disconnected from|Connection closed)" | \
while read LINE; do

    # --- Извличане на IP ---
    IP="unknown"
    if echo "$LINE" | grep -qE "from ([0-9]{1,3}\.){3}[0-9]{1,3}"; then
        IP=$(echo "$LINE" | grep -oE "from ([0-9]{1,3}\.){3}[0-9]{1,3}" | awk '{print $2}' | head -n1)
    elif echo "$LINE" | grep -qE "([0-9]{1,3}\.){3}[0-9]{1,3}"; then
        IP=$(echo "$LINE" | grep -oE "([0-9]{1,3}\.){3}[0-9]{1,3}" | head -n1)
    fi

    # --- Извличане на потребител ---
    USER="unknown"

    if echo "$LINE" | grep -qE "Invalid user"; then
        USER=$(echo "$LINE" | sed -E 's/.*Invalid user ([^ ]+).*/\1/')
    elif echo "$LINE" | grep -qE "Failed (password|keyboard-interactive/pam) for invalid user"; then
        USER=$(echo "$LINE" | sed -E 's/.*Failed (password|keyboard-interactive\/pam) for invalid user ([^ ]+) .*/\2/')
    elif echo "$LINE" | grep -qE "Failed (password|keyboard-interactive/pam) for"; then
        USER=$(echo "$LINE" | sed -E 's/.*Failed (password|keyboard-interactive\/pam) for ([^ ]+) .*/\2/')
    elif echo "$LINE" | grep -Eq "Accepted (password|keyboard-interactive/pam) for"; then
        USER=$(echo "$LINE" | sed -E 's/.*Accepted (password|keyboard-interactive\/pam) for ([^ ]+) .*/\2/')
    elif echo "$LINE" | grep -qE "Disconnected from user"; then
        USER=$(echo "$LINE" | sed -E 's/.*Disconnected from user ([^ ]+) .*/\1/')
    fi



    # --- Държава / Флаг ---
    COUNTRY_INFO=""
    FLAG_EMOJI=""
    if [ "$IP" != "unknown" ] && [[ ! "$IP" =~ ^(127\.|10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.) ]]; then
        country_data=$(get_country_info "$IP")
        COUNTRY_NAME=$(echo "$country_data" | cut -d'|' -f1)
        COUNTRY_CODE=$(echo "$country_data" | cut -d'|' -f2)
        if [ "$COUNTRY_NAME" != "Unknown" ] && [ -n "$COUNTRY_CODE" ]; then
            FLAG_EMOJI=$(country_code_to_flag "$COUNTRY_CODE")
            COUNTRY_INFO=" - $COUNTRY_NAME $FLAG_EMOJI"
        elif [ "$COUNTRY_NAME" != "Unknown" ]; then
            COUNTRY_INFO=" - $COUNTRY_NAME"
        fi
    fi

    # --- Определяне на типа събитие ---
    if echo "$LINE" | grep -q "Accepted"; then
        EVENT="✅ SSH Login"
        MESSAGE="Successful login for user: $USER from $IP$COUNTRY_INFO"
        PRIORITY=3
    elif echo "$LINE" | grep -q "Failed\|Invalid password"; then
        EVENT="❌ Failed SSH Login"
        REASON="Invalid password"
        MESSAGE="$REASON for user: $USER from $IP$COUNTRY_INFO"
        PRIORITY=4
    elif echo "$LINE" | grep -q "Invalid user"; then
        EVENT="❌ Failed SSH Login"
        REASON="Invalid user"
        MESSAGE="$REASON: $USER from $IP$COUNTRY_INFO"
        PRIORITY=4
    elif echo "$LINE" | grep -q "Disconnected from\|Connection closed"; then
        EVENT="🚪 SSH Logout"
        MESSAGE="User: $USER disconnected from $IP$COUNTRY_INFO"
        PRIORITY=2
    else
        continue
    fi

    # --- Избягване на дублиране на известия ---
    TIMESTAMP=$(date +%Y%m%d%H%M)
    EVENT_ID="${EVENT}_${USER}_${IP}_${TIMESTAMP}"

    if grep -q "$EVENT_ID" "$TMPFILE" && [[ $(find "$TMPFILE" -mmin -0.5) ]]; then
        continue
    fi

    echo "$EVENT_ID" >> "$TMPFILE"
    tail -n 100 "$TMPFILE" > "$TMPFILE.tmp" && mv "$TMPFILE.tmp" "$TMPFILE"

    # --- Изпращане на известие ---
    curl -s \
         -H "Authorization: Bearer $NTFY_TOKEN" \
         -H "Title: $HOSTNAME: $EVENT" \
         -H "Priority: $PRIORITY" \
         -d "$MESSAGE" \
         "$NTFY_SERVER/$NTFY_TOPIC" >/dev/null 2>&1

    echo "Notification sent: $EVENT - $MESSAGE"

done