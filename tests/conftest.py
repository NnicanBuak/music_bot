"""Pytest configuration and shared fixtures."""

import asyncio
from collections.abc import AsyncGenerator, Generator
from typing import Any
from unittest.mock import AsyncMock, MagicMock

import pytest
import pytest_asyncio
from aiogram import Bot, Dispatcher
from aiogram.fsm.storage.memory import MemoryStorage
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.models.sql.base import Base


@pytest.fixture(scope="session")
def event_loop() -> Generator[asyncio.AbstractEventLoop, None, None]:
    """Create an instance of the default event loop for the test session."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()


@pytest_asyncio.fixture
async def db_engine() -> AsyncGenerator[AsyncEngine, None]:
    """Create test database engine."""
    engine = create_async_engine(
        "sqlite+aiosqlite:///:memory:",
        poolclass=NullPool,
        echo=False,
    )
    
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    
    yield engine
    
    await engine.dispose()


@pytest_asyncio.fixture
async def db_session(db_engine: AsyncEngine) -> AsyncGenerator[AsyncSession, None]:
    """Create test database session."""
    async_session = async_sessionmaker(
        db_engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )
    
    async with async_session() as session:
        yield session
        await session.rollback()


@pytest.fixture
def bot() -> Bot:
    """Create mock Bot instance."""
    bot_mock = MagicMock(spec=Bot)
    bot_mock.token = "123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"
    bot_mock.id = 123456789
    bot_mock.username = "test_bot"
    bot_mock.send_message = AsyncMock()
    bot_mock.send_audio = AsyncMock()
    bot_mock.send_photo = AsyncMock()
    bot_mock.edit_message_text = AsyncMock()
    bot_mock.edit_message_reply_markup = AsyncMock()
    bot_mock.answer_callback_query = AsyncMock()
    bot_mock.delete_message = AsyncMock()
    return bot_mock


@pytest.fixture
def dispatcher() -> Dispatcher:
    """Create Dispatcher instance with memory storage."""
    storage = MemoryStorage()
    return Dispatcher(storage=storage)


@pytest.fixture
def mock_message() -> MagicMock:
    """Create mock Message instance."""
    message = MagicMock()
    message.message_id = 1
    message.chat.id = 123456789
    message.from_user.id = 123456789
    message.from_user.username = "testuser"
    message.from_user.first_name = "Test"
    message.from_user.last_name = "User"
    message.from_user.is_bot = False
    message.text = "/start"
    message.answer = AsyncMock()
    message.reply = AsyncMock()
    message.edit_text = AsyncMock()
    message.delete = AsyncMock()
    return message


@pytest.fixture
def mock_callback_query() -> MagicMock:
    """Create mock CallbackQuery instance."""
    callback = MagicMock()
    callback.id = "callback_id_123"
    callback.data = "test_data"
    callback.from_user.id = 123456789
    callback.from_user.username = "testuser"
    callback.message.message_id = 1
    callback.message.chat.id = 123456789
    callback.answer = AsyncMock()
    callback.message.edit_text = AsyncMock()
    callback.message.edit_reply_markup = AsyncMock()
    return callback


@pytest.fixture
def mock_user_data() -> dict[str, Any]:
    """Create mock user data for tests."""
    return {
        "user_id": 123456789,
        "telegram_id": 123456789,
        "username": "testuser",
        "first_name": "Test",
        "last_name": "User",
    }


@pytest.fixture
def mock_track_data() -> dict[str, Any]:
    """Create mock track data for tests."""
    return {
        "title": "Test Track",
        "artist": "Test Artist",
        "album": "Test Album",
        "duration": 180,
        "file_id": "test_file_id_123",
    }


@pytest.fixture
def mock_playlist_data() -> dict[str, Any]:
    """Create mock playlist data for tests."""
    return {
        "name": "Test Playlist",
        "description": "Test playlist description",
        "is_public": False,
    }
