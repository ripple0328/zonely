#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="zonely"
BASE_PORT=4010
MAX_PORT=4999
TUNNEL_NAME="zonely-prod-$(date +%s)"

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to find an available port
find_available_port() {
    local port=$BASE_PORT
    while [ $port -le $MAX_PORT ]; do
        if ! lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
            echo $port
            return 0
        fi
        ((port++))
    done
    print_error "No available ports found in range $BASE_PORT-$MAX_PORT"
    exit 1
}

# Function to check if cloudflared is installed
check_cloudflared() {
    if ! command -v cloudflared &> /dev/null; then
        print_error "cloudflared is not installed. Please install it first:"
        print_info "brew install cloudflared"
        print_info "Or download from: https://github.com/cloudflare/cloudflared/releases"
        exit 1
    fi
}

# Function to update dependencies
update_dependencies() {
    print_info "Updating dependencies for production..."

    # Update all dependencies to resolve version conflicts
    mix deps.update --all

    # Install production dependencies
    MIX_ENV=prod mix deps.get --only prod

    print_success "Dependencies updated successfully"
}

# Function to wait for production database to be ready
wait_for_database() {
    print_info "Waiting for production database to be ready..."
    local retries=30
    while [ $retries -gt 0 ]; do
        if docker exec zonely_db_prod pg_isready -U postgres >/dev/null 2>&1; then
            print_success "Production database is ready"
            return 0
        fi
        print_info "Waiting for database... ($retries attempts left)"
        sleep 2
        ((retries--))
    done

    print_error "Production database is not responding"
    print_error "Make sure 'mix db.prod.up' was run successfully"
    return 1
}

# Function to generate required environment variables
generate_env_vars() {
    local port=$1

    # Generate secret key base if not provided
    if [ -z "$SECRET_KEY_BASE" ]; then
        print_info "Generating SECRET_KEY_BASE..."
        SECRET_KEY_BASE=$(mix phx.gen.secret)
    fi

    # Set default database URL if not provided (production database on port 5433)
    if [ -z "$DATABASE_URL" ]; then
        DATABASE_URL="postgresql://postgres:postgres@localhost:5433/zonely_prod"
        print_warning "Using default production DATABASE_URL: $DATABASE_URL"
    fi

    # Set PHX_HOST for tunnel
    PHX_HOST="localhost"

    # Export environment variables for production
    export MIX_ENV=prod
    export PHX_SERVER=true
    export SECRET_KEY_BASE="$SECRET_KEY_BASE"
    export DATABASE_URL="$DATABASE_URL"
    export PHX_HOST="$PHX_HOST"
    export PORT="$port"

    # Explicitly set individual database components to ensure they override dev config
    export DB_HOST="localhost"
    export DB_PORT="5433"
    export DB_NAME="zonely_prod"
    export DB_USER="postgres"
    export DB_PASSWORD="postgres"

    print_success "Environment variables configured for production on port $port"
    print_info "Database URL: $DATABASE_URL"

    # Debug: Show all relevant environment variables
    print_info "DEBUG - Environment variables:"
    echo "  MIX_ENV=$MIX_ENV"
    echo "  DATABASE_URL=$DATABASE_URL"
    echo "  PHX_HOST=$PHX_HOST"
    echo "  PORT=$PORT"
}

# Function to setup database
setup_database() {
    print_info "Setting up production database..."

    # Check if database exists, create if it doesn't
    if ! MIX_ENV=prod mix ecto.create --quiet 2>/dev/null; then
        print_warning "Database already exists or creation failed"
    fi

    # Run migrations in production
    MIX_ENV=prod mix ecto.migrate

    print_success "Production database setup complete"
}

# Function to build production release
build_production() {
    print_info "Building application for production..."

    # Compile the application in production mode
    MIX_ENV=prod mix compile

    # Build and deploy assets for production
    MIX_ENV=prod mix assets.deploy

    print_success "Production build completed successfully"
}

# Function to start the Phoenix app in production mode
start_phoenix_app() {
    local port=$1
    print_info "Starting Phoenix app in production mode on port $port..."

    # Start the Phoenix server in production mode in the background
    MIX_ENV=prod mix phx.server &
    PHOENIX_PID=$!

    # Wait a bit for the server to start
    sleep 8

    # Check if the server is running
    if kill -0 $PHOENIX_PID 2>/dev/null; then
        # Test if the server is responding
        local retries=5
        while [ $retries -gt 0 ]; do
            if curl -s "http://localhost:$port" >/dev/null 2>&1; then
                print_success "Phoenix app started successfully in production mode on port $port (PID: $PHOENIX_PID)"
                return 0
            fi
            print_info "Waiting for Phoenix app to be ready... ($retries attempts left)"
            sleep 3
            ((retries--))
        done
        print_error "Phoenix app started but not responding on port $port"
        return 1
    else
        print_error "Failed to start Phoenix app in production mode"
        return 1
    fi
}

