from datetime import datetime, timedelta
from typing import Optional

from jose import jwt, JWTError


def create_access_token(subject: str, secret: str, expire_minutes: int) -> str:
    expire = datetime.utcnow() + timedelta(minutes=expire_minutes)
    payload = {"sub": subject, "exp": expire}
    return jwt.encode(payload, secret, algorithm="HS256")


def decode_token(token: str, secret: str) -> Optional[str]:
    try:
        payload = jwt.decode(token, secret, algorithms=["HS256"])
        return payload.get("sub")
    except JWTError:
        return None
