"""
SharePoint API routes for document management.
"""

from fastapi import APIRouter, HTTPException, Query, Response
from pydantic import BaseModel, EmailStr
from typing import List, Optional, Dict
import logging
import os

from sharepoint_service.sharepoint_service import (
    search_documents,
    read_metadata_file,
    get_document_path,
    create_folder,
    create_metadata_file,
    list_all_folders,
    MOCK_BASE_PATH,
    USE_S3,
)
from sharepoint_service.document_parser import read_document_content

logger = logging.getLogger(__name__)

router = APIRouter()


# Request/Response models
class SearchRequest(BaseModel):
    query: str
    doc_type: Optional[str] = None  # "SERVICE DESC" or "Pricing Doc"
    gcloud_version: str = "14"
    search_all_versions: bool = False  # Search both GCloud 14 and 15


class SearchResult(BaseModel):
    service_name: str
    owner: str
    sponsor: str
    folder_path: str
    doc_type: str
    lot: str
    gcloud_version: str


class CreateFolderRequest(BaseModel):
    service_name: str
    lot: str
    gcloud_version: str = "15"


class CreateMetadataRequest(BaseModel):
    service_name: str
    owner: str
    sponsor: str
    lot: str
    gcloud_version: str = "15"
    last_edited_by: Optional[str] = None


class MetadataResponse(BaseModel):
    service: str
    owner: str
    sponsor: str


@router.post("/search", response_model=List[SearchResult])
async def search_sharepoint_documents(request: SearchRequest):
    """
    Search documents in SharePoint (mock).
    
    Args:
        request: Search request with query, optional doc_type filter, and gcloud_version
        
    Returns:
        List of matching documents with metadata
    """
    try:
        results = search_documents(
            query=request.query,
            doc_type=request.doc_type,
            gcloud_version=request.gcloud_version,
            search_all_versions=request.search_all_versions
        )
        return [SearchResult(**r) for r in results]
    except Exception as e:
        logger.error(f"Error searching documents: {e}")
        raise HTTPException(status_code=500, detail=f"Error searching documents: {str(e)}")


