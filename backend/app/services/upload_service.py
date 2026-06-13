from typing import List
import asyncio
from fastapi import UploadFile, HTTPException

from ..utils.cloudflare_utils import upload_file_to_r2
from ..config import settings


def _validate_file_bytes(filename: str, content_type: str | None, data: bytes):
    if content_type not in settings.ALLOWED_CONTENT_TYPES:
        raise HTTPException(status_code=400, detail=f"Unsupported content type: {content_type}")
    max_bytes = settings.MAX_UPLOAD_MB * 1024 * 1024
    if len(data) > max_bytes:
        raise HTTPException(status_code=400, detail=f"File too large. Max {settings.MAX_UPLOAD_MB} MB")


async def _read_and_validate(f: UploadFile) -> tuple[UploadFile, bytes]:
    try:
        data = await f.read()
    finally:
        await f.seek(0)
    _validate_file_bytes(f.filename or "file", f.content_type, data)
    return f, data


async def upload_images(
    files: List[UploadFile], 
    endpoint: str,
    patient_name: str = None,
    step_title: str = None
) -> List[str]:
    # Read + validate concurrently
    read_results = await asyncio.gather(*(_read_and_validate(f) for f in files))

    # To avoid re-reading, but our uploader expects UploadFile; we can just post original file again
    # Since we validated size/type above, proceed to concurrent uploads
    urls = await asyncio.gather(*(
        upload_file_to_r2(f, endpoint, patient_name, step_title) 
        for f, _ in read_results
    ))
    return list(urls)
