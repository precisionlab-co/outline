COMPOSE ?= docker compose
COMPOSE_FILE ?= docker-compose.yml
DEV_ENV ?= .env.dev
PROD_ENV ?= .env.prod
STORAGE_DIR ?= ../storage
STORAGE_ENV ?= $(STORAGE_DIR)/.env.prod
EDGE_DIR ?= ../edge

COMPOSE_DEV = $(COMPOSE) --env-file $(DEV_ENV) -f $(COMPOSE_FILE) --profile dev
COMPOSE_PROD = $(COMPOSE) --env-file $(PROD_ENV) -f $(COMPOSE_FILE) --profile prod
COMPOSE_STORAGE = $(COMPOSE) --env-file $(STORAGE_ENV) -f $(STORAGE_DIR)/docker-compose.yml
COMPOSE_EDGE = $(COMPOSE) -f $(EDGE_DIR)/docker-compose.yml

help:
	@printf "%s\n" \
		"dev-up        Start local Postgres and Redis" \
		"dev           Start dependencies and run Outline dev server" \
		"dev-down      Stop local dependencies" \
		"check-yarn    Verify Yarn is available on PATH" \
		"build         Build production Outline images" \
		"prod-config   Validate storage, edge, and Outline compose files" \
		"network       Ensure the shared edge Docker network exists" \
		"prod-up       Build and start storage, edge, and Outline" \
		"prod-down     Stop the production Outline stack" \
		"storage-down  Stop the shared storage stack" \
		"edge-down     Stop the shared edge stack" \
		"test          Run tests against local Postgres" \
		"watch         Run tests in watch mode"

dev-up:
	$(COMPOSE_DEV) up -d dev-outline-postgres dev-outline-redis

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

build:
	$(COMPOSE_PROD) --profile build build outline-base
	$(COMPOSE_PROD) build outline

prod-config:
	$(COMPOSE_STORAGE) config --quiet
	$(COMPOSE_EDGE) config --quiet
	$(COMPOSE_PROD) config --quiet

network:
	docker network inspect edge_proxy >/dev/null 2>&1 || docker network create edge_proxy >/dev/null

storage-up:
	$(COMPOSE_STORAGE) up -d

edge-up:
	$(COMPOSE_EDGE) up -d nginx

outline-prod-up:
	$(COMPOSE_PROD) up -d outline

prod-up: prod-config build network storage-up edge-up outline-prod-up

prod-down:
	$(COMPOSE_PROD) down

storage-down:
	$(COMPOSE_STORAGE) down

edge-down:
	$(COMPOSE_EDGE) down

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

.PHONY: help dev-up dev up dev-down destroy check-yarn build prod-config network storage-up edge-up outline-prod-up prod-up prod-down storage-down edge-down test watch
