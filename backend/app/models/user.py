from beanie import Document, Indexed
from pydantic import Field
from datetime import datetime


class Photographer(Document):
    full_name: str
    username: Indexed(str, unique=True)
    password: str  # hashed
    role: str = "photographer"  # "photographer" or "admin"
    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Settings:
        name = "photographers"
