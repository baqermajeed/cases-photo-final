from fastapi import APIRouter, Depends

from ..utils.security import get_current_user
from ..models.patient import Patient

router = APIRouter(dependencies=[Depends(get_current_user)])


@router.get("/metrics")
async def metrics():
    patients = await Patient.find_all().to_list()
    total_patients = len(patients)
    total_steps = sum(len(p.steps) for p in patients)
    done_steps = sum(sum(1 for s in p.steps if s.is_done) for p in patients)

    return {
        "success": True,
        "data": {
            "patients": {"total": total_patients},
            "steps": {"total": total_steps, "done": done_steps},
        },
    }
