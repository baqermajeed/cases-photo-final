import asyncio
from app.config import settings
from app.database import init_db
from app.models.patient import Patient, Step


async def add_step_25():
    await init_db(settings.DATABASE_URL)

    title = "صورة Emergency profile"
    updated = 0
    patients = await Patient.find_all().to_list()

    for p in patients:
        has_25 = any(s.step_number == 25 for s in p.steps)
        if not has_25:
            p.steps.append(Step(step_number=25, title=title))
            # ترتيب بحسب الرقم
            p.steps.sort(key=lambda s: s.step_number)
            await p.save()
            updated += 1

    print(f"Done. Added step 25 to {updated}/{len(patients)} patients.")


if __name__ == "__main__":
    asyncio.run(add_step_25())


