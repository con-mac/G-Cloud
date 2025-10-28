"""Validation rule model"""

import enum
from sqlalchemy import Column, String, Text, Boolean, Enum as SQLEnum, JSON

from app.models.base import Base
from app.models.section import SectionType


class RuleType(str, enum.Enum):
    """Types of validation rules"""

    WORD_COUNT_MIN = "word_count_min"
    WORD_COUNT_MAX = "word_count_max"
    REQUIRED_FIELD = "required_field"
    DATA_TYPE = "data_type"
    REGEX_PATTERN = "regex_pattern"
    URL_FORMAT = "url_format"
    EMAIL_FORMAT = "email_format"
    PHONE_FORMAT = "phone_format"
    NUMBER_RANGE = "number_range"
    DATE_RANGE = "date_range"
    CUSTOM = "custom"


class Severity(str, enum.Enum):
    """Severity of validation failure"""

    ERROR = "error"  # Prevents submission
    WARNING = "warning"  # Allows submission but warns user


class ValidationRule(Base):
    """Validation rule model for section validation"""

    __tablename__ = "validation_rules"

    # Rule identification
    section_type = Column(SQLEnum(SectionType), nullable=False, index=True)
    rule_type = Column(SQLEnum(RuleType), nullable=False)
    name = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)

    # Rule parameters (stored as JSON)
    parameters = Column(JSON, nullable=True)
    # Examples:
    # - word_count_min: {"min_words": 100}
    # - word_count_max: {"max_words": 500}
    # - regex_pattern: {"pattern": "^[A-Z]", "flags": "i"}
    # - number_range: {"min": 0, "max": 1000000}

    # Error messaging
    error_message = Column(Text, nullable=False)
    severity = Column(SQLEnum(Severity), default=Severity.ERROR, nullable=False)

    # Activation
    is_active = Column(Boolean, default=True, nullable=False)
    framework_version = Column(String(50), nullable=True)  # Specific to framework version

    def __repr__(self) -> str:
        return f"<ValidationRule {self.name} ({self.section_type})>"

