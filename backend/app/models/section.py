"""Section model"""

import enum
from sqlalchemy import Column, String, Text, Integer, Boolean, Enum as SQLEnum, ForeignKey, DateTime
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from app.models.base import Base


class SectionType(str, enum.Enum):
    """G-Cloud section types"""

    SERVICE_NAME = "service_name"
    SERVICE_SUMMARY = "service_summary"
    SERVICE_FEATURES = "service_features"
    SERVICE_BENEFITS = "service_benefits"
    PRICING = "pricing"
    PRICING_DETAILS = "pricing_details"
    TERMS_CONDITIONS = "terms_conditions"
    USER_SUPPORT = "user_support"
    ONBOARDING = "onboarding"
    OFFBOARDING = "offboarding"
    DATA_MANAGEMENT = "data_management"
    DATA_SECURITY = "data_security"
    DATA_BACKUP = "data_backup"
    SERVICE_AVAILABILITY = "service_availability"
    IDENTITY_AUTHENTICATION = "identity_authentication"
    AUDIT_LOGGING = "audit_logging"
    SECURITY_GOVERNANCE = "security_governance"
    VULNERABILITY_MANAGEMENT = "vulnerability_management"
    PROTECTIVE_MONITORING = "protective_monitoring"
    INCIDENT_MANAGEMENT = "incident_management"
    CUSTOM = "custom"


class ValidationStatus(str, enum.Enum):
    """Validation status for sections"""

    NOT_STARTED = "not_started"
    INVALID = "invalid"
    WARNING = "warning"
    VALID = "valid"


class Section(Base):
    """Section model for proposal sections"""

    __tablename__ = "sections"

    # Section identification
    proposal_id = Column(UUID(as_uuid=True), ForeignKey("proposals.id"), nullable=False)
    section_type = Column(SQLEnum(SectionType), nullable=False)
    title = Column(String(500), nullable=False)
    order = Column(Integer, nullable=False)  # Display order within proposal

    # Content
    content = Column(Text, nullable=True)
    word_count = Column(Integer, default=0, nullable=False)

    # Validation
    validation_status = Column(
        SQLEnum(ValidationStatus), default=ValidationStatus.NOT_STARTED, nullable=False
    )
    is_mandatory = Column(Boolean, default=False, nullable=False)
    validation_errors = Column(Text, nullable=True)  # JSON string of errors

    # Metadata
    last_modified_by = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    locked_by = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    locked_at = Column(DateTime, nullable=True)

    # Relationships
    proposal = relationship("Proposal", back_populates="sections")
    change_history = relationship("ChangeHistory", back_populates="section", cascade="all, delete-orphan")
    validation_rules = relationship(
        "ValidationRule",
        primaryjoin="Section.section_type == ValidationRule.section_type",
        foreign_keys="ValidationRule.section_type",
        viewonly=True,
    )

    def __repr__(self) -> str:
        return f"<Section {self.title} ({self.section_type})>"

