from fastapi import APIRouter
from motor.motor_asyncio import AsyncIOMotorClient

from ..config import settings

router = APIRouter()


@router.get("/health")
async def health():
    # Quick DB ping
    ok = True
    try:
        client = AsyncIOMotorClient(settings.DATABASE_URL)
        await client.admin.command("ping")
    except Exception:
        ok = False
    finally:
        try:
            client.close()
        except Exception:
            pass
    return {"ok": ok}
