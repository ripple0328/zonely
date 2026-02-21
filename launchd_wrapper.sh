#!/bin/zsh

LOG="/Users/qingbo/Projects/Personal/zonely/logs/wrapper.log"

echo "Starting launchd_wrapper.sh at $(date)" >> "$LOG"

# Source zsh config first
source ~/.zshrc 2>/dev/null

# CRITICAL: Ensure mise shims are in PATH
# launchd and .zshrc don't reliably include mise, so we add it explicitly.
# The shims directory is version-agnostic and handles tool resolution.
export PATH="$HOME/.local/share/mise/shims:/opt/homebrew/bin:$PATH"

echo "Final PATH: $PATH" >> "$LOG"
echo "mix location: $(which mix 2>/dev/null || echo 'NOT FOUND')" >> "$LOG"

# Change to project directory
cd /Users/qingbo/Projects/Personal/zonely
echo "Working directory: $(pwd)" >> "$LOG"

# Load production environment variables
if [ -f .env.prod ]; then
    source .env.prod
    echo "Loaded .env.prod" >> "$LOG"
else
    echo "WARNING: .env.prod not found!" >> "$LOG"
fi

# Run the production server
echo "Starting mix prod.tunnel..." >> "$LOG"
mix prod.tunnel 2>> "$LOG"
