"""API routes"""

from fastapi import APIRouter

# Import routers (will be created in subsequent steps)
# from app.api.routes import proposals, sections, users, auth, validation

api_router = APIRouter()

# Include route modules
# api_router.include_router(auth.router, prefix="/auth", tags=["Authentication"])
# api_router.include_router(proposals.router, prefix="/proposals", tags=["Proposals"])
# api_router.include_router(sections.router, prefix="/sections", tags=["Sections"])
# api_router.include_router(users.router, prefix="/users", tags=["Users"])
# api_router.include_router(validation.router, prefix="/validation", tags=["Validation"])


@api_router.get("/")
async def api_root():
    """API root endpoint"""
    return {
        "message": "G-Cloud Proposal Automation API",
        "version": "1.0.0",
        "endpoints": {
            "docs": "/docs",
            "health": "/health",
        },
    }

