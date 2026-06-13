import httpx
import re
import hashlib
from fastapi import UploadFile, HTTPException


def sanitize_arabic_filename(text: str) -> str:
    """تنظيف النص ليكون ملائم لاسم ملف"""
    # إزالة الحركات العربية
    text = re.sub(r'[ً-ٟ]', '', text)
    # استبدال الفراغات بشرطة سفلية
    text = text.replace(' ', '_')
    # إزالة الرموز غير المسموح بها (الإبقاء على العربي والإنجليزي والأرقام و_)
    text = re.sub(r'[^\w\u0600-\u06FF_-]', '', text)
    # إزالة الشرطات السفلية المتعددة
    text = re.sub(r'_+', '_', text)
    # إزالة الشرطات من البداية والنهاية
    text = text.strip('_')
    return text


async def upload_file_to_r2(
    file: UploadFile, 
    endpoint: str, 
    patient_name: str = None, 
    step_title: str = None
) -> str:
    """رفع ملف إلى R2 مع اسم ملف يحتوي على اسم المريض والخطوة"""
    try:
        content = await file.read()
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Failed to read file: {str(e)}")

    if not content:
        raise HTTPException(status_code=400, detail="Empty file content")

    orig_name = file.filename or "upload"
    # استخراج الامتداد
    ext = ""
    if "." in orig_name:
        ext = "." + orig_name.split(".")[-1]
    elif (file.content_type or "").startswith("image/"):
        ext = "." + (file.content_type or "image/jpeg").split("/")[-1]
    
    # إنشاء اسم الملف
    if patient_name and step_title:
        # تنظيف النصوص
        clean_patient = sanitize_arabic_filename(patient_name)
        clean_step = sanitize_arabic_filename(step_title)
        # اسم ثابت يعتمد على بصمة المحتوى لمنع تكرار الملفات عند إعادة المحاولة
        content_hash = hashlib.sha256(content).hexdigest()[:12]
        filename = f"{clean_patient}_{clean_step}_{content_hash}{ext}"
    else:
        # فولباك للطريقة القديمة
        content_hash = hashlib.sha256(content).hexdigest()[:16]
        filename = f"{content_hash}{ext}"
    
    content_type = file.content_type or "application/octet-stream"

    async with httpx.AsyncClient(timeout=60) as client:
        # Worker expects a single field named 'file'
        files = {"file": (filename, content, content_type)}
        resp = await client.post(endpoint, files=files)

    if resp.status_code >= 400:
        raise HTTPException(status_code=resp.status_code, detail=f"R2 upload failed: {resp.text}")

    url = None
    # Try parse JSON
    try:
        data = resp.json()
        if isinstance(data, dict):
            url = data.get("url") or data.get("publicUrl") or data.get("Location")
            if not url:
                nested = data.get("result") or data.get("data")
                if isinstance(nested, dict):
                    url = nested.get("url") or nested.get("publicUrl")
    except Exception:
        text = resp.text.strip()
        if text.startswith("http"):
            url = text

    if not url:
        raise HTTPException(status_code=502, detail="Upload succeeded but URL not found in response")

    return url
