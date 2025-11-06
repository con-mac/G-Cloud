"""Proposals API routes"""

from fastapi import APIRouter, HTTPException, Header, Query
from typing import List, Optional
from pydantic import BaseModel
from pathlib import Path
from datetime import datetime
import os
import shutil

# Lazy import for Lambda compatibility
try:
    from app.services.database import db_service
except ImportError:
    db_service = None

# Import SharePoint mock service
try:
    from sharepoint_service.mock_sharepoint import MOCK_BASE_PATH, read_metadata_file, get_document_path
except ImportError:
    MOCK_BASE_PATH = None
    read_metadata_file = None
    get_document_path = None

router = APIRouter()


class ProposalResponse(BaseModel):
    """Proposal response model"""
    id: str
    title: str
    framework_version: str
    status: str
    deadline: Optional[str] = None
    completion_percentage: float
    created_at: str
    updated_at: str
    created_by_name: str
    section_count: int
    valid_sections: int


class SectionResponse(BaseModel):
    """Section response model"""
    id: str
    section_type: str
    title: str
    order: int
    content: Optional[str] = None
    word_count: int
    validation_status: str
    is_mandatory: bool
    validation_errors: Optional[str] = None


class ProposalDetailResponse(BaseModel):
    """Proposal detail with sections"""
    id: str
    title: str
    framework_version: str
    status: str
    deadline: Optional[str] = None
    completion_percentage: float
    created_at: str
    updated_at: str
    created_by_name: str
    sections: List[dict]


def extract_name_from_email(email: str) -> str:
    """
    Extract name from email: Firstname.Lastname@paconsulting.com → "Firstname Lastname"
    
    Args:
        email: Email address in format Firstname.Lastname@paconsulting.com
        
    Returns:
        Name in format "Firstname Lastname"
    """
    if not email or '@' not in email:
        return ''
    
    # Remove @paconsulting.com part
    local_part = email.split('@')[0]
    
    # Replace . with space
    name = local_part.replace('.', ' ')
    
    # Capitalize first letter of each word
    name = ' '.join(word.capitalize() for word in name.split())
    
    return name


def get_proposals_by_owner(owner_name: str) -> List[dict]:
    """
    Get all proposals where OWNER matches the given owner name.
    
    Args:
        owner_name: Owner name to match (e.g., "Firstname Lastname")
        
    Returns:
        List of proposals with metadata
    """
    proposals = []
    
    if not MOCK_BASE_PATH or not MOCK_BASE_PATH.exists():
        return proposals
    
    # Iterate through all GCloud versions
    for gcloud_dir in sorted(MOCK_BASE_PATH.glob("GCloud *")):
        if not gcloud_dir.is_dir():
            continue
        
        gcloud_version = gcloud_dir.name.replace("GCloud ", "")
        
        pa_services = gcloud_dir / "PA Services"
        if not pa_services.exists():
            continue
        
        # Check both LOT 2 and LOT 3
        for lot_num in ["2", "3"]:
            lot_folder = pa_services / f"Cloud Support Services LOT {lot_num}"
            if not lot_folder.exists() or not lot_folder.is_dir():
                continue
            
            # Check each service folder
            for service_dir in lot_folder.iterdir():
                if not service_dir.is_dir():
                    continue
                
                # Read metadata file
                if read_metadata_file:
                    metadata = read_metadata_file(service_dir)
                    if not metadata:
                        continue
                    
                    # Match owner name (case-insensitive)
                    folder_owner = metadata.get('owner', '').strip()
                    if folder_owner.lower() != owner_name.lower():
                        continue
                    
                    service_name = metadata.get('service', service_dir.name)
                    
                    # Check if both SERVICE DESC and Pricing Doc exist
                    service_desc_exists = False
                    pricing_doc_exists = False
                    last_update = None
                    
                    if get_document_path:
                        # Check SERVICE DESC
                        service_desc_path = get_document_path(service_name, "SERVICE DESC", lot_num, gcloud_version)
                        if service_desc_path and service_desc_path.exists():
                            service_desc_exists = True
                            mtime = service_desc_path.stat().st_mtime
                            if last_update is None or mtime > last_update:
                                last_update = mtime
                        
                        # Check Pricing Doc
                        pricing_doc_path = get_document_path(service_name, "Pricing Doc", lot_num, gcloud_version)
                        if pricing_doc_path and pricing_doc_path.exists():
                            pricing_doc_exists = True
                            mtime = pricing_doc_path.stat().st_mtime
                            if last_update is None or mtime > last_update:
                                last_update = mtime
                    
                    # Determine status
                    if service_desc_exists and pricing_doc_exists:
                        status = "complete"
                        completion_percentage = 100.0
                    elif service_desc_exists or pricing_doc_exists:
                        status = "incomplete"
                        completion_percentage = 50.0
                    else:
                        status = "draft"
                        completion_percentage = 0.0
                    
                    # Format last update
                    last_update_str = None
                    if last_update:
                        last_update_str = datetime.fromtimestamp(last_update).isoformat()
                    
                    # Create proposal ID from service name and gcloud version
                    proposal_id = f"{service_name}_{gcloud_version}_{lot_num}".replace(" ", "_").lower()
                    
                    proposals.append({
                        "id": proposal_id,
                        "title": service_name,
                        "framework_version": f"G-Cloud {gcloud_version}",
                        "gcloud_version": gcloud_version,
                        "lot": lot_num,
                        "status": status,
                        "completion_percentage": completion_percentage,
                        "section_count": 2,  # SERVICE DESC and Pricing Doc
                        "valid_sections": 2 if status == "complete" else 1 if status == "incomplete" else 0,
                        "created_at": last_update_str or datetime.now().isoformat(),
                        "updated_at": last_update_str or datetime.now().isoformat(),
                        "last_update": last_update_str,
                        "service_desc_exists": service_desc_exists,
                        "pricing_doc_exists": pricing_doc_exists,
                        "owner": folder_owner,
                        "sponsor": metadata.get('sponsor', ''),
                    })
    
    # Sort by last update (most recent first)
    proposals.sort(key=lambda x: x.get("last_update") or "", reverse=True)
    
    return proposals


