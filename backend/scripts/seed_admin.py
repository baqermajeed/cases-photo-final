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
    existing = await Photographer.find_one(Photographer.username == "admin")
    if existing:
        print("Admin user already exists")
        return
    u = Photographer(full_name="Admin", username="admin", password=get_password_hash("admin123"))
    await u.insert()
    print("Seeded admin user: username=admin, password=admin123")


if __name__ == "__main__":
    asyncio.run(main())
