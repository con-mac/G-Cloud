"""
Questionnaire API routes (PA Deployment)
Uses SharePoint for storage
PLACEHOLDER: SharePoint integration needs to be completed
"""

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel
from typing import List, Dict, Optional, Any
import logging
import json

# PLACEHOLDER: Import SharePoint service
# from sharepoint_service.sharepoint_online import (
#     upload_file_to_sharepoint,
#     download_file_from_sharepoint,
#     file_exists_in_sharepoint,
# )

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/questions/{lot}")
async def get_questions(
    lot: str,
    gcloud_version: str = Query("15"),
    service_name: Optional[str] = Query(None)
):
    """
    Get questionnaire questions for a LOT
    PLACEHOLDER: Questionnaire parser needs to be copied and adapted
    """
    logger.warning("get_questions: Using placeholder - not implemented")
    
    # PLACEHOLDER: Parse Excel and return questions
    return {
        "sections": [],
        "note": "Questionnaire parser needs to be copied from main repo"
    }


@router.post("/responses")
async def save_responses(
    service_name: str,
    lot: str,
    gcloud_version: str,
    answers: List[Dict[str, Any]],
    is_draft: bool = True
):
    """
    Save questionnaire responses to SharePoint
    PLACEHOLDER: SharePoint upload needs to be implemented
    """
    logger.warning("save_responses: Using placeholder - not implemented")
    
    # PLACEHOLDER: Save to SharePoint
    return {
        "success": True,
        "message": "Response saving is a placeholder - implementation pending"
    }


@router.get("/responses")
async def get_responses(
    service_name: str,
    lot: str,
    gcloud_version: str
):
    """
    Get saved questionnaire responses from SharePoint
    PLACEHOLDER: SharePoint download needs to be implemented
    """
    logger.warning("get_responses: Using placeholder - not implemented")
    
    # PLACEHOLDER: Download from SharePoint
    return {
        "answers": [],
        "note": "SharePoint download is a placeholder - implementation pending"
    }

