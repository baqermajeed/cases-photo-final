from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import settings
from .database import init_db
from .routers.auth_router import router as auth_router
from .routers.patient_router import router as patient_router
from .routers.upload_router import router as upload_router
from .routers.health_router import router as health_router
from .routers.metrics_router import router as metrics_router

app = FastAPI(title="FarahDent Clinic Backend", version="1.0.0")

# CORS for Flutter or any client
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
async def on_startup():
    await init_db(settings.DATABASE_URL)


@app.get("/")
async def root():
    return {"service": "FarahDent Backend", "version": "1.0.0"}


# Routers
app.include_router(health_router, tags=["health"])  # /health
app.include_router(auth_router, prefix="/auth", tags=["auth"])
app.include_router(patient_router, prefix="/patients", tags=["patients"])
app.include_router(upload_router, tags=["uploads"])
app.include_router(metrics_router, tags=["metrics"])  # /metrics
