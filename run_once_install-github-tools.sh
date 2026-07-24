#!/bin/bash
# Install goto and todo-calendar from GitHub releases

mkdir -p "$HOME/.local/bin"

echo "Installing goto..."
curl -sL --fail "https://github.com/anttilinno/goto/releases/latest/download/goto-linux-amd64" -o "$HOME/.local/bin/goto-bin" || { echo "goto download failed" >&2; exit 1; }
chmod +x "$HOME/.local/bin/goto-bin"

echo "Installing todo-calendar..."
curl -sL --fail "https://github.com/anttilinno/todo-calendar/releases/latest/download/todo-calendar-linux-amd64" -o "$HOME/.local/bin/todo-calendar" || { echo "todo-calendar download failed" >&2; exit 1; }
chmod +x "$HOME/.local/bin/todo-calendar"

echo "Done."