@router.get("/", response_model=List[dict])
async def get_all_proposals(owner_email: Optional[str] = Query(None, description="Owner email to filter proposals")):
    """
    Get all proposals filtered by owner email.
    
    If owner_email is provided, extracts name from email and filters proposals by owner.
    Otherwise, returns empty list (for now, we require owner_email for security).
    
    Args:
        owner_email: Email address in format Firstname.Lastname@paconsulting.com
        
    Returns:
        List of proposals matching the owner
    """
    try:
        # If no owner_email provided, return empty list (we require it for security)
        if not owner_email:
            return []
        
        # Extract owner name from email
        owner_name = extract_name_from_email(owner_email)
        
        if not owner_name:
            return []
        
        # Get proposals from mock_sharepoint
        proposals = get_proposals_by_owner(owner_name)
        
        return proposals
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error getting proposals: {str(e)}")


@router.get("/{proposal_id}", response_model=dict)
async def get_proposal(proposal_id: str):
    """Get proposal by ID with all sections"""
    try:
        proposal = db_service.get_proposal_by_id(proposal_id)
        if not proposal:
            raise HTTPException(status_code=404, detail="Proposal not found")
        return proposal
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/admin/all")
async def get_all_proposals_admin():
    """
    Get all proposals (admin endpoint - no owner filtering).
    
    Returns:
        List of all proposals across all owners
    """
    try:
        if not MOCK_BASE_PATH or not MOCK_BASE_PATH.exists():
            return []
        
        proposals = []
        
        # Iterate through all GCloud versions
        for gcloud_dir in sorted(MOCK_BASE_PATH.glob("GCloud *")):
            if not gcloud_dir.is_dir():
                continue
            
            gcloud_version = gcloud_dir.name.replace("GCloud ", "")
            
            pa_services = gcloud_dir / "PA Services"
            if not pa_services.exists():
                continue
            
            # Check both LOT 2 and LOT 3
            for lot_num in ["2", "3"]:
                lot_folder = pa_services / f"Cloud Support Services LOT {lot_num}"
                if not lot_folder.exists() or not lot_folder.is_dir():
                    continue
                
                # Check each service folder
                for service_dir in lot_folder.iterdir():
                    if not service_dir.is_dir():
                        continue
                    
                    # Read metadata file
                    if read_metadata_file:
                        metadata = read_metadata_file(service_dir)
                        if not metadata:
                            continue
                        
                        service_name = metadata.get('service', service_dir.name)
                        folder_owner = metadata.get('owner', '').strip()
                        
                        # Check if both SERVICE DESC and Pricing Doc exist
                        service_desc_exists = False
                        pricing_doc_exists = False
                        last_update = None
                        
                        if get_document_path:
                            # Check SERVICE DESC
                            service_desc_path = get_document_path(service_name, "SERVICE DESC", lot_num, gcloud_version)
                            if service_desc_path and service_desc_path.exists():
                                service_desc_exists = True
                                mtime = service_desc_path.stat().st_mtime
                                if last_update is None or mtime > last_update:
                                    last_update = mtime
                            
                            # Check Pricing Doc
                            pricing_doc_path = get_document_path(service_name, "Pricing Doc", lot_num, gcloud_version)
                            if pricing_doc_path and pricing_doc_path.exists():
                                pricing_doc_exists = True
                                mtime = pricing_doc_path.stat().st_mtime
                                if last_update is None or mtime > last_update:
                                    last_update = mtime
                        
                        # Determine status
                        if service_desc_exists and pricing_doc_exists:
                            status = "complete"
                            completion_percentage = 100.0
                        elif service_desc_exists or pricing_doc_exists:
                            status = "incomplete"
                            completion_percentage = 50.0
                        else:
                            status = "draft"
                            completion_percentage = 0.0
                        
                        # Format last update
                        last_update_str = None
                        if last_update:
                            last_update_str = datetime.fromtimestamp(last_update).isoformat()
                        
                        # Create proposal ID from service name and gcloud version
                        proposal_id = f"{service_name}_{gcloud_version}_{lot_num}".replace(" ", "_").lower()
                        
                        proposals.append({
                            "id": proposal_id,
                            "title": service_name,
                            "framework_version": f"G-Cloud {gcloud_version}",
                            "gcloud_version": gcloud_version,
                            "lot": lot_num,
                            "status": status,
                            "completion_percentage": completion_percentage,
                            "section_count": 2,
                            "valid_sections": 2 if status == "complete" else 1 if status == "incomplete" else 0,
                            "created_at": last_update_str or datetime.now().isoformat(),
                            "updated_at": last_update_str or datetime.now().isoformat(),
                            "last_update": last_update_str,
                            "service_desc_exists": service_desc_exists,
                            "pricing_doc_exists": pricing_doc_exists,
                            "owner": folder_owner,
                            "sponsor": metadata.get('sponsor', ''),
                        })
        
        # Sort by last update (most recent first)
        proposals.sort(key=lambda x: x.get("last_update") or "", reverse=True)
        
        return proposals
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error getting all proposals: {str(e)}")


