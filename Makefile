# Файл для хранения текущего окружения
MAKEENV_FILE := .makeenv

# Читаем сохранённое окружение (если есть)
-include $(MAKEENV_FILE)

# По умолчанию dev, если ничего не сохранено
ENV ?= dev

COMPOSE_FILE = $(if $(filter prod,$(ENV)),deploy/docker-compose.prod.yml,docker-compose.yml)
COMPOSE_CMD = docker compose -f $(COMPOSE_FILE)

.PHONY: help
help:
	@echo ""
	@echo "Current environment: \033[36m$(ENV)\033[0m"
	@echo ""
	@echo "Usage: make <target> [ENV=dev|prod]"
	@echo ""
	@echo "Environment:"
	@echo "  dev          Switch to development mode"
	@echo "  prod         Switch to production mode"
	@echo ""
	@echo "Commands:"
	@echo "  build        Build $(ENV) environment"
	@echo "  up           Start $(ENV) containers"
	@echo "  down         Stop $(ENV) containers"
	@echo "  logs         Show logs [SVC=service_name]"
	@echo "  restart      Restart $(ENV) environment"
	@echo ""
ifeq ($(ENV),dev)
	@echo "Dev-specific:"
	@echo "  db           Start only DB services"
	@echo "  run          Run bot locally"
	@echo "  migrate      Apply migrations"
	@echo "  format       Format code"
endif
	@echo ""

##@ Environment Switch

.PHONY: dev
dev:
	@echo "ENV=dev" > $(MAKEENV_FILE)
	@echo "Switched to \033[36mdevelopment\033[0m mode"
	@echo "Now run: make build && make up"

.PHONY: prod
prod:
	@echo "ENV=prod" > $(MAKEENV_FILE)
	@echo "Switched to \033[32mproduction\033[0m mode"
	@echo "Now run: make build && make up"

##@ Main Commands

.PHONY: build
build:
	@echo "Building $(ENV) environment..."
ifeq ($(ENV),prod)
	@cd deploy && docker compose -f docker-compose.prod.yml build
else
	@docker compose build
endif

.PHONY: up
up:
	@echo "Starting $(ENV) environment..."
ifeq ($(ENV),prod)
	@cd deploy && docker compose -f docker-compose.prod.yml up -d
else
	@docker compose up -d
endif

.PHONY: down
down:
	@echo "Stopping $(ENV) environment..."
	@$(COMPOSE_CMD) down

.PHONY: logs
logs:
	@$(COMPOSE_CMD) logs -f $(SVC)

.PHONY: restart
restart: down up

##@ Dev Commands

.PHONY: db
db:
	@docker compose up -d postgres redis

.PHONY: run
run:
	@uv run python -O -m app

.PHONY: migrate
migrate:
	@uv run alembic upgrade head

.PHONY: format
format:
	@uv run ruff format .
	@uv run ruff check . --fix
