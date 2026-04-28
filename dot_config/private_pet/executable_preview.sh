#!/bin/bash
# Pretty-print a pet snippet entry for the television preview pane.
# Expected pet Format: "[$description] $tags: $command"

entry="$*"

desc="${entry#\[}"
desc="${desc%%\] *}"
rest="${entry#*\] }"

if [[ "$rest" == *": "* ]]; then
    tags="${rest%%: *}"
    cmd="${rest#*: }"
else
    tags=""
    cmd="$rest"
fi

printf '\033[1;33mDescription\033[0m  %s\n' "$desc"
[[ -n "$tags" ]] && printf '\033[1;36mTags\033[0m         %s\n' "$tags"
printf '\n\033[1;32mCommand\033[0m\n%s\n' "$cmd"
