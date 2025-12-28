"""API v1 Router - Aggregates all module routers."""

from fastapi import APIRouter

from app.api.v1.dhg.routes import router as dhg_router
from app.api.v1.enrollment.routes import router as enrollment_router
from app.api.v1.financials.routes import router as financials_router
from app.api.v1.workforce.routes import router as workforce_router

api_router = APIRouter()

# Include module routers
api_router.include_router(enrollment_router, prefix="/enrollment", tags=["Enrollment"])
api_router.include_router(workforce_router, prefix="/workforce", tags=["Workforce"])
api_router.include_router(dhg_router, prefix="/dhg", tags=["DHG"])
api_router.include_router(financials_router, prefix="/financials", tags=["Financials"])
