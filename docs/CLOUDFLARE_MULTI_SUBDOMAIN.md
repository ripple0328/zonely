# Multi-Subdomain Cloudflare Tunnel Setup

This guide shows how to set up a single Cloudflare tunnel that serves multiple subdomains from the same Phoenix application using ingress rules.

## Prerequisites

1. **Cloudflare Account**: Free account at [cloudflare.com](https://cloudflare.com)
2. **Domain in Cloudflare**: Add your domain to Cloudflare DNS management
3. **Cloudflared Installed**: `brew install cloudflared`

## Step 1: Authenticate with Cloudflare

```bash
# Login to your Cloudflare account
cloudflared tunnel login
```

This opens a browser where you:
- Select your domain from the list
- Authorize the connection
- Downloads certificate to `~/.cloudflared/cert.pem`

## Step 2: Create Named Tunnel

```bash
# Create a single tunnel for multiple subdomains
cloudflared tunnel create zonely
```

This creates:
- A tunnel with UUID (e.g., `abc123-def456-ghi789`)
- Credentials file at `~/.cloudflared/<tunnel-id>.json`

## Step 3: Configure Ingress Rules

Create the configuration file:

```bash
mkdir -p ~/.cloudflared
```

Create `~/.cloudflared/config.yml`:

```yaml
tunnel: zonely
credentials-file: ~/.cloudflared/<your-tunnel-id>.json

ingress:
  # Site 1 - Main application
  - hostname: app.yourdomain.com
    service: http://localhost:4010
    originRequest:
      httpHostHeader: app.yourdomain.com
  
  # Site 2 - Admin/Dashboard
  - hostname: admin.yourdomain.com
    service: http://localhost:4010
    originRequest:
      httpHostHeader: admin.yourdomain.com
      
  # Site 3 - API subdomain (optional)
  - hostname: api.yourdomain.com
    service: http://localhost:4010
    originRequest:
      httpHostHeader: api.yourdomain.com
  
  # Catch-all rule (required - must be last)
  - service: http_status:404
```

**Replace**:
- `<your-tunnel-id>` with the actual tunnel ID from step 2
- `yourdomain.com` with your actual domain

**Note**: The port `4010` in the config is just a starting point. The production script automatically updates this to match the actual dynamic port (4010, 4011, 4012, etc.) that Phoenix uses.

## Step 4: Configure DNS Routes

Route each subdomain to your tunnel:

```bash
# Route DNS for each subdomain
cloudflared tunnel route dns zonely app.saymyname.qingbo.us
cloudflared tunnel route dns zonely admin.saymyname.qingbo.us
cloudflared tunnel route dns zonely api.saymyname.qingbo.us
```

## Step 5: Phoenix Router Configuration

Update your Phoenix router to handle different subdomains:

```elixir
# lib/zonely_web/router.ex
defmodule ZonelyWeb.Router do
  use ZonelyWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ZonelyWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :put_site_context
  end

  # Main app routes
  scope "/", ZonelyWeb do
    pipe_through :browser
    
    # Main site (app.yourdomain.com)
    live "/", MapLive, :index, host: "app."
    live "/directory", DirectoryLive, :index, host: "app."
    # ... other main app routes
  end

  # Admin routes
  scope "/", ZonelyWeb.Admin do
    pipe_through [:browser, :admin_auth]
    
    # Admin site (admin.yourdomain.com)
    live "/", DashboardLive, :index, host: "admin."
    live "/users", UserManagementLive, :index, host: "admin."
    # ... other admin routes
  end

  # API routes (optional)
  scope "/api", ZonelyWeb do
    pipe_through :api
    
    # API endpoints (api.yourdomain.com)
    get "/users", UserController, :index, host: "api."
    # ... other API routes
  end

  # Helper function to set site context
  defp put_site_context(conn, _opts) do
    site = case conn.host do
      "app." <> _domain -> :main_app
      "admin." <> _domain -> :admin
      "api." <> _domain -> :api
      _ -> :main_app  # fallback
    end
    
    assign(conn, :current_site, site)
  end
end
```

## Step 6: Start the Tunnel

```bash
# Run the tunnel with config file
cloudflared tunnel run zonely
```

Or run in background:

```bash
# Run in background
cloudflared tunnel run zonely &

# Check status
cloudflared tunnel info zonely
```

## Step 7: Test Your Subdomains

Your subdomains should now be accessible:

- `https://app.yourdomain.com` → Main application
- `https://admin.yourdomain.com` → Admin interface  
- `https://api.yourdomain.com` → API endpoints

## Troubleshooting

### Check Tunnel Status
```bash
cloudflared tunnel list
cloudflared tunnel info zonely
```

### View Tunnel Logs
```bash
cloudflared tunnel run zonely --loglevel debug
```

### Test DNS Resolution
```bash
dig app.yourdomain.com
dig admin.yourdomain.com
```

### Check Phoenix Routing
Add debugging to your router:

```elixir
defp put_site_context(conn, _opts) do
  site = case conn.host do
    "app." <> _domain -> :main_app
    "admin." <> _domain -> :admin
    "api." <> _domain -> :api
    _ -> :main_app
  end
  
  # Debug logging
  require Logger
  Logger.info("Host: #{conn.host}, Site: #{site}")
  
  assign(conn, :current_site, site)
end
```

## Configuration Files Summary

**`~/.cloudflared/config.yml`**:
- Defines tunnel name and credentials
- Sets up ingress rules for each subdomain
- Routes traffic to local Phoenix server

**Phoenix Router**:
- Uses host-based routing
- Different pipelines for different sites
- Context assignment for site-specific logic

## Benefits

- ✅ Single tunnel for multiple sites
- ✅ Custom subdomains on your domain
- ✅ SSL/TLS termination handled by Cloudflare
- ✅ DDoS protection and CDN benefits
- ✅ Traffic analytics in Cloudflare dashboard
- ✅ Easy to add more subdomains
- ✅ **Dynamic port handling** - automatically adapts to available ports

## Dynamic Port Configuration

The production script (`mix prod.tunnel`) automatically:

1. **Finds available port** (4010-4999 range)
2. **Updates Cloudflare config** to use the actual port
3. **Creates backup** of original config
4. **Starts tunnel** with correct port mapping

This means you don't need to worry about port conflicts - the script handles everything dynamically!

## Next Steps

- Monitor traffic in Cloudflare dashboard
- Set up additional security rules if needed
- Configure caching policies per subdomain
- Add more subdomains by updating config.yml and DNS routes