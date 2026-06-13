import asyncio
from typing import Tuple

from app.config import settings
from app.database import init_db
from app.models.patient import Patient, Step


NEW_STEP_23_TITLE = "صورة اشعة سنسر pa و اشعة التركيب"
TREATMENT_TITLE = "صورة المعالجة"


async def migrate_patient_steps(patient: Patient) -> Tuple[bool, str]:
    """
    - إن وجدنا الخطوة 23 وكانت بعنوان 'صورة المعالجة' ننقلها إلى 24 ونتأكد أن عنوانها يبقى 'صورة المعالجة'.
    - نتأكد من وجود خطوة 23 بعنوان 'صورة اشعة سنسر pa و اشعة التركيب'، وإن لم توجد نضيفها.
    """
    changed = False

    # ابحث عن الخطوتين 23 و 24
    step23 = next((s for s in patient.steps if s.step_number == 23), None)
    step24 = next((s for s in patient.steps if s.step_number == 24), None)

    # لو الخطوة 23 حالياً هي "صورة المعالجة" أو أي عنوان آخر غير العنوان الجديد، انقلها إلى 24 كـ "صورة المعالجة"
    if step23 and (step23.title == TREATMENT_TITLE or step23.title != NEW_STEP_23_TITLE):
        if not step24:
            step23.step_number = 24
            step23.title = TREATMENT_TITLE
            changed = True
        else:
            # إن كان هناك خطوة 24 بالفعل، فقط غيّر عنوان 24 إن لزم
            if step24.title != TREATMENT_TITLE:
                step24.title = TREATMENT_TITLE
                changed = True

    # تأكد من وجود خطوة 23 بالعنوان الجديد
    has_new_23 = any(s.step_number == 23 and s.title == NEW_STEP_23_TITLE for s in patient.steps)
    if not has_new_23:
        patient.steps.append(Step(step_number=23, title=NEW_STEP_23_TITLE))
        changed = True

    # ترتيب الخطوات بحسب الرقم
    if changed:
        patient.steps.sort(key=lambda s: s.step_number)
        await patient.save()
        return True, f"Updated patient {patient.id}"

    return False, f"No change for patient {patient.id}"


async def run_migration():
    await init_db(settings.DATABASE_URL)
    patients = await Patient.find_all().to_list()
    updated = 0
    for p in patients:
        did_change, _ = await migrate_patient_steps(p)
        if did_change:
            updated += 1
    print(f"Finished. Updated {updated} of {len(patients)} patients.")


if __name__ == "__main__":
    asyncio.run(run_migration())


