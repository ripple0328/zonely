# Zonely — thin wrapper around platform ops Justfile

set shell := ["/usr/bin/env", "bash", "-lc"]

PLATFORM_JUST := "/Users/qingbo/Projects/Personal/platform/Justfile"
APP_NAME := "zonely"
LAUNCHD_LABEL := "com.zonely.prod"
ENV_FILE := "${HOME}/.config/zonely/.envrc.worker"
PORT := "${PORT:-4010}"
PHX_HOST := "${PHX_HOST:-saymyname.qingbo.us}"

status:
	@APP_NAME={{APP_NAME}} LAUNCHD_LABEL={{LAUNCHD_LABEL}} ENV_FILE={{ENV_FILE}} PORT={{PORT}} PHX_HOST={{PHX_HOST}} just -f {{PLATFORM_JUST}} status

health:
	@APP_NAME={{APP_NAME}} LAUNCHD_LABEL={{LAUNCHD_LABEL}} ENV_FILE={{ENV_FILE}} PORT={{PORT}} PHX_HOST={{PHX_HOST}} just -f {{PLATFORM_JUST}} health

logs:
	@APP_NAME={{APP_NAME}} LAUNCHD_LABEL={{LAUNCHD_LABEL}} ENV_FILE={{ENV_FILE}} PORT={{PORT}} PHX_HOST={{PHX_HOST}} just -f {{PLATFORM_JUST}} logs

restart:
	@APP_NAME={{APP_NAME}} LAUNCHD_LABEL={{LAUNCHD_LABEL}} ENV_FILE={{ENV_FILE}} PORT={{PORT}} PHX_HOST={{PHX_HOST}} just -f {{PLATFORM_JUST}} restart

migrate:
	@APP_NAME={{APP_NAME}} LAUNCHD_LABEL={{LAUNCHD_LABEL}} ENV_FILE={{ENV_FILE}} PORT={{PORT}} PHX_HOST={{PHX_HOST}} just -f {{PLATFORM_JUST}} migrate

deploy-mini:
	@APP_NAME={{APP_NAME}} LAUNCHD_LABEL={{LAUNCHD_LABEL}} ENV_FILE={{ENV_FILE}} PORT={{PORT}} PHX_HOST={{PHX_HOST}} just -f {{PLATFORM_JUST}} deploy-mini

deploy: deploy-mini
