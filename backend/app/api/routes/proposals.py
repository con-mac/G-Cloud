"""Proposals API routes"""

from fastapi import APIRouter, HTTPException, Header
from typing import List, Optional
from pydantic import BaseModel

from app.services.database import db_service

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


@router.get("/", response_model=List[dict])
async def get_all_proposals():
    """Get all proposals"""
    try:
        proposals = db_service.get_all_proposals()
        return proposals
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


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

