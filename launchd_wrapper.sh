#!/bin/zsh

# Debug logging
echo "Starting launchd_wrapper.sh at $(date)" >> /Users/qingbo/Projects/Personal/zonely/logs/wrapper.log
echo "Initial PATH: $PATH" >> /Users/qingbo/Projects/Personal/zonely/logs/wrapper.log

# Source zsh configuration to get your full environment
source ~/.zshrc

echo "After sourcing .zshrc PATH: $PATH" >> /Users/qingbo/Projects/Personal/zonely/logs/wrapper.log

# Change to project directory
cd /Users/qingbo/Projects/Personal/zonely
echo "Changed to directory: $(pwd)" >> /Users/qingbo/Projects/Personal/zonely/logs/wrapper.log

# Load production environment variables from .env.prod
if [ -f .env.prod ]; then
    echo "Loading production environment from .env.prod..." >> /Users/qingbo/Projects/Personal/zonely/logs/wrapper.log
    source .env.prod
    echo "Loaded .env.prod successfully" >> /Users/qingbo/Projects/Personal/zonely/logs/wrapper.log
else
    echo "WARNING: .env.prod not found! API keys and secrets may not be available." >> /Users/qingbo/Projects/Personal/zonely/logs/wrapper.log
fi

# Run the mix command with error logging
# Note: Additional environment variables are set in start_prod_tunnel.sh
mix prod.tunnel 2>> /Users/qingbo/Projects/Personal/zonely/logs/wrapper.log
