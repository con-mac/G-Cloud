"""Initialize database with SQL directly"""

import psycopg2
import os

# Get database URL from environment
db_url = os.getenv('DATABASE_URL', 'postgresql://postgres:postgres@postgres:5432/gcloud_db')

# Parse the URL
# Format: postgresql+asyncpg://user:pass@host:port/database
db_url = db_url.replace('postgresql+asyncpg://', 'postgresql://')

print(f"Connecting to database...")
try:
    conn = psycopg2.connect(db_url)
    cur = conn.cursor()
    
    print("Creating tables...")
    
    # Create ENUMS
    cur.execute("""
        DO $$ BEGIN
            CREATE TYPE userrole AS ENUM ('viewer', 'editor', 'reviewer', 'admin');
        EXCEPTION
            WHEN duplicate_object THEN null;
        END $$;
        
        DO $$ BEGIN
            CREATE TYPE proposalstatus AS ENUM ('draft', 'in_review', 'ready_for_submission', 'submitted', 'approved', 'rejected');
        EXCEPTION
            WHEN duplicate_object THEN null;
        END $$;
        
        DO $$ BEGIN
            CREATE TYPE sectiontype AS ENUM ('service_name', 'service_summary', 'service_features', 'service_benefits', 'pricing', 'pricing_details', 'terms_conditions', 'user_support', 'onboarding', 'offboarding', 'data_management', 'data_security', 'data_backup', 'service_availability', 'identity_authentication', 'audit_logging', 'security_governance', 'vulnerability_management', 'protective_monitoring', 'incident_management', 'custom');
        EXCEPTION
            WHEN duplicate_object THEN null;
        END $$;
        
        DO $$ BEGIN
            CREATE TYPE validationstatus AS ENUM ('not_started', 'invalid', 'warning', 'valid');
        EXCEPTION
            WHEN duplicate_object THEN null;
        END $$;
        
        DO $$ BEGIN
            CREATE TYPE ruletype AS ENUM ('word_count_min', 'word_count_max', 'required_field', 'data_type', 'regex_pattern', 'url_format', 'email_format', 'phone_format', 'number_range', 'date_range', 'custom');
        EXCEPTION
            WHEN duplicate_object THEN null;
        END $$;
        
        DO $$ BEGIN
            CREATE TYPE severity AS ENUM ('error', 'warning');
        EXCEPTION
            WHEN duplicate_object THEN null;
        END $$;
        
        DO $$ BEGIN
            CREATE TYPE changetype AS ENUM ('create', 'update', 'delete', 'rollback');
        EXCEPTION
            WHEN duplicate_object THEN null;
        END $$;
        
        DO $$ BEGIN
            CREATE TYPE notificationtype AS ENUM ('deadline_30_days', 'deadline_14_days', 'deadline_7_days', 'deadline_3_days', 'deadline_1_day', 'deadline_passed', 'validation_failed', 'proposal_submitted', 'proposal_approved', 'proposal_rejected', 'section_locked', 'section_unlocked', 'comment_added', 'custom');
        EXCEPTION
            WHEN duplicate_object THEN null;
        END $$;
    """)
    
    # Create tables
    cur.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            azure_ad_id VARCHAR(255) UNIQUE NOT NULL,
            email VARCHAR(255) UNIQUE NOT NULL,
            full_name VARCHAR(255) NOT NULL,
            role userrole NOT NULL DEFAULT 'editor',
            is_active BOOLEAN NOT NULL DEFAULT TRUE,
            last_login TIMESTAMP
        );
        
        CREATE INDEX IF NOT EXISTS ix_users_id ON users (id);
        CREATE INDEX IF NOT EXISTS ix_users_email ON users (email);
        CREATE INDEX IF NOT EXISTS ix_users_azure_ad_id ON users (azure_ad_id);
    """)
    
    cur.execute("""
        CREATE TABLE IF NOT EXISTS proposals (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            title VARCHAR(500) NOT NULL,
            framework_version VARCHAR(50) NOT NULL,
            status proposalstatus NOT NULL DEFAULT 'draft',
            deadline TIMESTAMP,
            completion_percentage FLOAT NOT NULL DEFAULT 0.0,
            created_by UUID NOT NULL REFERENCES users(id),
            last_modified_by UUID REFERENCES users(id),
            original_document_url VARCHAR(1000)
        );
        
        CREATE INDEX IF NOT EXISTS ix_proposals_id ON proposals (id);
    """)
    
    cur.execute("""
        CREATE TABLE IF NOT EXISTS sections (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            proposal_id UUID NOT NULL REFERENCES proposals(id) ON DELETE CASCADE,
            section_type sectiontype NOT NULL,
            title VARCHAR(500) NOT NULL,
            "order" INTEGER NOT NULL,
            content TEXT,
            word_count INTEGER NOT NULL DEFAULT 0,
            validation_status validationstatus NOT NULL DEFAULT 'not_started',
            is_mandatory BOOLEAN NOT NULL DEFAULT FALSE,
            validation_errors TEXT,
            last_modified_by UUID REFERENCES users(id),
            locked_by UUID REFERENCES users(id),
            locked_at TIMESTAMP
        );
        
        CREATE INDEX IF NOT EXISTS ix_sections_id ON sections (id);
    """)
    
    cur.execute("""
        CREATE TABLE IF NOT EXISTS validation_rules (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            section_type sectiontype NOT NULL,
            rule_type ruletype NOT NULL,
            name VARCHAR(255) NOT NULL,
            description TEXT,
            parameters JSONB,
            error_message TEXT NOT NULL,
            severity severity NOT NULL DEFAULT 'error',
            is_active BOOLEAN NOT NULL DEFAULT TRUE,
            framework_version VARCHAR(50)
        );
        
        CREATE INDEX IF NOT EXISTS ix_validation_rules_id ON validation_rules (id);
        CREATE INDEX IF NOT EXISTS ix_validation_rules_section_type ON validation_rules (section_type);
    """)
    
    cur.execute("""
        CREATE TABLE IF NOT EXISTS change_history (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            section_id UUID NOT NULL REFERENCES sections(id) ON DELETE CASCADE,
            user_id UUID NOT NULL REFERENCES users(id),
            change_type changetype NOT NULL,
            old_content TEXT,
            new_content TEXT,
            ip_address VARCHAR(45),
            user_agent VARCHAR(500),
            comment TEXT
        );
        
        CREATE INDEX IF NOT EXISTS ix_change_history_id ON change_history (id);
    """)
    
    cur.execute("""
        CREATE TABLE IF NOT EXISTS notifications (
            id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
            proposal_id UUID REFERENCES proposals(id) ON DELETE CASCADE,
            user_id UUID NOT NULL REFERENCES users(id),
            notification_type notificationtype NOT NULL,
            title VARCHAR(255) NOT NULL,
            message TEXT NOT NULL,
            sent_at TIMESTAMP,
            read_at TIMESTAMP,
            is_sent BOOLEAN NOT NULL DEFAULT FALSE,
            is_read BOOLEAN NOT NULL DEFAULT FALSE,
            email_sent BOOLEAN NOT NULL DEFAULT FALSE,
            email_sent_at TIMESTAMP
        );
        
        CREATE INDEX IF NOT EXISTS ix_notifications_id ON notifications (id);
    """)
    
    # Create alembic version table
    cur.execute("""
        CREATE TABLE IF NOT EXISTS alembic_version (
            version_num VARCHAR(32) NOT NULL PRIMARY KEY
        );
        
        INSERT INTO alembic_version (version_num) VALUES ('001_initial')
        ON CONFLICT (version_num) DO NOTHING;
    """)
    
    conn.commit()
    print("✅ Database initialized successfully!")
    
except Exception as e:
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()
finally:
    if conn:
        cur.close()
        conn.close()

