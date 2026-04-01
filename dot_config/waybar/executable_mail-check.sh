#!/bin/bash
source ~/.secrets

check_imap() {
  local user="$1" pass="$2"
  curl -s --url "imaps://imap.gmail.com/INBOX" \
    --user "${user}:${pass}" \
    --request "SEARCH UNSEEN" 2>/dev/null \
    | grep -oP '\d+' | wc -w
}

work=$(check_imap "antti@begin.ee" "$WORK_GMAIL_APP_PASSWORD")
personal=$(check_imap "antti.linno@gmail.com" "$GMAIL_APP_PASSWORD")

total=$((work + personal))

printf '{"text": "%d", "tooltip": "Work: %d  Personal: %d", "class": "%s"}\n' \
  "$total" "$work" "$personal" \
  "$([ "$total" -gt 0 ] && echo has-mail || echo no-mail)"
