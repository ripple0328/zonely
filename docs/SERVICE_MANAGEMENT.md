# System Service Management

This guide shows how to run the Zonely production tunnel as a system service, ensuring it stays running even after system restarts or accidental termination.

## Option 1: macOS LaunchAgent (Recommended for macOS)

### Setup

1. **Copy the service file:**
   ```bash
   cp com.zonely.prod.plist ~/Library/LaunchAgents/
   ```

2. **Load the service:**
   ```bash
   launchctl load ~/Library/LaunchAgents/com.zonely.prod.plist
   ```

3. **Start the service:**
   ```bash
   launchctl start com.zonely.prod
   ```

### Management Commands

```bash
# Start service
launchctl start com.zonely.prod

# Stop service
launchctl stop com.zonely.prod

# Restart service
launchctl stop com.zonely.prod && launchctl start com.zonely.prod

# Check status
launchctl list | grep zonely

# View logs
tail -f logs/prod.log
tail -f logs/prod.error.log

# Unload service (disable)
launchctl unload ~/Library/LaunchAgents/com.zonely.prod.plist
```

### Features
- ✅ **Auto-restart**: Restarts if process dies
- ✅ **Boot startup**: Starts automatically on login
- ✅ **Logging**: Separate stdout/stderr logs
- ✅ **Environment**: Proper PATH and direnv integration
- ✅ **Throttling**: Prevents rapid restart loops

## Option 2: Linux systemd Service

### Setup

1. **Copy service file:**
   ```bash
   sudo cp zonely-prod.service /etc/systemd/system/
   ```

2. **Reload systemd:**
   ```bash
   sudo systemctl daemon-reload
   ```

3. **Enable and start:**
   ```bash
   sudo systemctl enable zonely-prod
   sudo systemctl start zonely-prod
   ```

### Management Commands

```bash
# Start service
sudo systemctl start zonely-prod

# Stop service
sudo systemctl stop zonely-prod

# Restart service
sudo systemctl restart zonely-prod

# Check status
sudo systemctl status zonely-prod

# View logs
sudo journalctl -u zonely-prod -f

# Enable auto-start
sudo systemctl enable zonely-prod

# Disable auto-start
sudo systemctl disable zonely-prod
```

## Option 3: PM2 Process Manager

### Setup

1. **Install PM2:**
   ```bash
   npm install -g pm2
   ```

2. **Start with config:**
   ```bash
   pm2 start ecosystem.config.js
   ```

3. **Save PM2 config:**
   ```bash
   pm2 save
   pm2 startup
   ```

### Management Commands

```bash
# Start application
pm2 start zonely-prod

# Stop application
pm2 stop zonely-prod

# Restart application
pm2 restart zonely-prod

# View status
pm2 status
pm2 list

# View logs
pm2 logs zonely-prod
pm2 logs zonely-prod --lines 50

# Monitor in real-time
pm2 monit

# Delete from PM2
pm2 delete zonely-prod
```

## Option 4: Docker Compose Service

### Create docker-compose.service.yml

```yaml
version: '3.8'
services:
  zonely-prod:
    build: .
    container_name: zonely-prod
    restart: unless-stopped
    ports:
      - "4010-4020:4010-4020"
    environment:
      - MIX_ENV=prod
      - CLOUDFLARE_TUNNEL_NAME=zonely
    volumes:
      - .:/app
      - ~/.cloudflared:/root/.cloudflared
    depends_on:
      - db_prod
    command: mix prod.tunnel

  db_prod:
    image: postgres:17
    container_name: zonely_db_prod_service
    restart: unless-stopped
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: zonely_prod
    ports:
      - "5433:5432"
    volumes:
      - postgres_prod_service_data:/var/lib/postgresql/data

volumes:
  postgres_prod_service_data:
```

### Docker Service Commands

```bash
# Start services
docker-compose -f docker-compose.service.yml up -d

# Stop services
docker-compose -f docker-compose.service.yml down

# View logs
docker-compose -f docker-compose.service.yml logs -f

# Restart services
docker-compose -f docker-compose.service.yml restart
```

## Comparison

| Method | Platform | Complexity | Auto-restart | Boot startup | Resource Usage |
|--------|----------|------------|--------------|--------------|----------------|
| **LaunchAgent** | macOS | Low | ✅ | ✅ | Low |
| **systemd** | Linux | Low | ✅ | ✅ | Low |
| **PM2** | Cross-platform | Medium | ✅ | ✅ | Medium |
| **Docker** | Cross-platform | High | ✅ | ✅ | High |

## Monitoring and Troubleshooting

### Log Locations

- **LaunchAgent**: `logs/prod.log`, `logs/prod.error.log`
- **systemd**: `journalctl -u zonely-prod`
- **PM2**: `pm2 logs zonely-prod`
- **Docker**: `docker-compose logs`

### Common Issues

1. **Service won't start**:
   - Check logs for errors
   - Verify paths in service files
   - Ensure dependencies are installed

2. **Environment variables not loaded**:
   - Verify direnv integration
   - Check PATH configuration
   - Test manually first

3. **Database connection issues**:
   - Ensure production database is running
   - Check port configurations
   - Verify network connectivity

4. **Cloudflare tunnel failures**:
   - Check tunnel authentication
   - Verify config file exists
   - Test tunnel manually

### Health Checks

Add to your service monitoring:

```bash
#!/bin/bash
# health-check.sh

# Check if Phoenix is responding
if curl -s http://localhost:4010 > /dev/null; then
    echo "✅ Phoenix is healthy"
else
    echo "❌ Phoenix is not responding"
    exit 1
fi

# Check if tunnel is active
if pgrep -f cloudflared > /dev/null; then
    echo "✅ Cloudflare tunnel is running"
else
    echo "❌ Cloudflare tunnel is not running"
    exit 1
fi
```

## Recommended Setup

For **development/testing**: Use **PM2** for easy management and monitoring

For **production/server**: Use **systemd** (Linux) or **LaunchAgent** (macOS) for native system integration

For **containerized environments**: Use **Docker Compose** with restart policies

## Security Considerations

- Run services as non-root user when possible
- Use proper file permissions on service files
- Secure log file locations
- Regular security updates for dependencies
- Monitor service resource usage