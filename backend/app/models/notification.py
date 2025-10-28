"""Notification model"""

import enum
from sqlalchemy import Column, String, Text, Boolean, DateTime, Enum as SQLEnum, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.models.base import Base


class NotificationType(str, enum.Enum):
    """Types of notifications"""

    DEADLINE_30_DAYS = "deadline_30_days"
    DEADLINE_14_DAYS = "deadline_14_days"
    DEADLINE_7_DAYS = "deadline_7_days"
    DEADLINE_3_DAYS = "deadline_3_days"
    DEADLINE_1_DAY = "deadline_1_day"
    DEADLINE_PASSED = "deadline_passed"
    VALIDATION_FAILED = "validation_failed"
    PROPOSAL_SUBMITTED = "proposal_submitted"
    PROPOSAL_APPROVED = "proposal_approved"
    PROPOSAL_REJECTED = "proposal_rejected"
    SECTION_LOCKED = "section_locked"
    SECTION_UNLOCKED = "section_unlocked"
    COMMENT_ADDED = "comment_added"
    CUSTOM = "custom"


class Notification(Base):
    """Notification model for user alerts"""

    __tablename__ = "notifications"

    # References
    proposal_id = Column(UUID(as_uuid=True), ForeignKey("proposals.id"), nullable=True)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)

    # Notification details
    notification_type = Column(SQLEnum(NotificationType), nullable=False)
    title = Column(String(255), nullable=False)
    message = Column(Text, nullable=False)

    # Delivery
    sent_at = Column(DateTime, nullable=True)
    read_at = Column(DateTime, nullable=True)
    is_sent = Column(Boolean, default=False, nullable=False)
    is_read = Column(Boolean, default=False, nullable=False)

    # Email specific
    email_sent = Column(Boolean, default=False, nullable=False)
    email_sent_at = Column(DateTime, nullable=True)

    # Relationships
    proposal = relationship("Proposal", back_populates="notifications")
    user = relationship("User", back_populates="notifications")

    def __repr__(self) -> str:
        return f"<Notification {self.notification_type} to {self.user_id}>"

