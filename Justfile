# Zonely delegates production operations to ../mini-infra.

set shell := ["/usr/bin/env", "bash", "-lc"]

PLATFORM_JUST := "../mini-infra/platform/Justfile"
APP_NAME := "zonely"
LAUNCHD_LABEL := "us.qingbo.zonely.prod"
ENV_FILE := "${HOME}/.config/zonely/env.runtime"
APP_PORT := "${ZONELY_PROD_PORT:-4020}"
PHX_HOST := "${PHX_HOST:-zonely.qingbo.us}"
DEPLOY_HOST := "${DEPLOY_HOST:-mini}"

dev:
	@PORTLESS_STATE_DIR=/tmp/personal-portless-http PORTLESS_HTTPS=0 PORTLESS_PORT=1355 APP_DISPLAY_NAME=Zonely portless zonely ./scripts/dev_with_tidewave_banner.sh

_platform command:
	@APP_NAME={{APP_NAME}} LAUNCHD_LABEL={{LAUNCHD_LABEL}} ENV_FILE={{ENV_FILE}} PORT={{APP_PORT}} PHX_HOST={{PHX_HOST}} DEPLOY_HOST={{DEPLOY_HOST}} just -f {{PLATFORM_JUST}} {{command}}

deploy: (_platform "deploy")

install: (_platform "install")

status: (_platform "status")

health: (_platform "health")

logs: (_platform "logs")

tail: (_platform "tail")

restart: (_platform "restart")

rollback: (_platform "rollback")

migrate: (_platform "migrate")
