# Implementation Plan: SharePoint Integration

## Overview
This document outlines the step-by-step implementation plan for integrating SharePoint document management into the G-Cloud Proposal Automation System.

---

## Architecture Approach

### Current Stack
- **Frontend**: React + TypeScript (Vite)
- **Backend**: Python (FastAPI) on AWS Lambda
- **Infrastructure**: AWS (Lambda, API Gateway, S3)
- **Future Consideration**: May need to migrate to Azure for company policy compliance

### Authentication Strategy
1. **Phase 1 (Mock)**: Email validation (`@paconsulting.com`)
2. **Phase 2 (Production)**: Microsoft 365 SSO via Azure AD
3. **Token Management**: Store tokens securely, use in Lambda functions

### SharePoint Access Strategy
- **API**: Microsoft Graph API
- **Authentication**: 
  - Option A: User context (OAuth flow from frontend)
  - Option B: App-only (service principal) for backend operations
  - **Recommended**: Hybrid approach (user context for document access, app-only for system operations)

---

## Implementation Phases

### Phase 1: Mock Development (Local)

#### Step 1.1: Create Mock SharePoint Structure
**Location**: `mock_sharepoint/`

**Folder Structure**:
```
mock_sharepoint/
├── GCloud 14/
│   └── PA Services/
│       ├── Cloud Support Services LOT 2/
│       │   └── Test Title/
│       │       ├── PA GC14 SERVICE DESC Test Title.docx
│       │       ├── PA GC14 SERVICE DESC Test Title.pdf
│       │       ├── PA GC14 Pricing Doc Test Title.docx
│       │       ├── PA GC14 Pricing Doc Test Title.pdf
│       │       └── OWNER John Smith.txt
│       └── Cloud Support Services LOT 3/
│           └── Agile Test Title/
│               ├── PA GC14 SERVICE DESC Agile Test Title.docx
│               ├── PA GC14 SERVICE DESC Agile Test Title.pdf
│               ├── PA GC14 Pricing Doc Agile Test Title.docx
│               ├── PA GC14 Pricing Doc Agile Test Title.pdf
│               └── OWNER Jane Doe.txt
└── GCloud 15/
    └── PA Services/
        ├── Cloud Support Services LOT 2/
        └── Cloud Support Services LOT 3/
```

**Seed Documents**:
- Create sample Word documents with proper naming
- Create sample PDFs
- Create .txt metadata files with exact format:
  ```
  1. SERVICE: Test Title
  2. OWNER: John Smith
  3. SPONSOR: Jane Doe
  ```

#### Step 1.2: Create Mock SharePoint Service
**Location**: `backend/sharepoint_service/`

**Functions**:
- `search_documents(query: str, folder_path: str) -> List[Dict]`
  - Fuzzy search (case-insensitive, contains matching)
  - Returns: `[{service_name, owner, folder_path, doc_type}, ...]`
- `read_document_metadata(folder_path: str) -> Dict`
  - Read .txt file and parse SERVICE, OWNER, SPONSOR
- `list_folders(base_path: str) -> List[str]`
  - List all service folders in LOT 2/3
- `read_document(file_path: str) -> bytes`
  - Download document content
- `create_folder(folder_path: str) -> bool`
  - Create folder structure
- `create_document(file_path: str, content: bytes) -> bool`
  - Upload/create document
- `create_metadata_file(folder_path: str, service: str, owner: str, sponsor: str) -> bool`
  - Create .txt metadata file with exact format

**API Endpoints** (FastAPI):
- `POST /api/v1/sharepoint/search`
  - Query: `{query: str, document_type: str}`
  - Returns: List of matching documents with metadata
- `GET /api/v1/sharepoint/metadata/{service_name}`
  - Returns: SERVICE, OWNER, SPONSOR from .txt file
- `GET /api/v1/sharepoint/document/{service_name}/{doc_type}`
  - Returns: Document content (Word/PDF)
- `POST /api/v1/sharepoint/create-folder`
  - Body: `{service_name: str, lot: str}`
  - Creates folder structure
