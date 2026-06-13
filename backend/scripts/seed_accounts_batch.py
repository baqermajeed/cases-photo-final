import asyncio
import os
import sys

# Ensure project root is on PYTHONPATH
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.database import init_db
from app.config import settings
from app.models.user import Photographer
from app.services.auth_service import get_password_hash

USERS = [
    {"full_name": "Ahmed - Manager", "username": "ahmed", "password": "ahmed121", "role": "admin"},
    {"full_name": "Ali - Manager", "username": "ali", "password": "ali121", "role": "admin"},
    {"full_name": "Mou", "username": "mou", "password": "mou123", "role": "photographer"},
    {"full_name": "Mon", "username": "mon", "password": "mon123", "role": "photographer"},
    {"full_name": "Mus", "username": "mus", "password": "mus123", "role": "photographer"},
]


async def seed_users():
    await init_db(settings.DATABASE_URL)
    for u in USERS:
        existing = await Photographer.find_one(Photographer.username == u["username"])
        if existing:
            print(f"User '{u['username']}' already exists - skipping")
            continue
        user = Photographer(
            full_name=u["full_name"],
            username=u["username"],
            password=get_password_hash(u["password"]),
            role=u["role"],
        )
        await user.insert()
        print(f"Created user: {u['username']} (role={u['role']})")


if __name__ == "__main__":
    asyncio.run(seed_users())
