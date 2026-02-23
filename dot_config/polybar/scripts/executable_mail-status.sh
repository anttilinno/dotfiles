#!/bin/bash

source ~/.secrets 2>/dev/null

COUNT=$(curl -sf --url "imaps://imap.gmail.com:993/INBOX" \
    --user "$GMAIL_USER:$GMAIL_APP_PASSWORD" \
    --request "STATUS INBOX (UNSEEN)" 2>/dev/null \
    | grep -oP 'UNSEEN \K[0-9]+')

if [ -z "$COUNT" ] || [ "$COUNT" -eq 0 ]; then
    echo ""
else
    echo "󰊫 $COUNT"
fi
