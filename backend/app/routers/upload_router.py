from fastapi import APIRouter, UploadFile, File, HTTPException, Depends
from typing import List

from ..services import patient_service
from ..services.upload_service import upload_images
from ..models.patient import Image
from ..config import settings
from ..schemas.patient_schema import StepDoneRequest
from ..utils.security import get_current_user
from ..models.user import Photographer

router = APIRouter(dependencies=[Depends(get_current_user)])


@router.post("/patients/{patient_id}/steps/{step_number}/upload")
async def upload_step_images(patient_id: str, step_number: int, files: List[UploadFile] = File(...), current_user: Photographer = Depends(get_current_user)):
    if not files:
        raise HTTPException(status_code=400, detail="No files provided")
    
    # جلب بيانات المريض للحصول على الاسم وعنوان الخطوة
    patient = await patient_service.get_patient(patient_id)
    step = patient_service.get_step(patient, step_number)
    
    # رفع الصور مع المعلومات
    urls = await upload_images(
        files, 
        str(settings.R2_ENDPOINT),
        patient_name=patient.name,
        step_title=step.title
    )
    
    images = [Image(url=url, uploaded_by_username=current_user.username) for url in urls]
    patient = await patient_service.add_images_to_step(patient_id, step_number, images)
    # تعليم الخطوة كمكتملة تلقائياً بعد رفع الصور
    patient = await patient_service.mark_step_done(patient_id, step_number, True)
    step = patient_service.get_step(patient, step_number)
    return {
        "success": True,
        "message": f"Uploaded {len(images)} image(s)",
        "data": step,
    }


@router.patch("/patients/{patient_id}/steps/{step_number}/done")
async def mark_step_done(patient_id: str, step_number: int, payload: StepDoneRequest = StepDoneRequest()):
    is_done = True if payload is None or payload.is_done is None else payload.is_done
    patient = await patient_service.mark_step_done(patient_id, step_number, is_done)
    step = patient_service.get_step(patient, step_number)
    return {"success": True, "data": {"step_number": step.step_number, "is_done": step.is_done}}


@router.delete("/patients/{patient_id}/steps/{step_number}/images/{image_id}")
async def delete_image(patient_id: str, step_number: int, image_id: str, current_user: Photographer = Depends(get_current_user)):
    if current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    patient = await patient_service.delete_image_from_step(patient_id, step_number, image_id)
    step = patient_service.get_step(patient, step_number)
    return {
        "success": True,
        "message": "Image deleted",
        "data": {"step_number": step.step_number, "images": step.images},
    }
