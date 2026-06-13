from pydantic import BaseModel
from datetime import datetime


class LoginRequest(BaseModel):
    username: str
    password: str


class UserPublic(BaseModel):
    id: str
    full_name: str
    username: str
    created_at: datetime


class LoginResponse(BaseModel):
    success: bool
    user: UserPublic
