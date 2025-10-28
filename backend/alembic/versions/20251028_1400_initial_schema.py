"""Initial schema with all tables

Revision ID: 001_initial
Revises: 
Create Date: 2025-10-28 14:00:00.000000

"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision = '001_initial'
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Create users table
    op.create_table('users',
        sa.Column('id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
        sa.Column('azure_ad_id', sa.String(length=255), nullable=False),
        sa.Column('email', sa.String(length=255), nullable=False),
        sa.Column('full_name', sa.String(length=255), nullable=False),
        sa.Column('role', sa.Enum('viewer', 'editor', 'reviewer', 'admin', name='userrole'), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=False),
        sa.Column('last_login', sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_users_azure_ad_id'), 'users', ['azure_ad_id'], unique=True)
    op.create_index(op.f('ix_users_email'), 'users', ['email'], unique=True)
    op.create_index(op.f('ix_users_id'), 'users', ['id'], unique=False)

    # Create proposals table
    op.create_table('proposals',
        sa.Column('id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
        sa.Column('title', sa.String(length=500), nullable=False),
        sa.Column('framework_version', sa.String(length=50), nullable=False),
        sa.Column('status', sa.Enum('draft', 'in_review', 'ready_for_submission', 'submitted', 'approved', 'rejected', name='proposalstatus'), nullable=False),
        sa.Column('deadline', sa.DateTime(), nullable=True),
        sa.Column('completion_percentage', sa.Float(), nullable=False),
        sa.Column('created_by', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('last_modified_by', postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column('original_document_url', sa.String(length=1000), nullable=True),
        sa.ForeignKeyConstraint(['created_by'], ['users.id'], ),
        sa.ForeignKeyConstraint(['last_modified_by'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_proposals_id'), 'proposals', ['id'], unique=False)

    # Create sections table
    op.create_table('sections',
        sa.Column('id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
        sa.Column('proposal_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('section_type', sa.Enum('service_name', 'service_summary', 'service_features', 'service_benefits', 'pricing', 'pricing_details', 'terms_conditions', 'user_support', 'onboarding', 'offboarding', 'data_management', 'data_security', 'data_backup', 'service_availability', 'identity_authentication', 'audit_logging', 'security_governance', 'vulnerability_management', 'protective_monitoring', 'incident_management', 'custom', name='sectiontype'), nullable=False),
        sa.Column('title', sa.String(length=500), nullable=False),
        sa.Column('order', sa.Integer(), nullable=False),
        sa.Column('content', sa.Text(), nullable=True),
        sa.Column('word_count', sa.Integer(), nullable=False),
        sa.Column('validation_status', sa.Enum('not_started', 'invalid', 'warning', 'valid', name='validationstatus'), nullable=False),
        sa.Column('is_mandatory', sa.Boolean(), nullable=False),
        sa.Column('validation_errors', sa.Text(), nullable=True),
        sa.Column('last_modified_by', postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column('locked_by', postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column('locked_at', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['last_modified_by'], ['users.id'], ),
        sa.ForeignKeyConstraint(['locked_by'], ['users.id'], ),
        sa.ForeignKeyConstraint(['proposal_id'], ['proposals.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_sections_id'), 'sections', ['id'], unique=False)

    # Create validation_rules table
    op.create_table('validation_rules',
        sa.Column('id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
        sa.Column('section_type', sa.Enum('service_name', 'service_summary', 'service_features', 'service_benefits', 'pricing', 'pricing_details', 'terms_conditions', 'user_support', 'onboarding', 'offboarding', 'data_management', 'data_security', 'data_backup', 'service_availability', 'identity_authentication', 'audit_logging', 'security_governance', 'vulnerability_management', 'protective_monitoring', 'incident_management', 'custom', name='sectiontype'), nullable=False),
        sa.Column('rule_type', sa.Enum('word_count_min', 'word_count_max', 'required_field', 'data_type', 'regex_pattern', 'url_format', 'email_format', 'phone_format', 'number_range', 'date_range', 'custom', name='ruletype'), nullable=False),
        sa.Column('name', sa.String(length=255), nullable=False),
        sa.Column('description', sa.Text(), nullable=True),
        sa.Column('parameters', sa.JSON(), nullable=True),
        sa.Column('error_message', sa.Text(), nullable=False),
        sa.Column('severity', sa.Enum('error', 'warning', name='severity'), nullable=False),
        sa.Column('is_active', sa.Boolean(), nullable=False),
        sa.Column('framework_version', sa.String(length=50), nullable=True),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_validation_rules_id'), 'validation_rules', ['id'], unique=False)
    op.create_index(op.f('ix_validation_rules_section_type'), 'validation_rules', ['section_type'], unique=False)

    # Create change_history table
    op.create_table('change_history',
        sa.Column('id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
        sa.Column('section_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('change_type', sa.Enum('create', 'update', 'delete', 'rollback', name='changetype'), nullable=False),
        sa.Column('old_content', sa.Text(), nullable=True),
        sa.Column('new_content', sa.Text(), nullable=True),
        sa.Column('ip_address', sa.String(length=45), nullable=True),
        sa.Column('user_agent', sa.String(length=500), nullable=True),
        sa.Column('comment', sa.Text(), nullable=True),
        sa.ForeignKeyConstraint(['section_id'], ['sections.id'], ),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_change_history_id'), 'change_history', ['id'], unique=False)

    # Create notifications table
    op.create_table('notifications',
        sa.Column('id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('created_at', sa.DateTime(), nullable=False),
        sa.Column('updated_at', sa.DateTime(), nullable=False),
        sa.Column('proposal_id', postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column('user_id', postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column('notification_type', sa.Enum('deadline_30_days', 'deadline_14_days', 'deadline_7_days', 'deadline_3_days', 'deadline_1_day', 'deadline_passed', 'validation_failed', 'proposal_submitted', 'proposal_approved', 'proposal_rejected', 'section_locked', 'section_unlocked', 'comment_added', 'custom', name='notificationtype'), nullable=False),
        sa.Column('title', sa.String(length=255), nullable=False),
        sa.Column('message', sa.Text(), nullable=False),
        sa.Column('sent_at', sa.DateTime(), nullable=True),
        sa.Column('read_at', sa.DateTime(), nullable=True),
        sa.Column('is_sent', sa.Boolean(), nullable=False),
        sa.Column('is_read', sa.Boolean(), nullable=False),
        sa.Column('email_sent', sa.Boolean(), nullable=False),
        sa.Column('email_sent_at', sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(['proposal_id'], ['proposals.id'], ),
        sa.ForeignKeyConstraint(['user_id'], ['users.id'], ),
        sa.PrimaryKeyConstraint('id')
    )
    op.create_index(op.f('ix_notifications_id'), 'notifications', ['id'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_notifications_id'), table_name='notifications')
    op.drop_table('notifications')
    op.drop_index(op.f('ix_change_history_id'), table_name='change_history')
    op.drop_table('change_history')
    op.drop_index(op.f('ix_validation_rules_section_type'), table_name='validation_rules')
    op.drop_index(op.f('ix_validation_rules_id'), table_name='validation_rules')
    op.drop_table('validation_rules')
    op.drop_index(op.f('ix_sections_id'), table_name='sections')
    op.drop_table('sections')
    op.drop_index(op.f('ix_proposals_id'), table_name='proposals')
    op.drop_table('proposals')
    op.drop_index(op.f('ix_users_id'), table_name='users')
    op.drop_index(op.f('ix_users_email'), table_name='users')
    op.drop_index(op.f('ix_users_azure_ad_id'), table_name='users')
    op.drop_table('users')
    
    # Drop enums
    sa.Enum(name='notificationtype').drop(op.get_bind(), checkfirst=True)
    sa.Enum(name='changetype').drop(op.get_bind(), checkfirst=True)
    sa.Enum(name='severity').drop(op.get_bind(), checkfirst=True)
    sa.Enum(name='ruletype').drop(op.get_bind(), checkfirst=True)
    sa.Enum(name='validationstatus').drop(op.get_bind(), checkfirst=True)
    sa.Enum(name='sectiontype').drop(op.get_bind(), checkfirst=True)
    sa.Enum(name='proposalstatus').drop(op.get_bind(), checkfirst=True)
    sa.Enum(name='userrole').drop(op.get_bind(), checkfirst=True)

