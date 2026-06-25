from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase

from app.config import MONGODB_URL, MONGODB_DB_NAME

_client: AsyncIOMotorClient | None = None
_db: AsyncIOMotorDatabase | None = None


async def connect_db() -> None:
    global _client, _db
    _client = AsyncIOMotorClient(MONGODB_URL)
    _db = _client[MONGODB_DB_NAME]


async def close_db() -> None:
    global _client
    if _client:
        _client.close()


def get_database() -> AsyncIOMotorDatabase:
    assert _db is not None, "Database not connected. Call connect_db() first."
    return _db
