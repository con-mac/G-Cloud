"""
G-Cloud Template API routes
Handles template-based proposal creation
"""

from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field, validator
from typing import List
import re

from app.services.document_generator import document_generator

router = APIRouter()


class ServiceDescriptionRequest(BaseModel):
    """Request model for G-Cloud Service Description"""
    title: str = Field(..., min_length=1, max_length=100, description="Service name")
    description: str = Field(..., min_length=50, max_length=500, description="Service description (50-500 words)")
    features: List[str] = Field(..., min_items=1, max_items=10, description="Service features (max 10)")
    benefits: List[str] = Field(..., min_items=1, max_items=10, description="Service benefits (max 10)")
    
    @validator('title')
    def validate_title(cls, v):
        """Title should be just the service name, no extra keywords"""
        if len(v.split()) > 10:
            raise ValueError('Title should be concise - just the service name')
        return v.strip()
    
    @validator('description')
    def validate_description(cls, v):
        """Validate word count for description"""
        word_count = len(re.findall(r'\b\w+\b', v))
        if word_count < 50:
            raise ValueError(f'Description must be at least 50 words (currently {word_count})')
        if word_count > 500:
            raise ValueError(f'Description must not exceed 500 words (currently {word_count})')
        return v.strip()
    
    @validator('features', 'benefits', each_item=True)
    def validate_list_items(cls, v):
        """Each feature/benefit should be max 10 words"""
        word_count = len(re.findall(r'\b\w+\b', v))
        if word_count > 10:
            raise ValueError(f'Each item must be max 10 words (this item has {word_count})')
        if word_count < 1:
            raise ValueError('Item cannot be empty')
        return v.strip()


class GenerateResponse(BaseModel):
    """Response after generating documents"""
    success: bool
    message: str
    word_filename: str
    pdf_filename: str
    word_path: str
    pdf_path: str


@router.post("/service-description/generate", response_model=GenerateResponse)
async def generate_service_description(request: ServiceDescriptionRequest):
    """
    Generate G-Cloud Service Description documents from template
    
    Creates both Word (.docx) and PDF versions following the official
    G-Cloud v15 template format with PA Consulting branding.
    """
    try:
        result = document_generator.generate_service_description(
            title=request.title,
            description=request.description,
            features=request.features,
            benefits=request.benefits
        )
        
        return GenerateResponse(
            success=True,
            message="Documents generated successfully",
            word_filename=f"{result['filename']}.docx",
            pdf_filename=f"{result['filename']}.pdf",
            word_path=result['word_path'],
            pdf_path=result['pdf_path']
        )
    
    except FileNotFoundError as e:
        raise HTTPException(status_code=500, detail=f"Template not found: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Document generation failed: {str(e)}")


@router.get("/service-description/download/{filename}")
async def download_document(filename: str):
    """Download generated Word or PDF document"""
    import os
    file_path = f"/app/generated_documents/{filename}"
    
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="File not found")
    
    media_type = "application/vnd.openxmlformats-officedocument.wordprocessingml.document" \
        if filename.endswith('.docx') else "application/pdf"
    
    return FileResponse(
        path=file_path,
        media_type=media_type,
        filename=filename
    )


@router.get("/templates")
async def list_templates():
    """List available G-Cloud templates"""
    return {
        "templates": [
            {
                "id": "service-description",
                "name": "G-Cloud Service Description",
                "description": "Official G-Cloud v15 Service Description template with PA Consulting branding",
                "sections": [
                    {"name": "title", "label": "Service Name", "required": True, "editable": True},
                    {"name": "description", "label": "Short Service Description", "required": True, "editable": False},
                    {"name": "features", "label": "Key Service Features", "required": True, "editable": False},
                    {"name": "benefits", "label": "Key Service Benefits", "required": True, "editable": False}
                ],
                "validation": {
                    "title": "Service name only, no extra keywords",
                    "description": "50-500 words",
                    "features": "10 words each, max 10 features",
                    "benefits": "10 words each, max 10 benefits"
                }
            },
            {
                "id": "pricing-document",
                "name": "G-Cloud Pricing Document",
                "description": "Official G-Cloud v15 Pricing Document template",
                "status": "Coming soon"
            }
        ]
    }