@router.delete("/{service_name}")
async def delete_proposal(
    service_name: str,
    lot: str = Query(..., description="LOT number (2 or 3)"),
    gcloud_version: str = Query(..., description="G-Cloud version (14 or 15)")
):
    """
    Delete a proposal folder and all its contents.
    
    Args:
        service_name: Name of the service (URL encoded)
        lot: LOT number (2 or 3)
        gcloud_version: G-Cloud version (14 or 15)
        
    Returns:
        Success message
    """
    try:
        if not MOCK_BASE_PATH or not MOCK_BASE_PATH.exists():
            raise HTTPException(status_code=404, detail="SharePoint mock path not found")
        
        # Decode service name
        from urllib.parse import unquote
        service_name = unquote(service_name)
        
        # Construct folder path
        folder_path = (
            MOCK_BASE_PATH 
            / f"GCloud {gcloud_version}" 
            / "PA Services" 
            / f"Cloud Support Services LOT {lot}" 
            / service_name
        )
        
        # Check if folder exists
        if not folder_path.exists() or not folder_path.is_dir():
            raise HTTPException(status_code=404, detail=f"Proposal folder not found: {service_name}")
        
        # Delete the entire folder and all its contents
        shutil.rmtree(folder_path)
        
        return {"message": f"Proposal '{service_name}' deleted successfully"}
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error deleting proposal: {str(e)}")

