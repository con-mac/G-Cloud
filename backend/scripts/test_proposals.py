"""Test script to view and validate all proposals"""

import psycopg2
import os
import sys
sys.path.append('/app')

from app.utils.validation import count_words, validate_word_count

# Get database URL
db_url = os.getenv('DATABASE_URL', 'postgresql://postgres:postgres@postgres:5432/gcloud_db')
db_url = db_url.replace('postgresql+asyncpg://', 'postgresql://')

print("=" * 80)
print("G-CLOUD PROPOSAL VALIDATION TEST")
print("=" * 80)
print()

conn = psycopg2.connect(db_url)
cur = conn.cursor()

try:
    # Get test user
    cur.execute("SELECT id, email, full_name FROM users WHERE email = 'test@gcloud.local'")
    user = cur.fetchone()
    if user:
        print(f"✅ Logged in as: {user[2]} ({user[1]})")
        print(f"   User ID: {user[0]}")
    else:
        print("❌ Test user not found!")
        sys.exit(1)
    
    print()
    print("-" * 80)
    
    # Get all proposals
    cur.execute("""
        SELECT id, title, framework_version, status, deadline, completion_percentage, created_at
        FROM proposals
        ORDER BY created_at
    """)
    proposals = cur.fetchall()
    
    print(f"\n📝 Found {len(proposals)} proposals:")
    print()
    
    for prop in proposals:
        prop_id, title, framework, status, deadline, completion, created = prop
        
        print("=" * 80)
        print(f"📄 PROPOSAL: {title}")
        print("=" * 80)
        print(f"   ID: {prop_id}")
        print(f"   Framework: {framework}")
        print(f"   Status: {status}")
        print(f"   Completion: {completion}%")
        print(f"   Deadline: {deadline}")
        print()
        
        # Get sections for this proposal
        cur.execute("""
            SELECT id, section_type, title, content, word_count, is_mandatory, validation_status
            FROM sections
            WHERE proposal_id = %s
            ORDER BY "order"
        """, (prop_id,))
        sections = cur.fetchall()
        
        print(f"   📑 Sections ({len(sections)}):")
        print()
        
        total_errors = 0
        total_warnings = 0
        
        for section in sections:
            sec_id, sec_type, sec_title, content, word_count, is_mandatory, val_status = section
            
            # Get validation rules for this section type
            cur.execute("""
                SELECT section_type, rule_type, parameters, error_message, severity
                FROM validation_rules
                WHERE section_type = %s AND is_active = TRUE
            """, (sec_type,))
            rules = cur.fetchall()
            
            # Validate
            min_words = None
            max_words = None
            errors = []
            warnings = []
            
            for rule in rules:
                rule_section_type, rule_type, parameters, error_msg, severity = rule
                
                if rule_type == 'word_count_min':
                    min_words = parameters.get('min_words')
                    if word_count < min_words:
                        errors.append(error_msg)
                        
                elif rule_type == 'word_count_max':
                    max_words = parameters.get('max_words')
                    if word_count > max_words:
                        errors.append(error_msg)
            
            # Determine status icon
            if errors:
                status_icon = "❌"
                status_text = "INVALID"
                total_errors += len(errors)
            elif warnings:
                status_icon = "⚠️ "
                status_text = "WARNING"
                total_warnings += len(warnings)
            else:
                status_icon = "✅"
                status_text = "VALID"
            
            # Build word count display
            word_display = f"{word_count} words"
            if min_words and max_words:
                word_display += f" (limit: {min_words}-{max_words})"
            elif min_words:
                word_display += f" (min: {min_words})"
            elif max_words:
                word_display += f" (max: {max_words})"
            
            print(f"      {status_icon} {sec_title}")
            print(f"         Type: {sec_type}")
            print(f"         Word Count: {word_display}")
            print(f"         Status: {status_text}")
            print(f"         Mandatory: {'Yes' if is_mandatory else 'No'}")
            
            if errors:
                print(f"         ❌ Errors:")
                for error in errors:
                    print(f"            - {error}")
            
            if warnings:
                print(f"         ⚠️  Warnings:")
                for warning in warnings:
                    print(f"            - {warning}")
            
            print()
        
        # Summary for this proposal
        if total_errors > 0:
            print(f"   ❌ VALIDATION FAILED: {total_errors} error(s)")
        elif total_warnings > 0:
            print(f"   ⚠️  VALIDATION PASSED WITH WARNINGS: {total_warnings} warning(s)")
        else:
            print(f"   ✅ ALL SECTIONS VALID")
        
        print()
    
    print("=" * 80)
    print("TEST COMPLETE")
    print("=" * 80)
    print()
    print("📊 SUMMARY:")
    print(f"   Total Proposals: {len(proposals)}")
    print()
    print("💡 HOW TO TEST:")
    print("   1. Review the validation results above")
    print("   2. Check word counts against the defined limits")
    print("   3. Proposals with ❌ have validation errors")
    print("   4. Proposals with ✅ are valid and ready for submission")
    print()
    print("🔄 TO RE-RUN TEST:")
    print("   docker-compose exec backend python /app/scripts/test_proposals.py")
    print()
    
except Exception as e:
    print(f"❌ Error: {e}")
    import traceback
    traceback.print_exc()
finally:
    cur.close()
    conn.close()

