"""API routes"""

import os
from fastapi import APIRouter

# Lazy imports for Lambda compatibility (templates doesn't need database)
# Only import templates router - proposals/sections need database and will fail
# Check if we're in Lambda environment (USE_S3 is set)
_use_s3 = os.environ.get("USE_S3", "false").lower() == "true"

# Always import templates (needed for document generation)
from app.api.routes import templates

# Import SharePoint routes (mock service, no database needed)
try:
    from app.api.routes import sharepoint
except (ImportError, AttributeError, ModuleNotFoundError):
    sharepoint = None

# Import proposals router (uses SharePoint service, not database)
# Proposals router works with both local and S3 storage
try:
    from app.api.routes import proposals
except (ImportError, AttributeError, ModuleNotFoundError):
    proposals = None

# Import questionnaire router (uses file storage, not database)
try:
    from app.api.routes import questionnaire
except (ImportError, AttributeError, ModuleNotFoundError):
    questionnaire = None

# Import analytics router (uses file storage, not database)
try:
    from app.api.routes import analytics
except (ImportError, AttributeError, ModuleNotFoundError):
    analytics = None

# Only import database-dependent routes if not in Lambda
if not _use_s3:
    try:
        from app.api.routes import sections
    except (ImportError, AttributeError, ModuleNotFoundError):
        sections = None
else:
    # In Lambda, don't import database-dependent routes
    sections = None

api_router = APIRouter()

# Include route modules (only templates is needed for document generation)
if templates:
    api_router.include_router(templates.router, prefix="/templates", tags=["Templates"])
if sharepoint:
    api_router.include_router(sharepoint.router, prefix="/sharepoint", tags=["SharePoint"])
if proposals:
    api_router.include_router(proposals.router, prefix="/proposals", tags=["Proposals"])
if questionnaire:
    api_router.include_router(questionnaire.router, prefix="/questionnaire", tags=["Questionnaire"])
if analytics:
    api_router.include_router(analytics.router, prefix="/analytics", tags=["Analytics"])
if sections:
    api_router.include_router(sections.router, prefix="/sections", tags=["Sections"])


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

