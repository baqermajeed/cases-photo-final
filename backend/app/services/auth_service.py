from typing import Optional
from passlib.context import CryptContext

from ..models.user import Photographer
from ..config import settings
from ..utils.jwt_utils import create_access_token

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)


async def authenticate_user(username: str, password: str) -> Optional[Photographer]:
    user = await Photographer.find_one(Photographer.username == username)
    if not user:
        return None
    if not verify_password(password, user.password):
        return None
    return user


async def issue_access_token(user: Photographer) -> str:
    return create_access_token(str(user.id), settings.JWT_SECRET, settings.JWT_EXPIRE_MINUTES)
