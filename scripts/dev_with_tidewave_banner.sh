#!/usr/bin/env bash
set -euo pipefail

app_port="${PORT:-4000}"
app_url="${PORTLESS_URL:-http://localhost:${app_port}}"
app_label="${APP_DISPLAY_NAME:-Zonely}"

host_with_optional_port="${app_url#*://}"
host_with_optional_port="${host_with_optional_port%%/*}"
app_host="${host_with_optional_port%%:*}"

if [[ -z "${app_host}" ]]; then
  app_host="localhost"
fi

direct_app_url="http://${app_host}:${app_port}"
tidewave_origin="${direct_app_url}"
tidewave_origin_encoded="${tidewave_origin//:/%3A}"
tidewave_origin_encoded="${tidewave_origin_encoded//\//%2F}"
tidewave_web_url="http://${app_host}:9832/?origin=${tidewave_origin_encoded}"
tidewave_mcp_url="http://127.0.0.1:${app_port}/tidewave/mcp"
tidewave_status="not checked"

if command -v lsof >/dev/null 2>&1 && lsof -nP -iTCP:9832 -sTCP:LISTEN >/dev/null 2>&1; then
  tidewave_status="running on port 9832"
elif [[ -d /Applications/Tidewave.app ]]; then
  open -g -a Tidewave >/dev/null 2>&1 || true

  for _ in {1..5}; do
    if lsof -nP -iTCP:9832 -sTCP:LISTEN >/dev/null 2>&1; then
      tidewave_status="started Tidewave.app on port 9832"
      break
    fi

    sleep 0.2
  done

  if [[ "${tidewave_status}" == "not checked" ]]; then
    tidewave_status="Tidewave.app was opened, but port 9832 is not listening yet"
  fi
else
  tidewave_status="Tidewave.app not found; install or start Tidewave CLI/App for Web"
fi

cat <<EOF

${app_label} dev URLs
  App:                  ${direct_app_url}
  Portless:             ${app_url}
  Tidewave Web:         ${tidewave_web_url}
  Tidewave Web status:  ${tidewave_status}
  Tidewave MCP (POST):  ${tidewave_mcp_url}

EOF

exec mix phx.server
