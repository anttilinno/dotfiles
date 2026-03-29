#!/bin/bash
# Install goto and todo-calendar from GitHub releases

mkdir -p "$HOME/.local/bin"

echo "Installing goto..."
curl -sL "https://github.com/anttilinno/goto/releases/download/latest/goto-linux-amd64" -o "$HOME/.local/bin/goto"
chmod +x "$HOME/.local/bin/goto"

echo "Installing todo-calendar..."
curl -sL "https://github.com/anttilinno/todo-calendar/releases/latest/download/todo-calendar-linux-amd64" -o "$HOME/.local/bin/todo-calendar"
chmod +x "$HOME/.local/bin/todo-calendar"

echo "Done."
