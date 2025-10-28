"""Seed database with test data"""

import psycopg2
import os
import uuid
from datetime import datetime, timedelta

# Get database URL from environment
db_url = os.getenv('DATABASE_URL', 'postgresql://postgres:postgres@postgres:5432/gcloud_db')
db_url = db_url.replace('postgresql+asyncpg://', 'postgresql://')

print("Connecting to database...")
conn = psycopg2.connect(db_url)
cur = conn.cursor()

try:
    # Create test user
    test_user_id = str(uuid.uuid4())
    print(f"Creating test user (ID: {test_user_id})...")
    
    cur.execute("""
        INSERT INTO users (id, azure_ad_id, email, full_name, role, is_active)
        VALUES (%s, %s, %s, %s, %s, %s)
        ON CONFLICT (email) DO UPDATE SET id = users.id
        RETURNING id
    """, (test_user_id, 'test-user-001', 'test@gcloud.local', 'Test User', 'editor', True))
    
    result = cur.fetchone()
    test_user_id = str(result[0])
    print(f"✅ Test user created: test@gcloud.local")
    
    # Create validation rules
    print("Creating validation rules...")
    
    validation_rules = [
        # Service Summary rules
        ('service_summary', 'word_count_min', 'Service Summary Min Words', 
         '{"min_words": 50}', 'Service summary must be at least 50 words', 'error'),
        ('service_summary', 'word_count_max', 'Service Summary Max Words', 
         '{"max_words": 500}', 'Service summary must not exceed 500 words', 'error'),
        
        # Service Features rules
        ('service_features', 'word_count_min', 'Service Features Min Words', 
         '{"min_words": 100}', 'Service features must be at least 100 words', 'error'),
        ('service_features', 'word_count_max', 'Service Features Max Words', 
         '{"max_words": 1000}', 'Service features must not exceed 1000 words', 'error'),
        
        # Pricing rules
        ('pricing', 'word_count_min', 'Pricing Min Words', 
         '{"min_words": 20}', 'Pricing information must be at least 20 words', 'error'),
        ('pricing', 'word_count_max', 'Pricing Max Words', 
         '{"max_words": 200}', 'Pricing information must not exceed 200 words', 'error'),
        
        # Data Security rules
        ('data_security', 'word_count_min', 'Data Security Min Words', 
         '{"min_words": 150}', 'Data security description must be at least 150 words', 'error'),
        ('data_security', 'word_count_max', 'Data Security Max Words', 
         '{"max_words": 800}', 'Data security description must not exceed 800 words', 'error'),
    ]
    
    for rule in validation_rules:
        section_type, rule_type, name, parameters, error_msg, severity = rule
        cur.execute("""
            INSERT INTO validation_rules (section_type, rule_type, name, parameters, error_message, severity, is_active, framework_version)
            VALUES (%s, %s, %s, %s::jsonb, %s, %s, %s, %s)
            ON CONFLICT DO NOTHING
        """, (section_type, rule_type, name, parameters, error_msg, severity, True, 'G-Cloud 14'))
    
    print(f"✅ Created {len(validation_rules)} validation rules")
    
    # Create test proposals
    print("Creating test proposals...")
    
    # PROPOSAL 1: Valid proposal (all sections within limits)
    proposal1_id = str(uuid.uuid4())
    cur.execute("""
        INSERT INTO proposals (id, title, framework_version, status, deadline, completion_percentage, created_by)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
    """, (proposal1_id, 'Cloud Storage Service - Valid', 'G-Cloud 14', 'draft', 
          datetime.now() + timedelta(days=30), 75.0, test_user_id))
    
    # Proposal 1 sections (all valid)
    sections_p1 = [
        ('service_summary', 'Service Summary', 1, 
         'Our cloud storage service provides secure, scalable, and reliable data storage solutions for UK government agencies. ' * 8,  # ~80 words (valid: 50-500)
         True),
        ('service_features', 'Service Features', 2,
         'Advanced encryption at rest and in transit. Automated backup and recovery systems. Real-time monitoring and alerting. ' * 15,  # ~150 words (valid: 100-1000)
         True),
        ('pricing', 'Pricing Information', 3,
         'Standard pricing: £0.10 per GB per month. Premium tier: £0.15 per GB per month with enhanced support and SLA. ' * 2,  # ~40 words (valid: 20-200)
         True),
        ('data_security', 'Data Security', 4,
         'Our service implements military-grade encryption using AES-256 for data at rest and TLS 1.3 for data in transit. ' * 20,  # ~200 words (valid: 150-800)
         True),
    ]
    
    for section in sections_p1:
        section_type, title, order, content, is_mandatory = section
        word_count = len(content.split())
        cur.execute("""
            INSERT INTO sections (proposal_id, section_type, title, "order", content, word_count, is_mandatory, validation_status)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """, (proposal1_id, section_type, title, order, content, word_count, is_mandatory, 'valid'))
    
    print(f"✅ Proposal 1: 'Cloud Storage Service - Valid' (all sections valid)")
    
    # PROPOSAL 2: Service Summary exceeds max words
    proposal2_id = str(uuid.uuid4())
    cur.execute("""
        INSERT INTO proposals (id, title, framework_version, status, deadline, completion_percentage, created_by)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
    """, (proposal2_id, 'Database Service - Summary Too Long', 'G-Cloud 14', 'draft',
          datetime.now() + timedelta(days=45), 50.0, test_user_id))
    
    sections_p2 = [
        ('service_summary', 'Service Summary', 1,
         'Our comprehensive database-as-a-service platform offers unparalleled performance and reliability. ' * 70,  # ~630 words (EXCEEDS 500 max)
         True),
        ('service_features', 'Service Features', 2,
         'High-performance database clusters with automatic scaling and load balancing capabilities. ' * 12,  # ~120 words (valid)
         True),
        ('pricing', 'Pricing Information', 3,
         'Flexible pricing based on usage: £0.50 per compute hour, £0.05 per GB storage. ' * 3,  # ~45 words (valid)
         False),
    ]
    
    for section in sections_p2:
        section_type, title, order, content, is_mandatory = section
        word_count = len(content.split())
        status = 'invalid' if section_type == 'service_summary' else 'valid'
        cur.execute("""
            INSERT INTO sections (proposal_id, section_type, title, "order", content, word_count, is_mandatory, validation_status)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """, (proposal2_id, section_type, title, order, content, word_count, is_mandatory, status))
    
    print(f"✅ Proposal 2: 'Database Service - Summary Too Long' (service_summary: 630 words > 500 max)")
    
    # PROPOSAL 3: Service Features below min words
    proposal3_id = str(uuid.uuid4())
    cur.execute("""
        INSERT INTO proposals (id, title, framework_version, status, deadline, completion_percentage, created_by)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
    """, (proposal3_id, 'AI Platform - Features Too Short', 'G-Cloud 14', 'draft',
          datetime.now() + timedelta(days=20), 40.0, test_user_id))
    
    sections_p3 = [
        ('service_summary', 'Service Summary', 1,
         'Our AI platform provides machine learning capabilities for government applications. ' * 10,  # ~110 words (valid)
         True),
        ('service_features', 'Service Features', 2,
         'Natural language processing. Computer vision. Predictive analytics.',  # ~8 words (BELOW 100 min)
         True),
        ('data_security', 'Data Security', 3,
         'Comprehensive security measures including encryption, access controls, and audit logging. ' * 18,  # ~180 words (valid)
         True),
    ]
    
    for section in sections_p3:
        section_type, title, order, content, is_mandatory = section
        word_count = len(content.split())
        status = 'invalid' if section_type == 'service_features' else 'valid'
        cur.execute("""
            INSERT INTO sections (proposal_id, section_type, title, "order", content, word_count, is_mandatory, validation_status)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """, (proposal3_id, section_type, title, order, content, word_count, is_mandatory, status))
    
    print(f"✅ Proposal 3: 'AI Platform - Features Too Short' (service_features: 8 words < 100 min)")
    
    # PROPOSAL 4: Multiple validation failures
    proposal4_id = str(uuid.uuid4())
    cur.execute("""
        INSERT INTO proposals (id, title, framework_version, status, deadline, completion_percentage, created_by)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
    """, (proposal4_id, 'Security Service - Multiple Errors', 'G-Cloud 14', 'draft',
          datetime.now() + timedelta(days=15), 30.0, test_user_id))
    
    sections_p4 = [
        ('service_summary', 'Service Summary', 1,
         'Short summary.',  # ~2 words (BELOW 50 min)
         True),
        ('pricing', 'Pricing Information', 2,
         'Our comprehensive pricing structure includes multiple tiers and options for all scenarios. ' * 25,  # ~225 words (EXCEEDS 200 max)
         True),
        ('data_security', 'Data Security', 3,
         'We have security measures in place for all data.',  # ~10 words (BELOW 150 min)
         True),
    ]
    
    for section in sections_p4:
        section_type, title, order, content, is_mandatory = section
        word_count = len(content.split())
        cur.execute("""
            INSERT INTO sections (proposal_id, section_type, title, "order", content, word_count, is_mandatory, validation_status)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        """, (proposal4_id, section_type, title, order, content, word_count, is_mandatory, 'invalid'))
    
    print(f"✅ Proposal 4: 'Security Service - Multiple Errors' (3 sections with violations)")
    
    conn.commit()
    print("\n" + "="*60)
    print("🎉 Seed data created successfully!")
    print("="*60)
    print(f"\n📧 Test User: test@gcloud.local (ID: {test_user_id})")
    print("\n📝 Test Proposals Created:")
    print("  1. Cloud Storage Service - Valid ✅")
    print("  2. Database Service - Summary Too Long ❌ (630/500 words)")
    print("  3. AI Platform - Features Too Short ❌ (8/100 words)")
    print("  4. Security Service - Multiple Errors ❌❌❌")
    print("\n✨ You can now test the validation system!")
    
except Exception as e:
    conn.rollback()
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()
finally:
    cur.close()
    conn.close()

