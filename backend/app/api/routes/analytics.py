"""
Analytics API routes (PA Deployment)
Uses SharePoint for data
PLACEHOLDER: SharePoint integration needs to be completed
"""

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel
from typing import List, Dict, Optional, Any
import logging

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/summary")
async def get_analytics_summary(
    lot: Optional[str] = Query(None),
    gcloud_version: str = Query("15")
):
    """
    Get analytics summary
    PLACEHOLDER: SharePoint integration needs to be completed
    """
    logger.warning("get_analytics_summary: Using placeholder - not implemented")
    
    # PLACEHOLDER: Aggregate data from SharePoint
    return {
        "total_services": 0,
        "services_with_responses": 0,
        "services_without_responses": 0,
        "services_locked": 0,
        "services_draft": 0,
        "lot_breakdown": {},
        "sections": [],
        "note": "Analytics is a placeholder - implementation pending"
    }


@router.get("/services")
async def get_services_status(
    lot: Optional[str] = Query(None),
    gcloud_version: str = Query("15")
):
    """
    Get services status
    PLACEHOLDER: SharePoint integration needs to be completed
    """
    logger.warning("get_services_status: Using placeholder - not implemented")
    
    return {
        "services": [],
        "note": "Services status is a placeholder - implementation pending"
    }