@router.get("/metadata/{service_name}", response_model=MetadataResponse)
async def get_metadata(
    service_name: str,
    lot: str = Query(..., description="LOT number (2 or 3)"),
    gcloud_version: str = Query("14", description="GCloud version (14 or 15)"),
    response: Response = None
):
    """
    Get metadata for a service (from .txt file).
    
    Args:
        service_name: Service name
        lot: LOT number (2 or 3)
        gcloud_version: GCloud version (14 or 15)
        
    Returns:
        Metadata (SERVICE, OWNER, SPONSOR)
    """
    try:
        from pathlib import Path
        from sharepoint_service.sharepoint_service import MOCK_BASE_PATH, USE_S3
        
        base_path = MOCK_BASE_PATH / f"GCloud {gcloud_version}" / "PA Services"
        lot_folder = base_path / f"Cloud Support Services LOT {lot}"
        
        # Find service folder (fuzzy match)
        service_folder = None
        if not USE_S3 and MOCK_BASE_PATH:
            lot_folder = MOCK_BASE_PATH / f"GCloud {gcloud_version}" / "PA Services" / f"Cloud Support Services LOT {lot}"
            if lot_folder.exists():
                for folder in lot_folder.iterdir():
                    if folder.is_dir():
                        from sharepoint_service.sharepoint_service import fuzzy_match
                        if fuzzy_match(service_name, folder.name):
                            service_folder = folder
                            break
        else:
            # For S3, get_document_path returns the S3 key directly
            # We'll use get_document_path to find the folder
            from sharepoint_service.sharepoint_service import get_document_path
            doc_path = get_document_path(service_name, "SERVICE DESC", lot, gcloud_version)
            if doc_path:
                # Extract folder path from S3 key
                service_folder = Path(doc_path).parent if isinstance(doc_path, str) else doc_path.parent
        
        if not service_folder:
            raise HTTPException(status_code=404, detail=f"Service folder not found: {service_name}")
        
        metadata = read_metadata_file(service_folder)
        if not metadata:
            raise HTTPException(status_code=404, detail=f"Metadata not found for: {service_name}")
        
        # Set cache-control headers to prevent browser caching
        if response:
            response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
            response.headers["Pragma"] = "no-cache"
            response.headers["Expires"] = "0"
        
        return MetadataResponse(
            service=metadata.get('service', service_name),
            owner=metadata.get('owner', ''),
            sponsor=metadata.get('sponsor', '')
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting metadata: {e}")
        raise HTTPException(status_code=500, detail=f"Error getting metadata: {str(e)}")


@router.get("/document/{service_name}")
async def get_document(
    service_name: str,
    doc_type: str = Query(..., description="Document type (SERVICE DESC or Pricing Doc)"),
    lot: str = Query(..., description="LOT number (2 or 3)"),
    gcloud_version: str = Query("14", description="GCloud version (14 or 15)")
):
    """
    Get document path (for mock, returns path info).
    
    Args:
        service_name: Service name
        doc_type: Document type ("SERVICE DESC" or "Pricing Doc")
        lot: LOT number (2 or 3)
        gcloud_version: GCloud version (14 or 15)
        
    Returns:
        Document path information
    """
    try:
        doc_path = get_document_path(service_name, doc_type, lot, gcloud_version)
        if not doc_path:
            raise HTTPException(
                status_code=404,
                detail=f"Document not found: {service_name} ({doc_type})"
            )
        
        return {
            "service_name": service_name,
            "doc_type": doc_type,
            "lot": lot,
            "gcloud_version": gcloud_version,
            "file_path": str(doc_path),
            "exists": doc_path.exists()
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting document: {e}")
        raise HTTPException(status_code=500, detail=f"Error getting document: {str(e)}")


@router.post("/create-folder")
async def create_service_folder(request: CreateFolderRequest):
    """
    Create folder structure for new proposal and generate Pricing Document.
    
    Args:
        request: Folder creation request
        
    Returns:
        Success status and folder path
    """
    try:
        success, folder_path = create_folder(
            service_name=request.service_name,
            lot=request.lot,
            gcloud_version=request.gcloud_version
        )
        
        if not success:
            raise HTTPException(status_code=500, detail="Failed to create folder")
        
        # Generate Pricing Document at folder creation (as per G-Cloud 15 requirements)
        try:
            from app.services.pricing_document_generator import PricingDocumentGenerator
            from app.services.s3_service import S3Service
            
            # Initialize pricing document generator
            _use_s3 = os.environ.get("USE_S3", "false").lower() == "true"
            if _use_s3:
                s3_service = S3Service()
                pricing_generator = PricingDocumentGenerator(s3_service=s3_service)
            else:
                pricing_generator = PricingDocumentGenerator()
            
            # Prepare metadata for pricing doc generation
            new_proposal_metadata = {
                'service': request.service_name,
                'lot': request.lot,
                'gcloud_version': request.gcloud_version
            }
            
            # Generate pricing document
            pricing_result = pricing_generator.generate_pricing_document(
                service_name=request.service_name,
                gcloud_version=request.gcloud_version,
                lot=request.lot,
                new_proposal_metadata=new_proposal_metadata
            )
            
            logger.info(f"Generated pricing document: {pricing_result.get('word_blob_key') or pricing_result.get('word_path')}")
        except Exception as e:
            # Log error but don't fail folder creation if pricing doc generation fails
            logger.warning(f"Failed to generate pricing document: {e}")
        
        return {
            "success": True,
            "folder_path": folder_path,
            "service_name": request.service_name,
            "lot": request.lot,
            "gcloud_version": request.gcloud_version
        }
    except Exception as e:
        logger.error(f"Error creating folder: {e}")
        raise HTTPException(status_code=500, detail=f"Error creating folder: {str(e)}")


@router.post("/create-metadata")
async def create_metadata(request: CreateMetadataRequest):
    """
    Create metadata .txt file with exact format.
    
    Args:
        request: Metadata creation request
        
    Returns:
        Success status
    """
    try:
        # Get folder path
        success, folder_path = create_folder(
            service_name=request.service_name,
            lot=request.lot,
            gcloud_version=request.gcloud_version
        )
        
        if not success:
            raise HTTPException(status_code=500, detail="Failed to create folder")
        
        # Create metadata file
        success = create_metadata_file(
            folder_path=folder_path,
            service=request.service_name,
            owner=request.owner,
            sponsor=request.sponsor,
            last_edited_by=request.last_edited_by
        )
        
        if not success:
            raise HTTPException(status_code=500, detail="Failed to create metadata file")
        
        return {
            "success": True,
            "folder_path": folder_path,
            "service_name": request.service_name,
            "owner": request.owner,
            "sponsor": request.sponsor
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error creating metadata: {e}")
        raise HTTPException(status_code=500, detail=f"Error creating metadata: {str(e)}")


@router.get("/list-folders")
async def list_folders(gcloud_version: str = Query("14", description="GCloud version (14 or 15)")):
    """
    List all service folders in SharePoint (mock).
    
    Args:
        gcloud_version: GCloud version (14 or 15)
        
    Returns:
        List of folders with metadata
    """
    try:
        folders = list_all_folders(gcloud_version=gcloud_version)
        return [SearchResult(**f) for f in folders]
    except Exception as e:
        logger.error(f"Error listing folders: {e}")
        raise HTTPException(status_code=500, detail=f"Error listing folders: {str(e)}")


class DocumentContentResponse(BaseModel):
    title: str
    description: str
    features: List[str]
    benefits: List[str]
    service_definition: List[Dict[str, str]]


@router.get("/document-content/{service_name}", response_model=DocumentContentResponse)
async def get_document_content(
    service_name: str,
    doc_type: str = Query(..., description="Document type (SERVICE DESC or Pricing Doc)"),
    lot: str = Query(..., description="LOT number (2 or 3)"),
    gcloud_version: str = Query("14", description="GCloud version (14 or 15)"),
    response: Response = None
):
    """
    Get parsed content from an existing document.
    
    Args:
        service_name: Service name
        doc_type: Document type ("SERVICE DESC" or "Pricing Doc")
        lot: LOT number (2 or 3)
        gcloud_version: GCloud version (14 or 15)
        
    Returns:
        Parsed document content
    """
    try:
        content = read_document_content(service_name, doc_type, lot, gcloud_version)
        
        if not content:
            raise HTTPException(
                status_code=404,
                detail=f"Document not found or could not be parsed: {service_name} ({doc_type})"
            )
        
        # Set cache-control headers to prevent browser caching
        if response:
            response.headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
            response.headers["Pragma"] = "no-cache"
            response.headers["Expires"] = "0"
        
        return DocumentContentResponse(**content)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error getting document content: {e}")
        raise HTTPException(status_code=500, detail=f"Error getting document content: {str(e)}")

