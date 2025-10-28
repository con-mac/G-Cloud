"""API routes"""

from fastapi import APIRouter
from app.api.routes import proposals, sections, templates

api_router = APIRouter()

# Include route modules
api_router.include_router(proposals.router, prefix="/proposals", tags=["Proposals"])
api_router.include_router(sections.router, prefix="/sections", tags=["Sections"])
api_router.include_router(templates.router, prefix="/templates", tags=["Templates"])


@api_router.get("/")
async def api_root():
    """API root endpoint"""
    return {
        "message": "G-Cloud Proposal Automation API",
        "version": "1.0.0",
        "endpoints": {
            "docs": "/docs",
            "health": "/health",
            "proposals": "/api/v1/proposals",
            "sections": "/api/v1/sections",
        },
    }

