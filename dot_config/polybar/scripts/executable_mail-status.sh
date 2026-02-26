#!/bin/bash

source ~/.secrets 2>/dev/null

check_mail() {
    curl -sf --max-time 10 --url "imaps://imap.gmail.com:993/INBOX" \
        --user "$1:$2" \
        --request "STATUS INBOX (UNSEEN)" 2>/dev/null \
        | grep -oP 'UNSEEN \K[0-9]+'
}

TMP=$(mktemp -d)
check_mail "$GMAIL_USER" "$GMAIL_APP_PASSWORD" > "$TMP/personal" &
check_mail "$WORK_GMAIL_USER" "$WORK_GMAIL_APP_PASSWORD" > "$TMP/work" &
wait

PERSONAL=$(cat "$TMP/personal" 2>/dev/null)
WORK=$(cat "$TMP/work" 2>/dev/null)
rm -rf "$TMP"

PERSONAL=${PERSONAL:-0}
WORK=${WORK:-0}

if [ "$PERSONAL" -eq 0 ] && [ "$WORK" -eq 0 ]; then
    echo ""
else
    echo "󰊫 $PERSONAL/$WORK"
fi
