# SayMyName SLO & Alert Policy (GAT-98)

## Service: SayMyName (saymyname.qingbo.us)
**App:** Zonely (pronunciation service on dedicated subdomain)
**Criticality:** Medium (personal project, but public-facing)

## Service Level Objectives (SLOs)

### Availability SLO
- **Target:** 99.5% uptime (monthly)
- **Measurement:** HTTP 200 responses from /healthz
- **Window:** 30-day rolling window
- **Budget:** 3.6 hours downtime per month

### Latency SLO
- **Target:** 95% of requests < 500ms (p95)
- **Measurement:** Response time for / and /api/pronounce endpoints
- **Window:** 1-hour sliding window

### Error Rate SLO
- **Target:** < 1% error rate
- **Measurement:** HTTP 5xx responses / total requests
- **Window:** 1-hour sliding window

## "Down" Definition

Service is considered **DOWN** when ANY of:
1. `/healthz` returns non-200 status
2. `/readyz` returns 503 (critical dependency failure)
3. No response within 10 seconds (timeout)
4. >50 consecutive failures (circuit breaker)

Service is considered **DEGRADED** when:
1. Response time p95 > 1s for 5+ minutes
2. Error rate > 5% for 5+ minutes
3. `/readyz` returns 200 but with warnings in response

## Alert Channels

### Primary
- **Telegram:** @ripple0328 (via OpenClaw)
- **Delivery:** Immediate for DOWN, throttled for DEGRADED

### Secondary
- **Email:** ripple0328@gmail.com (critical only)
- **Logs:** Written to Prometheus for historical analysis

## Alert Thresholds & Rules

### Critical Alerts (Immediate)
1. **Service Down**
   - Condition: /healthz fails for 3 consecutive checks (30s)
   - Action: Telegram notification immediately
   - Message: "🚨 SayMyName DOWN - /healthz failing"

2. **Database Failure**
   - Condition: /readyz returns 503
   - Action: Telegram notification immediately
   - Message: "🚨 SayMyName DB FAILURE - /readyz: not_ready"

3. **Complete Outage**
   - Condition: No successful response for 5 minutes
   - Action: Telegram + Email
   - Message: "🚨 CRITICAL: SayMyName OUTAGE (5min+)"

### Warning Alerts (Throttled - max 1/hour)
1. **High Latency**
   - Condition: p95 > 1s for 10+ minutes
   - Action: Telegram (once per hour max)
   - Message: "⚠️ SayMyName SLOW - p95 latency > 1s"

2. **Elevated Errors**
   - Condition: Error rate >5% for 10+ minutes
   - Action: Telegram (once per hour max)
   - Message: "⚠️ SayMyName errors elevated (5%+)"

3. **Degraded State**
   - Condition: /readyz has warnings
   - Action: Log only (no immediate alert)
   - Review: Daily summary

## Check Frequency

- **Liveness (/healthz):** Every 10 seconds
- **Readiness (/readyz):** Every 30 seconds  
- **Version check:** Once per deployment (verify restart)

## Monitoring Implementation

### Option 1: Prometheus Blackbox Exporter
```yaml
# Scrape config for SayMyName
scrape_configs:
  - job_name: 'saymyname-blackbox'
    metrics_path: /probe
    params:
      module: [http_2xx]
    static_configs:
      - targets:
        - https://saymyname.qingbo.us/healthz
        - https://saymyname.qingbo.us/readyz
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: localhost:9115  # Blackbox exporter
```

### Option 2: OpenClaw Cron + Heartbeat
```javascript
// Simplified check via OpenClaw cron
async function checkSayMyName() {
  try {
    const health = await fetch('https://saymyname.qingbo.us/healthz');
    const ready = await fetch('https://saymyname.qingbo.us/readyz');
    
    if (!health.ok || !ready.ok) {
      // Alert via Telegram
      return `🚨 SayMyName health check failed`;
    }
    return 'HEARTBEAT_OK';
  } catch (e) {
    return `🚨 SayMyName unreachable: ${e.message}`;
  }
}
```

## Recovery Procedures

### Automatic Recovery
1. **Phoenix supervision tree** restarts crashed processes
2. **launchd** restarts the entire app if process dies
3. **Database reconnection** automatic via Ecto pool

### Manual Recovery (if automatic fails)
```bash
# SSH to mini
ssh mini

# Check service status
launchctl list | grep zonely

# Restart service
launchctl kickstart -k gui/$(id -u)/com.zonely.prod

# Check logs
tail -f ~/Library/Logs/zonely-error.log

# Verify health
curl https://saymyname.qingbo.us/healthz
curl https://saymyname.qingbo.us/readyz
```

## Dashboard Metrics

### Key Metrics to Track
1. **Uptime %** (30-day rolling)
2. **Request rate** (req/s)
3. **Latency distribution** (p50, p95, p99)
4. **Error rate %** (5xx/total)
5. **Health check status** (pass/fail timeline)

### Recommended Grafana Panels
- Uptime graph (target: 99.5% line)
- Latency heatmap
- Error rate over time
- Health check status (green/red timeline)
- Request volume

## Review Cadence

- **Daily:** Check Prometheus for any alerts
- **Weekly:** Review SLO compliance (are we within budget?)
- **Monthly:** Adjust thresholds if needed based on actual traffic

## Success Criteria

- ✅ No false positives for 1 week
- ✅ Catch real outage within 30 seconds
- ✅ Clear, actionable alert messages
- ✅ <5 minutes to investigate and respond to alert
