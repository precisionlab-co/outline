COMPOSE ?= docker compose
COMPOSE_FILE ?= docker-compose.yml
DEV_ENV ?= .env.dev

COMPOSE_DEV = $(COMPOSE) --env-file $(DEV_ENV) -f $(COMPOSE_FILE) --profile dev

help:
	@printf "%s\n" \
		"dev-up        Start local Postgres and Redis" \
		"dev           Start dependencies and run Outline dev server" \
		"dev-down      Stop local dependencies" \
		"check-yarn    Verify Yarn is available on PATH" \
		"test          Run tests against local Postgres" \
		"watch         Run tests in watch mode"

dev-up:
	$(COMPOSE_DEV) up -d postgres redis

check-yarn:
	@command -v yarn >/dev/null 2>&1 || { \
		echo "Yarn is required for Outline local development."; \
		echo "Install Corepack/Yarn, then rerun this target:"; \
		echo "  npm install -g corepack"; \
		echo "  corepack enable"; \
		echo "  corepack prepare yarn@4.11.0 --activate"; \
		exit 1; \
	}

dev: check-yarn dev-up
	yarn install --immutable
	yarn install-local-ssl
	yarn dev:watch

up: dev

dev-down:
	$(COMPOSE_DEV) stop
	$(COMPOSE_DEV) rm -f

destroy: dev-down

test: check-yarn dev-up
	NODE_ENV=test yarn sequelize db:drop
	NODE_ENV=test yarn sequelize db:create
	NODE_ENV=test yarn sequelize db:migrate
	yarn test

watch: check-yarn dev-up
	NODE_ENV=test yarn sequelize db:drop
	NODE_ENV=test yarn sequelize db:create
	NODE_ENV=test yarn sequelize db:migrate
	yarn test:watch

.PHONY: help dev-up dev up dev-down destroy check-yarn test watch
