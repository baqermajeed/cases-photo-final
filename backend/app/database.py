from beanie import init_beanie
from motor.motor_asyncio import AsyncIOMotorClient
from typing import Optional

from .models.user import Photographer
from .models.patient import Patient

_client: Optional[AsyncIOMotorClient] = None


async def init_db(database_url: str):
    """Initialize MongoDB (Motor) and Beanie ODM."""
    global _client
    _client = AsyncIOMotorClient(database_url)
    db = _client.get_default_database()
    await init_beanie(database=db, document_models=[Photographer, Patient])
