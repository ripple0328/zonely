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

# Load direnv environment
echo "Loading direnv..." >> /Users/qingbo/Projects/Personal/zonely/logs/wrapper.log
eval "$(direnv export zsh)" 2>> /Users/qingbo/Projects/Personal/zonely/logs/wrapper.log

echo "About to run mix command..." >> /Users/qingbo/Projects/Personal/zonely/logs/wrapper.log

# Run the mix command with error logging
mix prod.tunnel 2>> /Users/qingbo/Projects/Personal/zonely/logs/wrapper.log
