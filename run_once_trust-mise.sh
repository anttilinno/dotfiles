#!/bin/bash
# Trust .mise.toml so it doesn't show errors on every cd

if command -v mise &>/dev/null; then
  mise trust ~/.mise.toml
fi
