"""User model"""

from sqlalchemy import Boolean, Column, String, DateTime, Enum as SQLEnum
from sqlalchemy.orm import relationship
import enum

from app.models.base import Base


class UserRole(str, enum.Enum):
    """User roles for RBAC"""

    VIEWER = "viewer"
    EDITOR = "editor"
    REVIEWER = "reviewer"
    ADMIN = "admin"


class User(Base):
    """User model for authentication and authorization"""

    __tablename__ = "users"

    # Azure AD integration
    azure_ad_id = Column(String(255), unique=True, index=True, nullable=False)
    email = Column(String(255), unique=True, index=True, nullable=False)

    # User information
    full_name = Column(String(255), nullable=False)
    role = Column(SQLEnum(UserRole), default=UserRole.EDITOR, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    last_login = Column(DateTime, nullable=True)

    # Relationships
    proposals = relationship("Proposal", back_populates="created_by_user", foreign_keys="Proposal.created_by")
    change_history = relationship("ChangeHistory", back_populates="user")
    notifications = relationship("Notification", back_populates="user")

    def __repr__(self) -> str:
        return f"<User {self.email} ({self.role})>"

