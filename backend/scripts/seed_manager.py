import asyncio
import os
import sys

# Ensure project root is on PYTHONPATH
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.database import init_db
from app.config import settings
from app.models.user import Photographer
from app.services.auth_service import get_password_hash


async def main():
    await init_db(settings.DATABASE_URL)
    
    # Create admin photographer account (original)
    existing_admin = await Photographer.find_one(Photographer.username == "admin")
    if not existing_admin:
        u = Photographer(
            full_name="Admin", 
            username="admin", 
            password=get_password_hash("admin123"),
            role="photographer"
        )
        await u.insert()
        print("Seeded photographer: username=admin, password=admin123")
    else:
        print("Photographer admin already exists")
    
    # Create manager account
    existing_manager = await Photographer.find_one(Photographer.username == "baqer")
    if not existing_manager:
        m = Photographer(
            full_name="Baqer - Manager", 
            username="baqer", 
            password=get_password_hash("baqer121"),
            role="admin"
        )
        await m.insert()
        print("Seeded manager: username=baqer, password=baqer121")
    else:
        print("Manager baqer already exists")


if __name__ == "__main__":
    asyncio.run(main())
