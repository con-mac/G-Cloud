"""
G-Cloud Template API routes (PA Deployment)
Uses SharePoint instead of Azure Blob Storage
PLACEHOLDER: SharePoint integration needs to be completed
"""

from fastapi import APIRouter, HTTPException
from fastapi.responses import Response
from pydantic import BaseModel, Field
from typing import List, Optional, Dict
import os
import logging

from app.services.document_generator import DocumentGenerator

logger = logging.getLogger(__name__)

# Initialize document generator
document_generator = DocumentGenerator()

router = APIRouter()


class ServiceDescriptionRequest(BaseModel):
    """Request model for G-Cloud Service Description"""
    title: str = Field(..., min_length=1, max_length=100)
    description: str = Field(..., max_length=2000)
    features: List[str] = Field(..., min_items=0, max_items=10)
    benefits: List[str] = Field(..., min_items=0, max_items=10)
    service_definition: Optional[List[dict]] = Field(default_factory=list)
    update_metadata: Optional[Dict] = None
    new_proposal_metadata: Optional[Dict] = None
    save_as_draft: Optional[bool] = False


@router.post("/service-description/generate")
async def generate_service_description(request: ServiceDescriptionRequest):
    """
    Generate Service Description document
    PLACEHOLDER: SharePoint upload needs to be implemented
    """
    try:
        result = document_generator.generate_service_description(
            title=request.title,
            description=request.description,
            features=request.features,
            benefits=request.benefits,
            service_definition=request.service_definition,
            update_metadata=request.update_metadata,
            save_as_draft=request.save_as_draft,
            new_proposal_metadata=request.new_proposal_metadata
        )
        
        return {
            "success": True,
            "message": "Document generated (SharePoint upload pending)",
            "word_filename": result["word_filename"],
            "word_sharepoint_id": result.get("word_sharepoint_id"),
            "note": "SharePoint integration is a placeholder - implementation pending"
        }
    except Exception as e:
        logger.error(f"Error generating document: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Document generation failed: {str(e)}")


@router.get("/service-description/download/{filename}")
async def download_document(filename: str):
    """
    Download document from SharePoint
    PLACEHOLDER: SharePoint download needs to be implemented
    """
    # PLACEHOLDER: Download from SharePoint using Graph API
    # For now, return error
    raise HTTPException(
        status_code=501,
        detail="SharePoint download not yet implemented. This is a placeholder."
    )

