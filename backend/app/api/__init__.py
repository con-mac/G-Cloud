"""
API router initialization
Includes all API routes for PA deployment
"""

from fastapi import APIRouter

api_router = APIRouter()

# Import and include all route modules
try:
    from app.api.routes import templates
    api_router.include_router(templates.router, prefix="/templates", tags=["Templates"])
except (ImportError, AttributeError, ModuleNotFoundError):
    pass

try:
    from app.api.routes import proposals
    api_router.include_router(proposals.router, prefix="/proposals", tags=["Proposals"])
except (ImportError, AttributeError, ModuleNotFoundError):
    pass

try:
    from app.api.routes import sharepoint
    api_router.include_router(sharepoint.router, prefix="/sharepoint", tags=["SharePoint"])
except (ImportError, AttributeError, ModuleNotFoundError):
    pass

try:
    from app.api.routes import questionnaire
    api_router.include_router(questionnaire.router, prefix="/questionnaire", tags=["Questionnaire"])
except (ImportError, AttributeError, ModuleNotFoundError):
    pass

try:
    from app.api.routes import analytics
    api_router.include_router(analytics.router, prefix="/analytics", tags=["Analytics"])
except (ImportError, AttributeError, ModuleNotFoundError):
    pass

