# Тесты для Music Bot

## Структура

```
tests/
├── conftest.py              # Общие фикстуры и конфигурация pytest
├── unit/                    # Юнит-тесты
│   ├── test_models.py      # Тесты моделей базы данных
│   ├── test_services.py    # Тесты сервисного слоя
│   └── test_utils.py       # Тесты утилит
├── integration/             # Интеграционные тесты
│   ├── test_handlers.py    # Тесты Telegram хендлеров
│   └── test_workflows.py   # Тесты полных сценариев
└── e2e/                     # End-to-end тесты
    └── test_bot.py         # Тесты всего бота
```

## Запуск тестов

### Все тесты
```bash
pytest
```

### Только юнит-тесты
```bash
pytest tests/unit -m unit
```

### Только интеграционные тесты
```bash
pytest tests/integration -m integration
```

### С покрытием кода
```bash
pytest --cov=app --cov-report=html
```

### Конкретный файл
```bash
pytest tests/unit/test_models.py
```

### Конкретный тест
```bash
pytest tests/unit/test_models.py::TestUserModel::test_create_user
```

### С выводом print
```bash
pytest -s
```

## Фикстуры

### База данных
- `db_engine` - тестовый движок SQLite в памяти
- `db_session` - сессия базы данных для тестов

### Telegram
- `bot` - мок объект Bot
- `dispatcher` - инстанс Dispatcher с MemoryStorage
- `mock_message` - мок объект Message
- `mock_callback_query` - мок объект CallbackQuery

### Тестовые данные
- `mock_user_data` - данные пользователя
- `mock_track_data` - данные трека
- `mock_playlist_data` - данные плейлиста

## Добавление новых тестов

### 1. Тесты моделей

Добавляйте в `tests/unit/test_models.py`:

```python
class TestNewModel:
    @pytest.mark.asyncio
    async def test_create_instance(self, db_session: AsyncSession) -> None:
        # Ваш тест
        pass
```

### 2. Тесты сервисов

Добавляйте в `tests/unit/test_services.py`:

```python
class TestNewService:
    @pytest.mark.asyncio
    async def test_service_method(self, db_session: AsyncSession) -> None:
        # Ваш тест
        pass
```

### 3. Тесты хендлеров

Добавляйте в `tests/integration/test_handlers.py`:

```python
class TestNewHandler:
    @pytest.mark.asyncio
    async def test_handler(self, bot: Bot, mock_message: MagicMock, db_session: AsyncSession) -> None:
        # Ваш тест
        pass
```

## Маркеры

Используйте маркеры для категоризации:

```python
@pytest.mark.unit
def test_something():
    pass

@pytest.mark.integration
async def test_integration():
    pass

@pytest.mark.slow
async def test_slow_operation():
    pass
```

## Best Practices

1. **Изоляция**: каждый тест должен быть независимым
2. **Именование**: используйте описательные имена `test_что_когда_ожидается`
3. **AAA паттерн**: Arrange, Act, Assert
4. **Моки**: используйте моки для внешних зависимостей
5. **Async**: используйте `@pytest.mark.asyncio` для асинхронных тестов
6. **Фикстуры**: переиспользуйте фикстуры из `conftest.py`
7. **Документация**: добавляйте docstrings к тестам

## Конфигурация CI/CD

Добавьте в `.github/workflows/tests.yml`:

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-python@v4
        with:
          python-version: '3.12'
      - run: pip install -r requirements.txt
      - run: pytest --cov=app --cov-report=xml
      - uses: codecov/codecov-action@v3
```

## Требования

Добавьте в зависимости разработки:

```toml
[dependency-groups]
dev = [
    "pytest>=8.0.0",
    "pytest-asyncio>=0.23.0",
    "pytest-cov>=4.1.0",
    "pytest-mock>=3.12.0",
    "aiosqlite>=0.19.0",
]
```
