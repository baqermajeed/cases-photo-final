from beanie import Document
from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime
from uuid import uuid4


class Image(BaseModel):
    id: str = Field(default_factory=lambda: uuid4().hex)
    url: str
    uploaded_at: datetime = Field(default_factory=datetime.utcnow)
    uploaded_by_username: Optional[str] = None


class Step(BaseModel):
    id: str = Field(default_factory=lambda: uuid4().hex)
    step_number: int
    title: str
    description: Optional[str] = None
    images: List[Image] = Field(default_factory=list)
    is_done: bool = False
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    is_deleted: bool = False


class Patient(Document):
    name: str
    phone: str
    address: str
    registration_date: datetime = Field(default_factory=datetime.utcnow)
    note: Optional[str] = None
    steps: List[Step] = Field(default_factory=list)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
    is_deleted: bool = False

    class Settings:
        name = "patients"
