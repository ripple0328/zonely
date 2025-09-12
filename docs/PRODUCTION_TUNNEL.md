# Production Tunnel Setup

This script (`start_prod_tunnel.sh`) automatically starts the Phoenix application in production mode with a unique port and creates a Cloudflare tunnel to serve it publicly.

## Prerequisites

1. **Cloudflared**: Install the Cloudflare tunnel client
   ```bash
   brew install cloudflared
   # or download from: https://github.com/cloudflare/cloudflared/releases
   ```

2. **Database**: Ensure PostgreSQL is running locally
   ```bash
   mix db.up  # if using Docker Compose
   ```

## Usage

### Quick Tunnel (Anonymous)
```bash
mix prod.tunnel
```

This creates a temporary `https://xxx.trycloudflare.com` URL that works immediately without authentication.

### Named Tunnel (Multi-Subdomain Support)
For multiple subdomains on your own domain:

```bash
mix prod.tunnel
```

Uses the `CLOUDFLARE_TUNNEL_NAME=zonely` from your `.envrc` file for multi-subdomain support.

**Setup Required**: See [Multi-Subdomain Setup Guide](CLOUDFLARE_MULTI_SUBDOMAIN.md) for complete configuration.

## What the Script Does

1. **Production Database**: Starts separate PostgreSQL container on port 5433 (via `mix db.prod.up`)
2. **Finds Available Port**: Automatically finds an unused port (4010-4999 range) for Phoenix
3. **Environment Setup**: Configures production environment variables with correct database URL
4. **Database Setup**: Creates and migrates production database (`zonely_prod`)
5. **Production Build**: Compiles app and builds assets for production
6. **Phoenix Start**: Launches Phoenix in production mode (`MIX_ENV=prod`)
7. **Cloudflare Tunnel**: Creates a public tunnel via Cloudflare

## Environment Variables

The script will use these environment variables if set, otherwise use defaults:

- `SECRET_KEY_BASE`: Generated automatically if not set
- `DATABASE_URL`: Defaults to `postgresql://postgres:postgres@localhost:5433/zonely_prod`
- `PHX_HOST`: Set to `localhost` for tunnel compatibility
- `PORT`: Automatically assigned available port
- `CLOUDFLARE_TUNNEL_NAME`: Use named tunnel instead of quick tunnel

## Custom Configuration

You can override defaults by setting environment variables before running:

```bash
# Add to .envrc file for custom configuration

# Custom database
export DATABASE_URL="postgresql://user:pass@localhost:5433/my_prod_db"

# Custom secret (optional, auto-generated if not set)
export SECRET_KEY_BASE="your-secret-key-here"

# Then run
direnv allow
mix prod.tunnel
```

## Output

The mix task provides:
- ✅ Local URL: `http://localhost:PORT` 
- ✅ Public URL: `https://xyz.trycloudflare.com` (quick tunnel) or your subdomains (named tunnel)
- ✅ Process IDs for both Phoenix and tunnel
- ✅ Colored status messages

## Stopping

Press `Ctrl+C` to stop both the Phoenix app and Cloudflare tunnel. The mix task will clean up automatically.

## Troubleshooting

- **Port conflicts**: Mix task automatically finds next available port (starting from 4010)
- **Database errors**: Ensure production database is running with `mix db.prod.up`
- **Cloudflared missing**: Install via `brew install cloudflared`
- **Build errors**: Mix task automatically updates dependencies for production mode
- **Database connection**: Production database runs on port 5433, separate from dev (5432)

## Production Mode Features

- Compiled for production performance
- Minified assets
- Production database
- Proper error handling
- Clean process management