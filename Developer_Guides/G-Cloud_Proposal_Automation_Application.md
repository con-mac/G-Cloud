## G-Cloud Proposal Automation Application

### G-Cloud v15
- UK Crown Commercial Service (CCS) G-Cloud provides a framework for procuring cloud software, hosting, and support services.
- Version 15 introduces refreshed service definitions, updated accessibility expectations, and tighter data validation on catalogue submissions.
- Suppliers must present concise service descriptions (short summary, key features, key benefits, service definition) adhering to strict word counts and formatting.

### Current Problem
- Manual word counting for each section leads to human error and repeated rework.
- Draft templates remain unfinished because there is no guided workflow or validation.
- No automated reminders or workflow state tracking; relies on email and spreadsheets.
- Enumerated bullet formatting in Word conflicts with validation rules in the submission portal.
- Generating final Word/PDF packages requires manual copying, formatting, and storing in SharePoint.

### Solution (AWS Implementation)
- **Backend**: FastAPI hosted on AWS Lambda (behind API Gateway) parses uploaded DOCX content, strips enumeration artefacts, validates word counts, and manages SharePoint storage.
- **Frontend**: React single-page application served via S3 + CloudFront provides guided forms, real-time validation, and draft workflows.
- **PDF Conversion**: Dedicated Lambda container running LibreOffice converts generated Word documents into PDFs while preserving layout and imagery.
- **Storage**: S3 buckets (`templates`, `uploads`, `sharepoint`, `output`) separate lifecycle stages; versioning and lifecycle policies protect artefacts.
- **Automation**: Session storage + backend parsing ensure numbered bullets never surface in the template boxes; document generation and PDF conversion run asynchronously without manual steps.
- **IAM Roles & Policies**:
  - `gcloud-automation-dev-api-role`: Lambda execution role with least-privilege access to `sharepoint`, `templates`, and `uploads` buckets plus Secrets Manager for OAuth secrets.
  - `gcloud-automation-dev-pdf-role`: Lambda execution role scoped to `output` bucket with permission to write generated PDFs and publish logs.
  - CloudFront origin access identity restricted to static S3 bucket.
  - Parameter Store / Secrets Manager policies limited to required keys (SharePoint client ID/secret, tenant ID).

### Unit Tests & Example Results
- `backend/tests/test_document_generation.py` – verifies numbering resets between sections and About PA block retention.
- `backend/tests/azure/test_number_prefix.py` – ensures `strip_number_prefix` removes enumerated bullets, including non-breaking spaces.
- `backend/tests/azure/test_blob_path_resolver.py` – validates blob key naming for generated documents.
- `backend/tests/azure/test_pdf_event.py` – confirms PDF Lambda contract validation.
- `backend/tests/azure/test_healthcheck.py` – confirms FastAPI `/health` endpoint returns success.
- **Recent Run**: `pytest backend/tests/azure -q` → `9 passed in 1.77s` (warnings limited to Pydantic deprecations).

### AWS Architecture Diagram (Textual)
```
Users (Browser)
   │
   ▼
Amazon CloudFront (Static SPA)
   │
   ├──> Amazon S3 (Frontend assets)
   │
   ▼
Amazon API Gateway
   │
   ├──> AWS Lambda (FastAPI service)
   │        ├──> Amazon S3 (Templates / SharePoint / Uploads buckets)
   │        └──> Secrets Manager (SharePoint OAuth)
   │
   └──> AWS Lambda (PDF converter container)
             └──> Amazon S3 (Output bucket with generated PDFs)
```

### Azure Replication Plan (Bullet Outline)
- Provision Azure Functions (HTTP-trigger FastAPI, container-based PDF converter).
- Host SPA on Azure Static Web Apps with Azure Front Door for global caching.
- Replace S3 buckets with Azure Storage containers (`sharepoint`, `output`, `uploads`, `templates`).
- Store secrets in Azure Key Vault; grant managed identities `Key Vault Secrets User`.
- Use Azure API Management for throttling and request inspection.
- RBAC Assignments:
  - API Function identity → `Storage Blob Data Contributor` on `sharepoint`, `uploads`, `templates`.
  - PDF Function identity → `Storage Blob Data Contributor` scoped to `output`.
  - Deployment principal → `Website Contributor`, `Storage Blob Data Contributor`, `AcrPush` (time-bound).
  - Key Vault policies limited to `get`/`list` for runtime identities.

