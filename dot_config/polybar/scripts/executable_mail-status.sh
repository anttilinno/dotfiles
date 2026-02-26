#!/bin/bash

source ~/.secrets 2>/dev/null

check_mail() {
    curl -sf --url "imaps://imap.gmail.com:993/INBOX" \
        --user "$1:$2" \
        --request "STATUS INBOX (UNSEEN)" 2>/dev/null \
        | grep -oP 'UNSEEN \K[0-9]+'
}

PERSONAL=$(check_mail "$GMAIL_USER" "$GMAIL_APP_PASSWORD")
WORK=$(check_mail "$WORK_GMAIL_USER" "$WORK_GMAIL_APP_PASSWORD")

PERSONAL=${PERSONAL:-0}
WORK=${WORK:-0}

if [ "$PERSONAL" -eq 0 ] && [ "$WORK" -eq 0 ]; then
    echo ""
else
    echo "󰊫 $PERSONAL/$WORK"
fi