- `POST /api/v1/sharepoint/create-metadata`
  - Body: `{service_name: str, owner: str, sponsor: str, lot: str}`
  - Creates .txt metadata file

#### Step 1.3: Build Frontend Components

**1. Login Screen** (`frontend/src/pages/Login.tsx`):
- Email input with validation
- Validate `@paconsulting.com` domain
- Store authenticated email in session/localStorage

**2. Questionnaire Flow** (`frontend/src/pages/ProposalFlow.tsx`):
- **Step 1**: "Are You updating or creating new?"
  - Radio buttons: "Updating" / "Creating New"
- **Step 2a (Update)**:
  - Select document type: "Service Description" / "Pricing Document"
  - Search input with live suggestions
  - Display: "Service Name | OWNER"
- **Step 2b (Create New)**:
  - Input: SERVICE, OWNER, SPONSOR
  - Select: LOT 2 / LOT 3
- **Step 3**: Document editor or redirect to appropriate form

**3. Search Component** (`frontend/src/components/SharePointSearch.tsx`):
- Debounced search input
- Live suggestions as user types
- Display format: "Service Name | OWNER"
- Click to select document

**4. Document Selection** (`frontend/src/components/DocumentSelector.tsx`):
- Show selected document details
- Option to edit Service Description or Pricing Document
- After editing one, ask: "Do you want to update the other?"

---

### Phase 2: SharePoint Integration

#### Step 2.1: Azure AD App Registration
1. Register app in Azure AD portal
2. Configure redirect URIs
3. Set API permissions:
   - `Files.ReadWrite.All` (for document operations)
   - `Sites.ReadWrite.All` (for folder operations)
   - `User.Read` (for user context)
4. Generate client secret
5. Store credentials in AWS Secrets Manager

#### Step 2.2: Microsoft Graph API Client
**Location**: `backend/sharepoint_service/graph_client.py`

**Dependencies**:
- `msal` (Microsoft Authentication Library)
- `requests` (for API calls)

**Functions**:
- `authenticate_user(code: str) -> str`
  - Exchange authorization code for access token
- `authenticate_app() -> str`
  - Get app-only access token (service principal)
- `get_sharepoint_site(site_url: str) -> Dict`
  - Get SharePoint site by URL
- `search_documents(query: str, site_id: str, drive_id: str) -> List[Dict]`
  - Use Microsoft Graph API to search documents
  - Filter by folder path
  - Fuzzy matching in application
- `read_document(site_id: str, item_id: str) -> bytes`
  - Download document content
- `create_folder(site_id: str, drive_id: str, folder_path: str) -> Dict`
  - Create folder structure
- `upload_document(site_id: str, drive_id: str, folder_id: str, filename: str, content: bytes) -> Dict`
  - Upload document to SharePoint

#### Step 2.3: Replace Mock with Real API
1. Update backend endpoints to use Microsoft Graph API
2. Replace mock service calls with real SharePoint operations
3. Handle authentication flow
4. Add error handling for SharePoint API errors

---

### Phase 3: Document Operations Integration

#### Step 3.1: Document Reading
- Download existing Word/PDF from SharePoint
- Parse document content
- Load into editor (for updates)

#### Step 3.2: Document Updating
- Save edited document
- Upload to SharePoint (replace existing)
- Update metadata if needed

#### Step 3.3: Document Creation
- Generate Word document (using existing `document_generator.py`)
- Generate PDF (using existing `pdf_converter.py`)
- Upload to SharePoint in correct folder
- Create .txt metadata file

#### Step 3.4: Folder Management
- Create service folder if it doesn't exist
- Create LOT folder if it doesn't exist (GCloud 15)
- Ensure proper folder structure

---

### Phase 4: Frontend Integration

#### Step 4.1: Authentication Flow
- Redirect to Microsoft login (OAuth)
- Handle callback with authorization code
- Exchange code for access token
- Store token securely (httpOnly cookie or session)

