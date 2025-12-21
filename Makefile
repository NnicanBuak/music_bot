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
	@echo "  install      Install dependencies with dev tools"
	@echo "  test         Run linting, type checking and tests"
	@echo "  lint         Run ruff linter and formatter"
	@echo "  mypy         Run mypy type checker"
	@echo "  pytest       Run pytest tests"
	@echo "  test-cov     Run tests with coverage report"
	@echo "  db           Start only DB services"
	@echo "  run          Run bot locally"
	@echo "  migrate      Apply migrations"
	@echo "  migrate-new  Create new migration [msg='description']"
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

.PHONY: install
install:
	@echo "Installing dependencies..."
	@uv sync --all-groups

.PHONY: test
test: lint mypy pytest
	@echo "\n✅ All checks passed!"

.PHONY: lint
lint:
	@echo "Running ruff linter and formatter..."
	@uv run ruff check .
	@uv run ruff format .

.PHONY: lint-fix
lint-fix:
	@echo "Auto-fixing with ruff..."
	@uv run ruff check . --fix
	@uv run ruff format .

.PHONY: mypy
mypy:
	@echo "Running mypy type checker..."
	@uv run python -m mypy app

.PHONY: pytest
pytest:
	@echo "Running pytest..."
	@uv run pytest

.PHONY: test-cov
test-cov:
	@echo "Running tests with coverage..."
	@uv run pytest --cov=app --cov-report=html --cov-report=term
	@echo "\n📊 Coverage report generated in htmlcov/index.html"

.PHONY: db
db:
	@echo "Starting database services..."
	@docker compose up -d postgres redis

.PHONY: run
run:
	@echo "Running bot locally..."
	@uv run python -O -m app

.PHONY: migrate
migrate:
	@echo "Applying migrations..."
	@uv run alembic upgrade head

.PHONY: migrate-new
migrate-new:
	@if [ -z "$(msg)" ]; then \
		echo "❌ Error: msg parameter required"; \
		echo "Usage: make migrate-new msg='your migration description'"; \
		exit 1; \
	fi
	@echo "Creating new migration: $(msg)"
	@uv run alembic revision --autogenerate -m "$(msg)"

.PHONY: clean
clean:
	@echo "Cleaning up..."
	@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	@find . -type d -name ".mypy_cache" -exec rm -rf {} + 2>/dev/null || true
	@find . -type d -name "htmlcov" -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete 2>/dev/null || true
	@echo "✨ Cleaned!"
