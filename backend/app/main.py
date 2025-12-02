"""Main FastAPI application entry point"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.responses import JSONResponse

from app.core.config import settings
from app.core.logging import setup_logging

# Setup logging first
setup_logging()
import logging
logger = logging.getLogger(__name__)

# Import API router with error handling
try:
    from app.api import api_router
    logger.info("API router imported successfully")
    logger.info(f"API router has {len(api_router.routes)} routes")
except Exception as e:
    logger.error(f"Failed to import API router: {e}", exc_info=True)
    # Create empty router as fallback
    from fastapi import APIRouter
    api_router = APIRouter()
    api_router.get("/")(lambda: {"error": "API router failed to load", "detail": str(e)})

# Create FastAPI application
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="G-Cloud Proposal Automation System API",
    docs_url="/docs" if settings.DEBUG else None,
    redoc_url="/redoc" if settings.DEBUG else None,
    openapi_url="/openapi.json" if settings.DEBUG else None,
)

# Add middleware
app.add_middleware(GZipMiddleware, minimum_size=1000)
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/", tags=["Health"])
async def root():
    """Root endpoint - health check"""
    return {
        "status": "healthy",
        "app": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "environment": settings.ENVIRONMENT,
    }


@app.get("/health", tags=["Health"])
async def health_check():
    """Detailed health check endpoint"""
    return JSONResponse(
        status_code=200,
        content={
            "status": "healthy",
            "checks": {
                "api": "ok",
                # TODO: Add database, redis, and other service checks
            },
        },
    )


# Include API router
try:
    app.include_router(api_router, prefix="/api/v1")
    logger.info("API router included successfully with prefix /api/v1")
except Exception as e:
    logger.error(f"Failed to include API router: {e}", exc_info=True)


@app.on_event("startup")
async def startup_event():
    """Application startup event"""
    print(f"Starting {settings.APP_NAME} v{settings.APP_VERSION}")
    print(f"Environment: {settings.ENVIRONMENT}")
    print(f"Debug mode: {settings.DEBUG}")
    # TODO: Initialize database connection pool
    # TODO: Initialize Redis connection
    # TODO: Initialize Azure services


@app.on_event("shutdown")
async def shutdown_event():
    """Application shutdown event"""
    print(f"Shutting down {settings.APP_NAME}")
    # TODO: Close database connections
    # TODO: Close Redis connections
    # TODO: Cleanup resources

