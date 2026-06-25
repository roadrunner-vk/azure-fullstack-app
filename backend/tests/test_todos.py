from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app


@pytest.fixture
def mock_db():
    db = MagicMock()
    db.todos = MagicMock()
    return db


@pytest.mark.asyncio
async def test_health():
    async with AsyncClient(
        transport=ASGITransport(app=app), base_url="http://test"
    ) as client:
        response = await client.get("/api/health")
    assert response.status_code == 200
    assert response.json() == {"status": "healthy"}


@pytest.mark.asyncio
async def test_list_todos_empty(mock_db):
    cursor = AsyncMock()
    cursor.to_list = AsyncMock(return_value=[])
    mock_db.todos.find.return_value.sort.return_value = cursor

    with patch("app.routes.todos.get_database", return_value=mock_db):
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.get("/api/todos/")
    assert response.status_code == 200
    assert response.json() == []


@pytest.mark.asyncio
async def test_create_todo(mock_db):
    mock_result = MagicMock()
    mock_result.inserted_id = "507f1f77bcf86cd799439011"
    mock_db.todos.insert_one = AsyncMock(return_value=mock_result)

    with patch("app.routes.todos.get_database", return_value=mock_db):
        async with AsyncClient(
            transport=ASGITransport(app=app), base_url="http://test"
        ) as client:
            response = await client.post(
                "/api/todos/",
                json={"title": "Test todo", "description": "A test"},
            )
    assert response.status_code == 201
    data = response.json()
    assert data["title"] == "Test todo"
    assert data["completed"] is False
