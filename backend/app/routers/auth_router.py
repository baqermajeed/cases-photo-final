from fastapi import APIRouter, HTTPException, status, Depends
from fastapi.security import OAuth2PasswordRequestForm

from ..schemas.user_schema import LoginRequest
from ..services.auth_service import authenticate_user, issue_access_token
from ..utils.security import get_current_user
from ..models.user import Photographer

router = APIRouter()


@router.post("/login")
async def login(payload: LoginRequest):
    user = await authenticate_user(payload.username, payload.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password",
        )
    token = await issue_access_token(user)
    return {
        "success": True,
        "access_token": token,
        "token_type": "bearer",
        "user": {
            "id": str(user.id),
            "full_name": user.full_name,
            "username": user.username,
            "role": user.role,
            "created_at": user.created_at,
        },
    }


@router.post("/token")
async def token(form: OAuth2PasswordRequestForm = Depends()):
    user = await authenticate_user(form.username, form.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password",
        )
    token = await issue_access_token(user)
    return {"access_token": token, "token_type": "bearer"}


@router.get("/me")
async def me(current_user: Photographer = Depends(get_current_user)):
    return {
        "success": True,
        "user": {
            "id": str(current_user.id),
            "full_name": current_user.full_name,
            "username": current_user.username,
            "role": current_user.role,
            "created_at": current_user.created_at,
        },
    }
