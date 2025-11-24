"""
Main FastAPI application for PA deployment
Uses SharePoint Online instead of Azure Blob Storage
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import os
import logging

from app.api import api_router

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="G-Cloud 15 Automation API (PA Deployment)",
    description="API for G-Cloud proposal automation using SharePoint",
    version="1.0.0"
)

# CORS configuration
# PLACEHOLDER: Update with actual frontend URL
cors_origins = os.environ.get("CORS_ORIGINS", "http://localhost:3000,http://localhost:5173").split(",")

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API routes
app.include_router(api_router, prefix="/api/v1")

@app.get("/")
async def root():
    """Health check endpoint"""
    return {
        "status": "ok",
        "service": "G-Cloud 15 Automation API",
        "deployment": "PA Environment",
        "storage": "SharePoint Online",
        "note": "SharePoint integration is a placeholder - implementation pending"
    }

@app.get("/health")
async def health():
    """Health check endpoint"""
    return {"status": "healthy"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

