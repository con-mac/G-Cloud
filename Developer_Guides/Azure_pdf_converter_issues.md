# Azure PDF Converter Issues - Change Log

## Overview
Tracking changes made to fix PDF generation and document loading issues in Azure deployment.

---

## Change Log

### 2025-11-20 - Initial PDF Logic Fix

**Change:** Modified PDF converter to only generate on completion (not drafts)
- **File:** `backend/app/services/document_generator.py`
- **Line:** ~395
- **Change:** Added condition `and not save_as_draft` to PDF converter call
- **Intent:** PDFs should only be generated when proposals are finalized, not during draft saves
- **Status:** ✅ Deployed

### 2025-11-20 - Service Name Normalization (Final)

**Change:** Keep normalization (spaces to underscores) to match existing Azure container format
- **File:** `backend/app/services/document_generator.py`, `backend/sharepoint_service/mock_sharepoint.py`
- **Line:** ~254-261, ~378-382, ~336-342
- **Change:** Use service name normalization (spaces → underscores) to match existing folders in Azure container
- **Reason:** Existing Azure container already has folders with underscores - need to match existing data format
- **Impact:** Folder names use underscores (e.g., "Agile_Scrum") to match existing Azure container structure
- **Status:** ✅ Deployed - Matches existing Azure container format

---

## Issues Tracked

### Issue #1: Document Loading Error
**Error:** "Failed to load proposal: Document not found or could not be parsed: Agile Scrum (SERVICE DESC)"
**Status:** ✅ Fixed
**Reported:** 2025-11-20
**Fixed:** 2025-11-20

**Root Cause:** Filename mismatch - `get_document_path` was using `service_name` (search query) to construct filename, but saved documents use `actual_folder_name` (actual folder name, which may be normalized with underscores for Azure).

**Fix Applied:**
- **File:** `backend/sharepoint_service/mock_sharepoint.py`
- **Line:** ~257-261
- **Change:** Changed filename construction to use `service_folder_name` instead of `service_name`
- **Before:** `filename = f"PA GC{gcloud_version} SERVICE DESC {service_name}.docx"`
- **After:** `filename = f"PA GC{gcloud_version} SERVICE DESC {service_folder_name}.docx"`
- **Commit:** 64a7542 (deployed)

### Issue #2: PDF Download Shows "Coming Soon"
**Error:** PDF download button still shows "Coming Soon" after completion
**Status:** 🔴 Investigating
**Reported:** 2025-11-20

**Current Implementation:**
- PDF converter only called when `save_as_draft=False` (final completion, not drafts)
- PDF blob key is set in return dict
- templates.py checks if PDF blob exists and creates download URL

**Possible Causes:**
1. PDF_CONVERTER_FUNCTION_URL not set or incorrect
2. PDF converter Function App not deployed/working
3. PDF conversion failing silently (check Application Insights logs)
4. PDF blob not being created in Azure Blob Storage

**Next Steps:**
1. Verify PDF_CONVERTER_FUNCTION_URL environment variable is set
2. Check Application Insights logs for PDF conversion errors
3. Test PDF converter Function App directly
4. Verify PDF blob exists in Azure Storage after completion

