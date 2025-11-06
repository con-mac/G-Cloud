# G-Cloud Proposal Testing Guide

## ✅ What's Been Built

### Database Schema ✓
- All 6 tables created (users, proposals, sections, validation_rules, change_history, notifications)
- Proper relationships and foreign keys
- UUID primary keys for all tables
- Timestamps for audit trail

### Test Data ✓
- **Test User**: `test@gcloud.local` 
- **User ID**: `fe3d34b2-3538-4550-89b8-0fc96eee953a`
- **Role**: Editor
- **4 Test Proposals** with varying validation states

### Validation Rules ✓
8 active validation rules for word counts:
- **Service Summary**: 50-500 words
- **Service Features**: 100-1000 words
- **Pricing**: 20-200 words
- **Data Security**: 150-800 words

---

## 🧪 Test Proposals Overview

### 1️⃣ Cloud Storage Service - Valid ✅
**Status**: All sections pass validation

| Section | Word Count | Limit | Status |
|---------|-----------|-------|--------|
| Service Summary | 128 | 50-500 | ✅ Valid |
| Service Features | 240 | 100-1000 | ✅ Valid |
| Pricing | 38 | 20-200 | ✅ Valid |
| Data Security | 360 | 150-800 | ✅ Valid |

**Result**: Ready for submission

---

### 2️⃣ Database Service - Summary Too Long ❌
**Status**: 1 validation error

| Section | Word Count | Limit | Status |
|---------|-----------|-------|--------|
| Service Summary | **630** | 50-500 | ❌ **Exceeds maximum** |
| Service Features | 120 | 100-1000 | ✅ Valid |
| Pricing | 39 | 20-200 | ✅ Valid |

**Error**: Service summary must not exceed 500 words (has 630)

---

### 3️⃣ AI Platform - Features Too Short ❌
**Status**: 1 validation error

| Section | Word Count | Limit | Status |
|---------|-----------|-------|--------|
| Service Summary | 100 | 50-500 | ✅ Valid |
| Service Features | **7** | 100-1000 | ❌ **Below minimum** |
| Data Security | 180 | 150-800 | ✅ Valid |

**Error**: Service features must be at least 100 words (has 7)

---

### 4️⃣ Security Service - Multiple Errors ❌❌❌
**Status**: 3 validation errors

| Section | Word Count | Limit | Status |
|---------|-----------|-------|--------|
| Service Summary | **2** | 50-500 | ❌ **Below minimum** |
| Pricing | **300** | 20-200 | ❌ **Exceeds maximum** |
| Data Security | **9** | 150-800 | ❌ **Below minimum** |

**Errors**:
1. Service summary must be at least 50 words (has 2)
2. Pricing must not exceed 200 words (has 300)
3. Data security must be at least 150 words (has 9)

---

## 🚀 How to Test

### Run the Test Script

```bash
docker-compose exec backend python /app/scripts/test_proposals.py
```

This will display:
- ✅ Login confirmation as test user
- 📝 All proposals with their details
- 📑 Each section with validation status
- ❌ Specific errors for failed validations
- 📊 Summary statistics

### Expected Output

You'll see a comprehensive report showing:
- Visual indicators (✅ ❌ ⚠️)
- Word counts vs limits
- Validation errors with clear messages
- Overall proposal status

### Example Output Snippet

```
================================================================================
📄 PROPOSAL: Database Service - Summary Too Long
================================================================================
   Framework: G-Cloud 14
   Status: draft
   Completion: 50.0%

   📑 Sections (3):

      ❌ Service Summary
         Word Count: 630 words (limit: 50-500)
         Status: INVALID
         ❌ Errors:
            - Service summary must not exceed 500 words

   ❌ VALIDATION FAILED: 1 error(s)
```

---

## 🔍 What's Being Tested

### ✅ Validation Features

1. **Word Count Validation**
   - Minimum word requirements
   - Maximum word limits
   - Real-time counting (splits by whitespace)

2. **Multiple Rule Types**
   - Per-section type rules
   - Framework-specific rules
   - Severity levels (error vs warning)

3. **Test Scenarios**
   - Below minimum (too few words)
   - Above maximum (too many words)
   - Within range (valid)
   - Multiple violations

### 📊 Test Coverage

- ✅ Valid proposals (all rules pass)
- ❌ Single rule violations
- ❌ Multiple rule violations
- ✅ Different section types
- ✅ Mandatory vs optional sections

---

## 📂 Database Access

### View Raw Data

```bash
# Connect to PostgreSQL
docker-compose exec postgres psql -U postgres -d gcloud_db

# View proposals
SELECT id, title, status, completion_percentage FROM proposals;

# View sections
SELECT p.title, s.section_type, s.word_count, s.validation_status 
FROM sections s 
JOIN proposals p ON s.proposal_id = p.id;

# View validation rules
SELECT section_type, rule_type, parameters 
FROM validation_rules 
WHERE is_active = TRUE;

# Exit
\q
```

---

## 🔄 Re-run Tests

### Reset Database
```bash
docker-compose exec backend python /app/scripts/init_db.py
docker-compose exec backend python /app/scripts/seed_data.py
```

### Run Tests Again
```bash
docker-compose exec backend python /app/scripts/test_proposals.py
```

---

## 📝 Test User Details

**Login As**: Test User  
**Email**: `test@gcloud.local`  
**ID**: `fe3d34b2-3538-4550-89b8-0fc96eee953a`  
**Role**: Editor  
**Permissions**: Can create and edit proposals  

This user is automatically authenticated in the test script (no Azure AD required for testing).

---

## 🎯 Validation Rules Reference

| Section Type | Min Words | Max Words | Mandatory |
|--------------|-----------|-----------|-----------|
| Service Summary | 50 | 500 | Yes |
| Service Features | 100 | 1000 | Yes |
| Pricing | 20 | 200 | Variable |
| Data Security | 150 | 800 | Yes |

---

## ✨ Next Steps

To extend testing:

1. **Add More Proposals**: Modify `seed_data.py` and re-run
2. **Create Custom Rules**: Add to validation_rules table
3. **Test Different Scenarios**: Create proposals with edge cases
4. **API Testing**: Build REST endpoints to test via HTTP (coming next)

---

## 🐛 Troubleshooting

### Test Script Doesn't Run
```bash
# Restart backend
docker-compose restart backend

# Check logs
docker-compose logs backend
```

### Database Connection Error
```bash
# Ensure PostgreSQL is running
docker-compose ps postgres

# Check connection
docker-compose exec postgres psql -U postgres -c "SELECT 1"
```

### No Test Data
```bash
# Re-seed database
docker-compose exec backend python /app/scripts/seed_data.py
```

---

## 📊 Git History

```
✓ feat: initial framework
✓ docs: getting started guide  
✓ fix: Docker build errors
✓ feat: database schema and migrations
✓ feat: validation service and test script ← Current
```

---

**Last Updated**: 28 October 2025  
**Test Script**: `/backend/scripts/test_proposals.py`  
**Validation Logic**: `/backend/app/utils/validation.py`

