"""Change history model"""

import enum
from sqlalchemy import Column, String, Text, Enum as SQLEnum, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.models.base import Base


class ChangeType(str, enum.Enum):
    """Type of change made"""

    CREATE = "create"
    UPDATE = "update"
    DELETE = "delete"
    ROLLBACK = "rollback"


class ChangeHistory(Base):
    """Change history model for audit trail"""

    __tablename__ = "change_history"

    # References
    section_id = Column(UUID(as_uuid=True), ForeignKey("sections.id"), nullable=False)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)

    # Change details
    change_type = Column(SQLEnum(ChangeType), nullable=False)
    old_content = Column(Text, nullable=True)
    new_content = Column(Text, nullable=True)
    
    # Metadata
    ip_address = Column(String(45), nullable=True)  # IPv6 max length
    user_agent = Column(String(500), nullable=True)
    comment = Column(Text, nullable=True)

    # Relationships
    section = relationship("Section", back_populates="change_history")
    user = relationship("User", back_populates="change_history")

    def __repr__(self) -> str:
        return f"<ChangeHistory {self.change_type} by {self.user_id}>"

