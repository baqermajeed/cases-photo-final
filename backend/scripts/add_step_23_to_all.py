import asyncio
from beanie import PydanticObjectId
from app.config import settings
from app.database import init_db
from app.models.patient import Patient, Step
from app.services.patient_service import STEP_TITLES


async def add_step_23():
    await init_db(settings.DATABASE_URL)

    title = "صورة المعالجة"
    # fallback to service titles if available/matching
    if len(STEP_TITLES) >= 23:
        title = STEP_TITLES[22]

    updated_count = 0
    patients = await Patient.find_all().to_list()
    for patient in patients:
        has_23 = any(s.step_number == 23 for s in patient.steps)
        if not has_23:
            patient.steps.append(Step(step_number=23, title=title))
            await patient.save()
            updated_count += 1

    print(f"Done. Updated {updated_count} patient(s). Total patients scanned: {len(patients)}")


if __name__ == "__main__":
    asyncio.run(add_step_23())

