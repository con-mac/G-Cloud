"""
Proposals API routes (PA Deployment)
Uses SharePoint instead of Azure Blob Storage
PLACEHOLDER: SharePoint integration needs to be completed
"""

from fastapi import APIRouter, HTTPException, Query
from typing import List, Optional
import logging

# PLACEHOLDER: Import SharePoint service
# from sharepoint_service.sharepoint_online import (
#     list_all_folders,
#     get_document_path,
#     read_metadata_file,
# )

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/")
async def get_proposals_by_owner(owner_email: str = Query(...)):
    """
    Get all proposals for an owner
    PLACEHOLDER: SharePoint integration needs to be completed
    """
    logger.warning("get_proposals_by_owner: Using placeholder - not implemented")
    
    # PLACEHOLDER: Get proposals from SharePoint
    # folders = list_all_folders(gcloud_version="15")
    # Filter by owner and check for documents
    
    return {
        "proposals": [],
        "note": "SharePoint integration is a placeholder - implementation pending"
    }


@router.get("/admin/all")
async def get_all_proposals_admin():
    """
    Get all proposals (admin endpoint)
    PLACEHOLDER: SharePoint integration needs to be completed
    """
    logger.warning("get_all_proposals_admin: Using placeholder - not implemented")
    
    # PLACEHOLDER: Get all proposals from SharePoint
    return {
        "proposals": [],
        "note": "SharePoint integration is a placeholder - implementation pending"
    }