#### Step 4.2: Search Integration
- Connect search component to SharePoint API
- Display live suggestions
- Handle selection and document loading

#### Step 4.3: Document Editor Integration
- Load document from SharePoint
- Edit in existing editor
- Save back to SharePoint
- Handle both Service Description and Pricing Document flows

---

## Technical Implementation Details

### Fuzzy Search Algorithm
```python
def fuzzy_match(query: str, service_name: str) -> bool:
    """
    Case-insensitive contains matching with variation handling.
    Handles: "Test Title v2", "Agile Test Title", "test title", "TEST TITLE"
    """
    query_lower = query.lower().strip()
    service_lower = service_name.lower().strip()
    
    # Remove version indicators (v2, v3, etc.)
    query_clean = re.sub(r'\s+v\d+\s*$', '', query_lower)
    service_clean = re.sub(r'\s+v\d+\s*$', '', service_lower)
    
    # Contains matching
    return query_clean in service_clean or service_clean in query_clean
```

### Metadata File Format
```python
def create_metadata_file(service: str, owner: str, sponsor: str) -> str:
    """Create metadata .txt file with exact format."""
    return f"""1. SERVICE: {service}
2. OWNER: {owner}
3. SPONSOR: {sponsor}
"""
```

### Folder Path Resolution
```python
def get_folder_path(service_name: str, lot: str, gcloud_version: str = "15") -> str:
    """Get SharePoint folder path."""
    base = f"GCloud {gcloud_version}/PA Services"
    lot_folder = f"Cloud Support Services LOT {lot}"
    return f"{base}/{lot_folder}/{service_name}"
```

---

## Security Considerations

1. **Authentication**: 
   - Validate `@paconsulting.com` email domain
   - Use Microsoft 365 SSO for production
   - Store tokens securely (not in localStorage)

2. **Authorization**:
   - Check user permissions before document operations
   - Validate user has access to SharePoint folders

3. **Credentials**:
   - Store Azure AD app credentials in AWS Secrets Manager
   - Rotate credentials regularly
   - Never commit credentials to git

4. **Data**:
   - Encrypt sensitive data in transit (HTTPS)
   - Validate all user inputs
   - Sanitize file paths to prevent directory traversal

---

## Testing Strategy

### Phase 1: Mock Testing
1. Test search functionality with various query formats
2. Test fuzzy matching with different variations
3. Test metadata file creation/reading
4. Test folder creation logic
5. Test document operations (read/write)

### Phase 2: Integration Testing
1. Test Microsoft Graph API authentication
2. Test SharePoint document operations
3. Test folder creation in SharePoint
4. Test metadata file operations
5. Test end-to-end workflow (search → select → edit → save)

### Phase 3: User Acceptance Testing
1. Test with real SharePoint structure
2. Test with real user accounts
3. Test SSO flow
4. Test document generation and upload
5. Test folder creation and management

---

## Deployment Plan

### Development Environment
- Use mock SharePoint structure
- Local development and testing
- No SharePoint credentials required

### Staging Environment
- Connect to SharePoint test site
- Use test Azure AD app registration
- Test with sample documents

### Production Environment
- Connect to production SharePoint
- Use production Azure AD app registration
- Full SSO integration
- Monitoring and logging

---

## Next Steps

1. ✅ Create production roadmap
2. ✅ Create implementation plan
3. ⏳ Create mock SharePoint structure
4. ⏳ Seed test documents
5. ⏳ Create mock SharePoint service
6. ⏳ Build frontend login and questionnaire
7. ⏳ Integrate with existing document generation
8. ⏳ Set up Azure AD app registration
9. ⏳ Integrate Microsoft Graph API
10. ⏳ Test end-to-end workflow

---

## Notes

- All file and folder naming must follow exact format specified in `production_roadmap.md`
- Metadata .txt files must use exact format (numbered lines)
- Search must be fuzzy and case-insensitive
- Folder creation must handle missing parent folders
- Both LOT 2 and LOT 3 folders should be searchable simultaneously

