from datetime import datetime
from fastapi import APIRouter, status, Depends, Query, HTTPException, Path
from typing import Optional

from ..schemas.patient_schema import PatientCreate, PatientUpdate
from ..services import patient_service
from ..utils.security import get_current_user
from ..models.user import Photographer

router = APIRouter(dependencies=[Depends(get_current_user)])


@router.post("", status_code=status.HTTP_201_CREATED)
async def create_patient(payload: PatientCreate):
    patient = await patient_service.create_patient(payload)
    return {"success": True, "data": patient}


@router.get("")
async def list_patients(q: Optional[str] = Query(default=None), page: int = Query(1, ge=1), limit: int = Query(20, ge=1, le=100)):
    result = await patient_service.search_patients(q=q, page=page, limit=limit)
    return {"success": True, **result}


# هذه الـ routes لازم تكون قبل /{patient_id}
@router.get("/stats/dashboard")
async def get_stats():
    stats = await patient_service.get_statistics()
    return {"success": True, "data": stats}


@router.get("/filter/completed")
async def get_completed_patients():
    patients = await patient_service.get_completed_patients()
    return {"success": True, "data": patients}


@router.get("/filter/completed/phase/{phase}")
async def get_completed_by_phase(phase: int = Path(..., ge=1, le=4)):
    patients = await patient_service.get_patients_completed_phase(phase)
    return {"success": True, "data": patients}


@router.get("/filter/zero-step")
async def get_zero_step_patients():
    patients = await patient_service.get_zero_step_patients()
    return {"success": True, "data": patients}


@router.get("/updates")
async def get_patient_updates(since: datetime = Query(..., description="ISO datetime in UTC")):
    patients = await patient_service.get_patients_updates(since)
    return {"success": True, "data": patients}


@router.get("/{patient_id}")
async def get_patient(patient_id: str):
    patient = await patient_service.get_patient(patient_id)
    return {"success": True, "data": patient}


@router.patch("/{patient_id}")
async def update_patient_basic_info(patient_id: str, payload: PatientUpdate):
    updated = await patient_service.update_patient(
        patient_id=patient_id,
        name=payload.name,
        phone=payload.phone,
        address=payload.address,
        note=payload.note,
    )
    return {"success": True, "data": updated}


@router.delete("/{patient_id}")
async def delete_patient(patient_id: str, current_user: Photographer = Depends(get_current_user)):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    await patient_service.delete_patient(patient_id)
    return {"success": True, "message": "Patient deleted successfully"}
