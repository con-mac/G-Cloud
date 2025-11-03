"""
G-Cloud Template API routes
Handles template-based proposal creation
"""

from fastapi import APIRouter, HTTPException, UploadFile, File
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field, validator
from typing import List, Optional, Literal
import os
import uuid
import re

from app.services.document_generator import DocumentGenerator
from app.services.s3_service import S3Service

# Initialize services based on environment
_use_s3 = os.environ.get("USE_S3", "false").lower() == "true"
if _use_s3:
    s3_service = S3Service()
    document_generator = DocumentGenerator(s3_service=s3_service)
else:
    document_generator = DocumentGenerator()

router = APIRouter()


class ServiceDescriptionRequest(BaseModel):
    """Request model for G-Cloud Service Description"""
    title: str = Field(..., min_length=1, max_length=100, description="Service name")
    description: str = Field(..., max_length=2000, description="Service description (max 50 words)")
    features: List[str] = Field(..., min_items=1, max_items=10, description="Service features (max 10)")
    benefits: List[str] = Field(..., min_items=1, max_items=10, description="Service benefits (max 10)")
    # New: service definition subsections (no constraints)
    # Each block: { subtitle: str, content: str(HTML), images?: [url], table?: [][] }
    service_definition: Optional[List[dict]] = Field(default_factory=list, description="Service Definition subsections (rich HTML content)")
    
    @validator('title')
    def validate_title(cls, v):
        """Title should be just the service name, no extra keywords"""
        if len(v.split()) > 10:
            raise ValueError('Title should be concise - just the service name')
        return v.strip()
    
    @validator('description')
    def validate_description(cls, v):
        """Validate word count for description - maximum 50 words"""
        word_count = len(re.findall(r'\b\w+\b', v))
        if word_count > 50:
            raise ValueError(f'Description must not exceed 50 words (currently {word_count})')
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
            benefits=request.benefits,
            service_definition=request.service_definition or []
        )
        
        # Handle PDF path - may be None in Lambda if PDF generation not implemented
        pdf_path = result.get('pdf_path') or result.get('pdf_s3_key', '')
        if pdf_path and not pdf_path.startswith('http'):
            # Convert S3 key to presigned URL if needed
            if _use_s3 and s3_service:
                try:
                    pdf_path = s3_service.get_presigned_url(pdf_path, expiration=3600)
                except:
                    pass
        
        return GenerateResponse(
            success=True,
            message="Documents generated successfully",
            word_filename=f"{result['filename']}.docx",
            pdf_filename=f"{result['filename']}.pdf",
            word_path=result['word_path'],
            pdf_path=pdf_path or f"{result.get('filename', 'document')}.pdf"  # Fallback to filename if no path
        )
    
    except FileNotFoundError as e:
        raise HTTPException(status_code=500, detail=f"Template not found: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Document generation failed: {str(e)}")


@router.get("/service-description/download/{filename}")
async def download_document(filename: str):
    """Download generated Word or PDF document"""
    if _use_s3 and s3_service:
        # AWS Lambda: generate presigned URL for S3 file
        s3_key = f"generated/{filename}"
        try:
            presigned_url = s3_service.get_presigned_url(s3_key, expiration=3600)
            from fastapi.responses import RedirectResponse
            return RedirectResponse(url=presigned_url)
        except Exception as e:
            raise HTTPException(status_code=404, detail=f"File not found in S3: {str(e)}")
    else:
        # Docker/local: serve from filesystem
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


@router.get("/")
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
                    {"name": "benefits", "label": "Key Service Benefits", "required": True, "editable": False},
                    {"name": "service_definition", "label": "Service Definition", "required": False, "editable": True}
                ],
                "validation": {
                    "title": "Service name only, no extra keywords",
                    "description": "max 50 words",
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


@router.post("/upload")
async def upload_file(file: UploadFile = File(...)):
    """Upload a file for embedding/linking in Service Definition content.

    Returns a URL that can be used in the editor. Images will be detected by content type.
    """
    content = await file.read()
    unique = str(uuid.uuid4())[:8]
    filename = f"{unique}_{file.filename}"
    is_image = (file.content_type or "").startswith("image/")
    
    if _use_s3 and s3_service:
        # AWS Lambda: upload to S3
        s3_key = f"uploads/{filename}"
        try:
            s3_service.upload_file(content, s3_key, file.content_type or "application/octet-stream")
            # Return presigned URL
            url = s3_service.get_presigned_url(s3_key, expiration=86400)  # 24 hours
            return {"url": url, "filename": file.filename, "content_type": file.content_type, "is_image": is_image}
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Upload to S3 failed: {e}")
    else:
        # Docker/local: save to filesystem
        uploads_dir = "/app/uploads"
        os.makedirs(uploads_dir, exist_ok=True)
        dest_path = os.path.join(uploads_dir, filename)
        try:
            with open(dest_path, "wb") as f:
                f.write(content)
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Upload failed: {e}")

        url = f"/api/v1/templates/upload/{filename}"
        return {"url": url, "filename": file.filename, "content_type": file.content_type, "is_image": is_image}


@router.get("/upload/{filename}")
async def serve_upload(filename: str):
    """Serve uploaded file (only for Docker/local, S3 uses presigned URLs)"""
    if _use_s3 and s3_service:
        # AWS Lambda: generate presigned URL
        s3_key = f"uploads/{filename}"
        try:
            presigned_url = s3_service.get_presigned_url(s3_key, expiration=3600)
            from fastapi.responses import RedirectResponse
            return RedirectResponse(url=presigned_url)
        except Exception as e:
            raise HTTPException(status_code=404, detail=f"File not found in S3: {str(e)}")
    else:
        # Docker/local: serve from filesystem
        uploads_dir = "/app/uploads"
        file_path = os.path.join(uploads_dir, filename)
        if not os.path.exists(file_path):
            raise HTTPException(status_code=404, detail="File not found")
        return FileResponse(path=file_path, filename=filename)