# Function to start Cloudflare tunnel
start_cloudflare_tunnel() {
    local port=$1
    print_info "Starting Cloudflare tunnel for port $port..."

    # Start the tunnel in the background
    cloudflared tunnel --url "http://localhost:$port" --name "$TUNNEL_NAME" > tunnel.log 2>&1 &
    TUNNEL_PID=$!

    # Wait a bit for the tunnel to establish
    sleep 10

    # Check if tunnel is running
    if kill -0 $TUNNEL_PID 2>/dev/null; then
        print_success "Cloudflare tunnel started successfully (PID: $TUNNEL_PID)"

        # Try to extract the tunnel URL from cloudflared logs
        if [ -f "tunnel.log" ]; then
            TUNNEL_URL=$(grep -o 'https://.*\.trycloudflare\.com' tunnel.log | head -1)
            if [ ! -z "$TUNNEL_URL" ]; then
                print_success "Tunnel URL: $TUNNEL_URL"
            else
                print_info "Check tunnel.log for the exact tunnel URL"
            fi
        fi
        return 0
    else
        print_error "Failed to start Cloudflare tunnel"
        if [ -f "tunnel.log" ]; then
            print_error "Tunnel log:"
            tail -10 tunnel.log
        fi
        return 1
    fi
}

# Function to cleanup on exit
cleanup() {
    print_info "Cleaning up..."

    if [ ! -z "$PHOENIX_PID" ] && kill -0 $PHOENIX_PID 2>/dev/null; then
        print_info "Stopping Phoenix app (PID: $PHOENIX_PID)..."
        kill $PHOENIX_PID
        wait $PHOENIX_PID 2>/dev/null || true
    fi

    if [ ! -z "$TUNNEL_PID" ] && kill -0 $TUNNEL_PID 2>/dev/null; then
        print_info "Stopping Cloudflare tunnel (PID: $TUNNEL_PID)..."
        kill $TUNNEL_PID
        wait $TUNNEL_PID 2>/dev/null || true
    fi

    # Clean up log file
    [ -f "tunnel.log" ] && rm -f tunnel.log

    print_success "Cleanup complete"
}

# Function to display running services info
display_info() {
    local port=$1
    echo ""
    print_success "=== ZONELY PRODUCTION ENVIRONMENT ==="
    echo -e "${GREEN}Local URL:${NC} http://localhost:$port"
    echo -e "${GREEN}Environment:${NC} production (MIX_ENV=prod)"
    echo -e "${GREEN}Database:${NC} PostgreSQL on port 5433 (zonely_prod)"
    echo -e "${GREEN}Phoenix PID:${NC} $PHOENIX_PID"
    echo -e "${GREEN}Tunnel PID:${NC} $TUNNEL_PID"
    echo -e "${GREEN}Tunnel Name:${NC} $TUNNEL_NAME"

    # Show tunnel URL if available
    if [ -f "tunnel.log" ]; then
        TUNNEL_URL=$(grep -o 'https://.*\.trycloudflare\.com' tunnel.log | head -1)
        if [ ! -z "$TUNNEL_URL" ]; then
            echo -e "${GREEN}Public URL:${NC} $TUNNEL_URL"
        fi
    fi

    echo ""
    print_info "The app is now running in PRODUCTION mode and accessible via Cloudflare tunnel"
    print_info "Database: PostgreSQL on localhost:5433"
    print_info "Press Ctrl+C to stop all services"
    echo ""
}

# Main execution
main() {
    print_info "Starting Zonely in PRODUCTION mode with Cloudflare tunnel..."
    print_info "Note: Production database will be started by 'mix db.prod.up'"

    # Set up signal handlers for cleanup
    trap cleanup EXIT INT TERM

    # Check prerequisites
    check_cloudflared

    # Update dependencies FIRST (before any Mix commands that need them)
    update_dependencies

    # Find available port
    print_info "Finding available port..."
    AVAILABLE_PORT=$(find_available_port)
    print_success "Using port: $AVAILABLE_PORT"

    # Generate environment variables
    generate_env_vars $AVAILABLE_PORT

    # Wait for production database to be ready (started by mix db.prod.up)
    if ! wait_for_database; then
        print_error "Production database is not ready. Make sure 'mix db.prod.up' ran successfully."
        exit 1
    fi

    # Setup database
    setup_database

    # Build production release
    build_production

    # Start Phoenix app in production mode
    if ! start_phoenix_app $AVAILABLE_PORT; then
        print_error "Failed to start Phoenix app in production mode"
        exit 1
    fi

    # Start Cloudflare tunnel
    if ! start_cloudflare_tunnel $AVAILABLE_PORT; then
        print_error "Failed to start Cloudflare tunnel"
        exit 1
    fi

    # Display information
    display_info $AVAILABLE_PORT

    # Wait for user to interrupt
    wait
}

# Check if running as source or executed
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi
