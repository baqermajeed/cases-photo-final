from datetime import datetime, timezone
from typing import List, Optional
from fastapi import HTTPException

from ..models.patient import Patient, Step, Image
from ..schemas.patient_schema import PatientCreate

ACTIVE_PATIENT_FILTER = {
    "$or": [
        {"is_deleted": False},
        {"is_deleted": {"$exists": False}},
    ]
}


STEP_TITLES: List[str] = [
    "صورة وجه كامل للمريض",
    "صورة ابتسامة المريض بدون وجه",
    "صورة ابتسامة مع ريتراكتد",
    "صورة ابتسامة مع ريتراكتد يمين",
    "صورة ابتسامة مع ريتراكتد يسار",
    "صورة اللهاة العلوية",
    "صورة اللهاة السفلية",
    "صورة الأشعة قبل الزراعة",
    "مكان الزراعة قبل الشق",
    "مكان الزراعة بعد الشق",
    "وضع الدرل",
    "الزرعة داخل الفم",
    "صورة الخيط",
    "الأشعة بعد الزراعة",
    "صورة الطبعة",
    "التركيب على القالب",
    "التركيب داخل الفم ابتسامة",
    "التركيب داخل الفم يمين",
    "التركيب داخل الفم يسار",
    "اللهاة العلوية",
    "اللهاة السفلية",
    "صورة وجه كامل",
    "صورة اشعة سنسر pa و اشعة التركيب",  # step 23 (after operation)
    "صورة المعالجة",  # step 24 (treatment)
    "صورة Emergency profile",  # step 25 (after operation - new)
]


def generate_default_steps() -> List[Step]:
    steps: List[Step] = []
    for i, title in enumerate(STEP_TITLES, start=1):
        steps.append(Step(step_number=i, title=title))
    return steps


def _touch_patient(patient: Patient) -> None:
    patient.updated_at = datetime.utcnow()


def _touch_step(step: Step) -> None:
    step.updated_at = datetime.utcnow()


def _normalize_datetime(value: datetime) -> datetime:
    if value.tzinfo:
        return value.astimezone(timezone.utc).replace(tzinfo=None)
    return value


async def create_patient(data: PatientCreate) -> Patient:
    patient = Patient(
        name=data.name,
        phone=data.phone,
        address=data.address,
        note=data.note,
        steps=generate_default_steps(),
    )
    _touch_patient(patient)
    await patient.insert()
    return patient


async def list_patients() -> List[Patient]:
    return await Patient.find(ACTIVE_PATIENT_FILTER).to_list()


def _phase_steps(phase: int) -> List[int]:
    if phase == 1:
        return [1, 2, 3, 4, 5, 6, 7, 8]
    if phase == 2:
        return [9, 10, 11, 12, 13, 14]
    if phase == 3:
        # treatment
        return [24]
    if phase == 4:
        # after operation (includes newly added 25)
        return [15, 16, 17, 18, 19, 20, 21, 22, 23, 25]
    raise HTTPException(status_code=400, detail="Invalid phase")


def _is_phase_completed(patient: Patient, phase: int) -> bool:
    required = set(_phase_steps(phase))
    step_map = {s.step_number: s for s in patient.steps}
    # All required steps must exist and be done
    for sn in required:
        step = step_map.get(sn)
        if step is None or not step.is_done:
            return False
    return True


def _has_zero_steps_done(patient: Patient) -> bool:
    return not any(s.is_done for s in patient.steps)


async def search_patients(q: Optional[str], page: int, limit: int) -> dict:
    skip = (page - 1) * limit
    if q:
        filter_query = {
            "$and": [
                {
                    "$or": [
                        {"name": {"$regex": q, "$options": "i"}},
                        {"phone": {"$regex": q, "$options": "i"}},
                    ]
                },
                ACTIVE_PATIENT_FILTER,
            ]
        }
        cursor = Patient.find(filter_query).sort([("registration_date", -1)])
        total = await Patient.find(filter_query).count()
    else:
        filter_query = ACTIVE_PATIENT_FILTER
        cursor = Patient.find(filter_query).sort([("registration_date", -1)])
        total = await Patient.find(filter_query).count()

    patients = await cursor.skip(skip).limit(limit).to_list()

    pages = (total + limit - 1) // limit if total else 0
    return {
        "data": patients,
        "pagination": {
            "total": total,
            "page": page,
            "limit": limit,
            "pages": pages,
        },
        "query": q,
    }


async def get_patient(patient_id: str) -> Patient:
    patient = await Patient.get(patient_id)
    if not patient or patient.is_deleted:
        raise HTTPException(status_code=404, detail="Patient not found")
    return patient


async def update_patient(patient_id: str, name: str, phone: str, address: str, note: Optional[str] = None) -> Patient:
    """تحديث بيانات المريض الأساسية"""
    patient = await get_patient(patient_id)
    patient.name = name
    patient.phone = phone
    patient.address = address
    if note is not None:
        patient.note = note
    _touch_patient(patient)
    await patient.save()
    return patient


def get_step(patient: Patient, step_number: int) -> Step:
    for step in patient.steps:
        if step.step_number == step_number:
            return step
    raise HTTPException(status_code=404, detail="Step not found")


async def mark_step_done(patient_id: str, step_number: int, is_done: bool = True) -> Patient:
    patient = await get_patient(patient_id)
    step = get_step(patient, step_number)
    step.is_done = is_done
    _touch_step(step)
    _touch_patient(patient)
    await patient.save()
    return patient


async def add_images_to_step(patient_id: str, step_number: int, images: List[Image]) -> Patient:
    patient = await get_patient(patient_id)
    step = get_step(patient, step_number)
    existing_urls = {img.url for img in step.images}
    for image in images:
        if image.url not in existing_urls:
            step.images.append(image)
            existing_urls.add(image.url)
    _touch_step(step)
    _touch_patient(patient)
    await patient.save()
    return patient


async def delete_image_from_step(patient_id: str, step_number: int, image_id: str) -> Patient:
    patient = await get_patient(patient_id)
    step = get_step(patient, step_number)
    before = len(step.images)
    step.images = [img for img in step.images if img.id != image_id]
    if len(step.images) == before:
        raise HTTPException(status_code=404, detail="Image not found")
    _touch_step(step)
    _touch_patient(patient)
    await patient.save()
    return patient


async def get_statistics() -> dict:
    """جلب إحصائيات المرضى"""
    all_patients = await Patient.find(ACTIVE_PATIENT_FILTER).to_list()
    total = len(all_patients)

    completed_total = 0
    incomplete_total = 0
    zero_step_total = 0

    # Phase completion counters
    phase_completed = {1: 0, 2: 0, 3: 0, 4: 0}

    for patient in all_patients:
        all_steps_done = all(step.is_done for step in patient.steps)
        if all_steps_done:
            completed_total += 1
        else:
            incomplete_total += 1

        if _has_zero_steps_done(patient):
            zero_step_total += 1

        for phase in (1, 2, 3, 4):
            if _is_phase_completed(patient, phase):
                phase_completed[phase] += 1

    completion_rate = (completed_total / total * 100) if total > 0 else 0.0

    return {
        "total_patients": total,
        "completed_patients": completed_total,
        "incomplete_patients": incomplete_total,
        "zero_step_patients": zero_step_total,
        "phase_completed": phase_completed,
        "completion_rate": round(completion_rate, 1),
    }


async def get_completed_patients() -> List[Patient]:
    """جلب فقط المرضى المكتملين"""
    all_patients = await Patient.find(ACTIVE_PATIENT_FILTER).to_list()
    completed_patients = []
    
    for patient in all_patients:
        if all(step.is_done for step in patient.steps):
            completed_patients.append(patient)
    
    return completed_patients


async def get_incomplete_patients() -> List[Patient]:
    """جلب المرضى غير المكتملين"""
    all_patients = await Patient.find(ACTIVE_PATIENT_FILTER).to_list()
    return [p for p in all_patients if not all(step.is_done for step in p.steps)]


async def delete_patient(patient_id: str) -> None:
    """حذف مريض"""
    patient = await get_patient(patient_id)
    if patient.is_deleted:
        return
    patient.is_deleted = True
    _touch_patient(patient)
    await patient.save()


# ========== Phase/Zero-step filters ==========

async def get_patients_completed_phase(phase: int) -> List[Patient]:
    """جلب المرضى الذين أتمّوا المرحلة المحددة (كل خطوات المرحلة مكتملة)"""
    all_patients = await Patient.find(ACTIVE_PATIENT_FILTER).to_list()
    result: List[Patient] = []
    for patient in all_patients:
        if _is_phase_completed(patient, phase):
            result.append(patient)
    return result


async def get_zero_step_patients() -> List[Patient]:
    """المرضى الذين لم يكملوا أي خطوة"""
    all_patients = await Patient.find(ACTIVE_PATIENT_FILTER).to_list()
    return [p for p in all_patients if _has_zero_steps_done(p)]


async def get_patients_updates(since: datetime) -> List[Patient]:
    normalized = _normalize_datetime(since)
    query = {"updated_at": {"$gt": normalized}}
    return await Patient.find(query).to_list()
