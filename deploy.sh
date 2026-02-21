#!/bin/bash
set -e

# Zonely Deployment Script
# Usage: ./deploy.sh [--skip-merge]
#
# This script deploys the current branch changes to the production server.
# Steps: push → merge to main → pull on server → compile → restart service
#
# Prerequisites:
#   - SSH access to 'mini' host configured in ~/.ssh/config
#   - Current branch has changes committed
#   - Server LaunchAgent 'com.zonely.prod' is configured

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

REMOTE_HOST="mini"
REMOTE_DIR="~/Projects/Personal/zonely"
MAIN_REPO="/Users/qingbo/Projects/Personal/zonely"
MISE_PATH="\$HOME/.local/share/mise/shims:/opt/homebrew/bin:\$PATH"

info()  { echo -e "${GREEN}[DEPLOY]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

SKIP_MERGE=false
if [ "$1" == "--skip-merge" ]; then
    SKIP_MERGE=true
fi

# Step 1: Get current branch
BRANCH=$(git rev-parse --abbrev-ref HEAD)
info "Current branch: $BRANCH"

# Step 2: Push current branch
info "Pushing $BRANCH to origin..."
git push origin "$BRANCH" || error "Failed to push $BRANCH"

# Step 3: Merge to main (unless --skip-merge or already on main)
if [ "$SKIP_MERGE" = false ] && [ "$BRANCH" != "main" ]; then
    info "Merging $BRANCH into main..."
    cd "$MAIN_REPO" 2>/dev/null || error "Main repo not found at $MAIN_REPO"
    git fetch origin
    git merge "origin/$BRANCH" -m "Merge $BRANCH: deploy $(date +%Y%m%d-%H%M%S)" || error "Merge conflict! Resolve manually."
    git push origin main || error "Failed to push main"
    cd - > /dev/null
    info "Merged to main successfully"
elif [ "$BRANCH" = "main" ]; then
    info "Already on main, skipping merge"
fi

# Step 4: Pull on server
info "Pulling latest code on server..."
ssh "$REMOTE_HOST" "cd $REMOTE_DIR && git pull origin main" || error "Failed to pull on server"

# Step 5: Compile on server
info "Compiling on server (MIX_ENV=prod)..."
ssh "$REMOTE_HOST" "export PATH=\"$MISE_PATH\" && cd $REMOTE_DIR && MIX_ENV=prod mix compile" || error "Compilation failed on server"

# Step 6: Restart the service
info "Restarting Zonely service..."
USERID=$(ssh "$REMOTE_HOST" "id -u")
ssh "$REMOTE_HOST" "launchctl kickstart -k gui/$USERID/com.zonely.prod" || {
    warn "launchctl kickstart failed, trying bootout/bootstrap..."
    ssh "$REMOTE_HOST" "launchctl bootout gui/$USERID/com.zonely.prod 2>/dev/null; sleep 2; launchctl bootstrap gui/$USERID ~/Library/LaunchAgents/com.zonely.prod.plist"
}

# Step 7: Wait and verify
info "Waiting for server to start (30s)..."
sleep 30

# Verify server is responding
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://saymyname.qingbo.us/" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
    info "✅ Deployment successful! Server responding with HTTP $HTTP_CODE"
else
    warn "⚠️  Server returned HTTP $HTTP_CODE — may still be starting up"
    warn "Check logs: ssh mini 'tail -50 ~/Projects/Personal/zonely/logs/prod.log'"
    warn "Check wrapper: ssh mini 'tail -20 ~/Projects/Personal/zonely/logs/wrapper.log'"
fi

info "Done!"

