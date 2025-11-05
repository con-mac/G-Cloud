# SharePoint Integration Guide

## Overview
This guide provides comprehensive documentation for the SharePoint integration feature, including API endpoints, frontend routes, components, and testing instructions.

---

## Table of Contents
1. [API Endpoints](#api-endpoints)
2. [Frontend Routes](#frontend-routes)
3. [Components](#components)
4. [Services](#services)
5. [File Structure](#file-structure)
6. [Testing](#testing)
7. [Development Workflow](#development-workflow)

---

## API Endpoints

### Base URL
- **Local Development**: `http://localhost:8000/api/v1`
- **AWS API Gateway**: `https://[api-gateway-url]/api/v1`

### SharePoint Endpoints

#### 1. Search Documents
**Endpoint**: `POST /api/v1/sharepoint/search`

**Description**: Search for documents in mock SharePoint with fuzzy matching.

**Request Body**:
```json
{
  "query": "test title",
  "doc_type": "SERVICE DESC",  // Optional: "SERVICE DESC" or "Pricing Doc"
  "gcloud_version": "14"  // Optional: "14" or "15"
}
```

**Response**:
```json
[
  {
    "service_name": "Test Title",
    "owner": "John Smith",
    "sponsor": "Jane Doe",
    "folder_path": "/path/to/folder",
    "doc_type": "SERVICE DESC",
    "lot": "2",
    "gcloud_version": "14"
  }
]
```

**Example**:
```bash
curl -X POST http://localhost:8000/api/v1/sharepoint/search \
  -H "Content-Type: application/json" \
  -d '{"query": "test title", "doc_type": "SERVICE DESC"}'
```

---

#### 2. Get Metadata
**Endpoint**: `GET /api/v1/sharepoint/metadata/{service_name}`

**Description**: Get metadata (SERVICE, OWNER, SPONSOR) for a service.

**Query Parameters**:
- `lot`: LOT number ("2" or "3") - **Required**
- `gcloud_version`: GCloud version ("14" or "15") - Default: "14"

**Response**:
```json
{
  "service": "Test Title",
  "owner": "John Smith",
  "sponsor": "Jane Doe"
}
```

**Example**:
```bash
curl "http://localhost:8000/api/v1/sharepoint/metadata/Test%20Title?lot=2&gcloud_version=14"
```

---

#### 3. Get Document Info
**Endpoint**: `GET /api/v1/sharepoint/document/{service_name}`

**Description**: Get document path information.

**Query Parameters**:
- `doc_type`: Document type ("SERVICE DESC" or "Pricing Doc") - **Required**
- `lot`: LOT number ("2" or "3") - **Required**
- `gcloud_version`: GCloud version ("14" or "15") - Default: "14"

**Response**:
```json
{
  "service_name": "Test Title",
  "doc_type": "SERVICE DESC",
  "lot": "2",
  "gcloud_version": "14",
  "file_path": "/path/to/document.docx",
  "exists": true
}
```

**Example**:
```bash
curl "http://localhost:8000/api/v1/sharepoint/document/Test%20Title?doc_type=SERVICE%20DESC&lot=2"
```

---

#### 4. Create Folder
**Endpoint**: `POST /api/v1/sharepoint/create-folder`

**Description**: Create folder structure for new proposal.

**Request Body**:
```json
{
  "service_name": "New Service",
  "lot": "2",  // "2" or "3"
  "gcloud_version": "15"  // Default: "15"
}
```

**Response**:
```json
{
  "success": true,
  "folder_path": "/path/to/new/service",
  "service_name": "New Service",
  "lot": "2",
  "gcloud_version": "15"
}
```

**Example**:
```bash
curl -X POST http://localhost:8000/api/v1/sharepoint/create-folder \
  -H "Content-Type: application/json" \
  -d '{"service_name": "New Service", "lot": "2", "gcloud_version": "15"}'
```

---

#### 5. Create Metadata File
**Endpoint**: `POST /api/v1/sharepoint/create-metadata`

**Description**: Create metadata .txt file with exact format.

**Request Body**:
```json
{
  "service_name": "New Service",
  "owner": "John Doe",
  "sponsor": "Jane Smith",
  "lot": "2",  // "2" or "3"
  "gcloud_version": "15"  // Default: "15"
}
```

**Response**:
```json
{
  "success": true,
  "folder_path": "/path/to/new/service",
  "service_name": "New Service",
  "owner": "John Doe",
  "sponsor": "Jane Smith"
}
```

**Example**:
```bash
curl -X POST http://localhost:8000/api/v1/sharepoint/create-metadata \
  -H "Content-Type: application/json" \
  -d '{
    "service_name": "New Service",
    "owner": "John Doe",
    "sponsor": "Jane Smith",
    "lot": "2"
  }'
```

---

#### 6. List All Folders
**Endpoint**: `GET /api/v1/sharepoint/list-folders`

**Description**: List all service folders in mock SharePoint.

**Query Parameters**:
- `gcloud_version`: GCloud version ("14" or "15") - Default: "14"

**Response**:
```json
[
  {
    "service_name": "Test Title",
    "owner": "John Smith",
    "sponsor": "Jane Doe",
    "folder_path": "/path/to/folder",
    "doc_type": "SERVICE DESC",
    "lot": "2",
    "gcloud_version": "14"
  }
]
```

**Example**:
```bash
curl "http://localhost:8000/api/v1/sharepoint/list-folders?gcloud_version=14"
```

---

## Frontend Routes

### Base URL
- **Local Development**: `http://localhost:3000`
- **Production**: `https://[cloudfront-url]`

### Routes

#### 1. Login Page
**Route**: `/login`

**Description**: Login page with email validation (`@paconsulting.com`).

**File**: `frontend/src/pages/Login.tsx`

**Features**:
- Email validation (must end with `@paconsulting.com`)
- Stores authentication in sessionStorage
- Redirects to `/proposals/flow` after login

**Usage**:
```typescript
// Navigate to login
navigate('/login');

// Check authentication
const isAuthenticated = sessionStorage.getItem('isAuthenticated') === 'true';
```

---

#### 2. Proposal Flow
**Route**: `/proposals/flow`

**Description**: Multi-step questionnaire for Update vs Create workflow.

**File**: `frontend/src/pages/ProposalFlow.tsx`

**Features**:
- Step 1: Update vs Create selection
- Step 2a (Update): Document type selection + search
- Step 2b (Create): SERVICE, OWNER, SPONSOR, LOT input
- Step 3: Confirmation screen

**Protected**: Yes (requires authentication)

**Usage**:
```typescript
// Navigate to flow
navigate('/proposals/flow');
```

---

#### 3. Proposals List
**Route**: `/proposals`

**Description**: List of all proposals.

**File**: `frontend/src/pages/ProposalsList.tsx`

**Protected**: Yes (requires authentication)

---

#### 4. Create Proposal
**Route**: `/proposals/create`

**Description**: Create new proposal template selection.

**File**: `frontend/src/pages/CreateProposal.tsx`

**Protected**: Yes (requires authentication)

---

#### 5. Service Description Form
**Route**: `/proposals/create/service-description`

**Description**: Service Description form with rich text editor.

**File**: `frontend/src/pages/ServiceDescriptionForm.tsx`

**Protected**: Yes (requires authentication)

---

#### 6. Proposal Editor
**Route**: `/proposals/:id`

**Description**: Edit existing proposal.

**File**: `frontend/src/pages/ProposalEditor.tsx`

**Protected**: Yes (requires authentication)

---

## Components

### SharePointSearch Component

**File**: `frontend/src/components/SharePointSearch.tsx`

**Description**: Search component with live suggestions.

**Props**:
```typescript
interface SharePointSearchProps {
  query: string;
  onChange: (query: string) => void;
  onSelect: (result: SearchResult) => void;
  docType?: 'SERVICE DESC' | 'Pricing Doc';
  gcloudVersion?: '14' | '15';
  placeholder?: string;
  label?: string;
}
```

**Usage**:
```typescript
import SharePointSearch, { SearchResult } from '../components/SharePointSearch';

const [query, setQuery] = useState('');
const [selectedResult, setSelectedResult] = useState<SearchResult | null>(null);

<SharePointSearch
  query={query}
  onChange={setQuery}
  onSelect={(result) => setSelectedResult(result)}
  docType="SERVICE DESC"
  gcloudVersion="14"
  placeholder="Type service name..."
  label="Search Service"
/>
```

**Features**:
- Live suggestions as user types (300ms debounce)
- Displays "Service Name | OWNER" format
- Shows LOT and document type
- Click outside to close
- Loading and empty states

---

## Services

### SharePoint API Service

**File**: `frontend/src/services/sharepointApi.ts`

**Description**: Service wrapper for SharePoint API endpoints.

**Methods**:

#### `searchDocuments(request: SearchRequest): Promise<SearchResult[]>`
Search for documents in SharePoint.

**Example**:
```typescript
import sharepointApi from '../services/sharepointApi';

const results = await sharepointApi.searchDocuments({
  query: 'test title',
  doc_type: 'SERVICE DESC',
  gcloud_version: '14',
});
```

#### `getMetadata(serviceName: string, lot: '2' | '3', gcloudVersion?: '14' | '15'): Promise<MetadataResponse>`
Get metadata for a service.

**Example**:
```typescript
const metadata = await sharepointApi.getMetadata('Test Title', '2', '14');
console.log(metadata.service, metadata.owner, metadata.sponsor);
```

#### `getDocument(serviceName: string, docType: 'SERVICE DESC' | 'Pricing Doc', lot: '2' | '3', gcloudVersion?: '14' | '15'): Promise<any>`
Get document information.

**Example**:
```typescript
const docInfo = await sharepointApi.getDocument('Test Title', 'SERVICE DESC', '2', '14');
```

#### `createFolder(request: CreateFolderRequest): Promise<any>`
Create folder structure.

**Example**:
```typescript
const result = await sharepointApi.createFolder({
  service_name: 'New Service',
  lot: '2',
  gcloud_version: '15',
});
```

#### `createMetadata(request: CreateMetadataRequest): Promise<any>`
Create metadata file.

**Example**:
```typescript
const result = await sharepointApi.createMetadata({
  service_name: 'New Service',
  owner: 'John Doe',
  sponsor: 'Jane Smith',
  lot: '2',
  gcloud_version: '15',
});
```

---

## File Structure

### Backend Files

```
backend/
├── sharepoint_service/
│   ├── __init__.py
│   └── mock_sharepoint.py          # Mock SharePoint service
├── app/
│   ├── api/
│   │   ├── routes/
│   │   │   └── sharepoint.py      # SharePoint API endpoints
│   │   └── __init__.py            # Router registration
│   └── main.py                    # FastAPI app
└── mock_sharepoint/                # Mock SharePoint structure
    ├── GCloud 14/
    │   └── PA Services/
    │       ├── Cloud Support Services LOT 2/
    │       └── Cloud Support Services LOT 3/
    └── GCloud 15/
        └── PA Services/
            ├── Cloud Support Services LOT 2/
            └── Cloud Support Services LOT 3/
```

### Frontend Files

```
frontend/
├── src/
│   ├── pages/
│   │   ├── Login.tsx               # Login page
│   │   └── ProposalFlow.tsx        # Questionnaire flow
│   ├── components/
│   │   └── SharePointSearch.tsx    # Search component
│   ├── services/
│   │   └── sharepointApi.ts        # SharePoint API service
│   └── App.tsx                     # Routes and protected routes
```

---

## Testing

### Backend Testing

#### Test Mock SharePoint Service
```bash
cd backend
python3 -c "
from sharepoint_service.mock_sharepoint import search_documents
results = search_documents('test title')
print(f'Found {len(results)} results')
"
```

#### Test API Endpoints (with FastAPI running)
```bash
# Start FastAPI server
cd backend
uvicorn app.main:app --reload

# Test search endpoint
curl -X POST http://localhost:8000/api/v1/sharepoint/search \
  -H "Content-Type: application/json" \
  -d '{"query": "test title", "doc_type": "SERVICE DESC"}'
```

### Frontend Testing

#### Build Frontend
```bash
cd frontend
npm run build
```

#### Run Development Server
```bash
cd frontend
npm run dev
```

#### Test Workflow
1. Navigate to `http://localhost:3000/login`
2. Enter email ending with `@paconsulting.com`
3. Click "Sign In"
4. Navigate to `/proposals/flow`
5. Test Update flow:
   - Select "Updating"
   - Select document type
   - Search for service
   - Select result
6. Test Create flow:
   - Select "Creating New"
   - Fill in SERVICE, OWNER, SPONSOR
   - Select LOT
   - Confirm and proceed

---

## Development Workflow

### 1. Start Backend
```bash
cd backend
uvicorn app.main:app --reload
```

### 2. Start Frontend
```bash
cd frontend
npm run dev
```

### 3. Access Application
- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:8000
- **API Docs**: http://localhost:8000/docs

### 4. Test Authentication
1. Go to http://localhost:3000/login
2. Enter email: `test@paconsulting.com`
3. Click "Sign In"
4. Should redirect to `/proposals/flow`

### 5. Test Search
1. Navigate to `/proposals/flow`
2. Select "Updating"
3. Select document type
4. Type in search box (e.g., "test title")
5. Should see live suggestions

### 6. Test Create
1. Navigate to `/proposals/flow`
2. Select "Creating New"
3. Fill in all fields
4. Select LOT
5. Confirm and proceed

---

## Links

### API Documentation
- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc
- **OpenAPI JSON**: http://localhost:8000/openapi.json

### Frontend Routes
- **Login**: http://localhost:3000/login
- **Proposal Flow**: http://localhost:3000/proposals/flow
- **Proposals List**: http://localhost:3000/proposals
- **Create Proposal**: http://localhost:3000/proposals/create
- **Service Description**: http://localhost:3000/proposals/create/service-description

### Backend Files
- **Mock SharePoint Service**: `backend/sharepoint_service/mock_sharepoint.py`
- **SharePoint API Routes**: `backend/app/api/routes/sharepoint.py`
- **API Router**: `backend/app/api/__init__.py`

### Frontend Files
- **Login Page**: `frontend/src/pages/Login.tsx`
- **Proposal Flow**: `frontend/src/pages/ProposalFlow.tsx`
- **Search Component**: `frontend/src/components/SharePointSearch.tsx`
- **SharePoint API Service**: `frontend/src/services/sharepointApi.ts`
- **App Routes**: `frontend/src/App.tsx`

### Documentation
- **Production Roadmap**: `production_roadmap.md`
- **Implementation Plan**: `IMPLEMENTATION_PLAN.md`
- **Mock SharePoint README**: `MOCK_SHAREPOINT_README.md`
- **This Guide**: `SHAREPOINT_INTEGRATION_GUIDE.md`

---

## Next Steps

1. ✅ Backend mock SharePoint service - Complete
2. ✅ API endpoints - Complete
3. ✅ Frontend Login - Complete
4. ✅ Questionnaire flow - Complete
5. ✅ Search component - Complete
6. ⏳ Test end-to-end workflow
7. ⏳ Integrate with document generation
8. ⏳ Real SharePoint integration (Phase 2)

---

## Notes

- All authentication is currently stored in `sessionStorage`
- Mock SharePoint structure is in `mock_sharepoint/` directory
- Fuzzy search handles case-insensitive variations
- All routes are protected except `/login`
- Future: Microsoft 365 SSO integration

