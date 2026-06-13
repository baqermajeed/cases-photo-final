from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer

from ..config import settings
from ..models.user import Photographer
from ..utils.jwt_utils import decode_token


oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/token")


async def get_current_user(token: str = Depends(oauth2_scheme)) -> Photographer:
    user_id = decode_token(token, settings.JWT_SECRET)
    if not user_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    try:
        user = await Photographer.get(user_id)
    except Exception:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token subject")
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    return user
