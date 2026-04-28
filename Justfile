# Zonely delegates production operations to ../mini-infra.

set shell := ["/usr/bin/env", "bash", "-lc"]

PLATFORM_JUST := "../mini-infra/platform/Justfile"
APP_NAME := "zonely"
LAUNCHD_LABEL := "us.qingbo.zonely.prod"
ENV_FILE := "${HOME}/.config/zonely/env.runtime"
PORT := "${PORT:-4020}"
PHX_HOST := "${PHX_HOST:-zonely.qingbo.us}"
DEPLOY_HOST := "${DEPLOY_HOST:-mini}"

dev:
	@portless zonely mix phx.server

_platform command:
	@APP_NAME={{APP_NAME}} LAUNCHD_LABEL={{LAUNCHD_LABEL}} ENV_FILE={{ENV_FILE}} PORT={{PORT}} PHX_HOST={{PHX_HOST}} DEPLOY_HOST={{DEPLOY_HOST}} just -f {{PLATFORM_JUST}} {{command}}

deploy: (_platform "deploy")

install: (_platform "install")

status: (_platform "status")

health: (_platform "health")

logs: (_platform "logs")

tail: (_platform "tail")

restart: (_platform "restart")

rollback: (_platform "rollback")

migrate: (_platform "migrate")
