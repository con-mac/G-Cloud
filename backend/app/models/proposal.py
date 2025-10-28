"""Proposal model"""

import enum
from sqlalchemy import Column, String, Float, DateTime, Enum as SQLEnum, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.models.base import Base


class ProposalStatus(str, enum.Enum):
    """Proposal status enum"""

    DRAFT = "draft"
    IN_REVIEW = "in_review"
    READY_FOR_SUBMISSION = "ready_for_submission"
    SUBMITTED = "submitted"
    APPROVED = "approved"
    REJECTED = "rejected"


class Proposal(Base):
    """Proposal model for G-Cloud proposals"""

    __tablename__ = "proposals"

    # Basic information
    title = Column(String(500), nullable=False)
    framework_version = Column(String(50), nullable=False)  # e.g., "G-Cloud 14"
    status = Column(SQLEnum(ProposalStatus), default=ProposalStatus.DRAFT, nullable=False)
    
    # Deadline and progress
    deadline = Column(DateTime, nullable=True)
    completion_percentage = Column(Float, default=0.0, nullable=False)
    
    # User tracking
    created_by = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)
    last_modified_by = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    
    # Document reference
    original_document_url = Column(String(1000), nullable=True)  # Azure Blob Storage URL
    
    # Relationships
    created_by_user = relationship("User", foreign_keys=[created_by], back_populates="proposals")
    sections = relationship("Section", back_populates="proposal", cascade="all, delete-orphan")
    notifications = relationship("Notification", back_populates="proposal", cascade="all, delete-orphan")

    def __repr__(self) -> str:
        return f"<Proposal {self.title} ({self.status})>"

