from pydantic import BaseModel
from typing import Optional


class PatientCreate(BaseModel):
    name: str
    phone: str
    address: str
    note: Optional[str] = None


class PatientUpdate(BaseModel):
    name: str
    phone: str
    address: str
    note: Optional[str] = None


class StepDoneRequest(BaseModel):
    is_done: Optional[bool] = True
