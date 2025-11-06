# Production Roadmap: SharePoint Integration & Document Management

## Overview
This roadmap outlines the requirements and implementation plan for integrating SharePoint document management into the G-Cloud Proposal Automation System.

---

## Authentication Requirements

### Initial Login Screen
- **Email Validation**: Must end with `@paconsulting.com`
- **Future Enhancement**: SSO integration with Microsoft 365 for go-live version
- **Validation**: Block access if email doesn't match company domain

---

## Document Workflow: Update vs Create

### Questionnaire Flow

#### Option 1: Updating Existing Proposal
1. User selects: **"Are You updating or creating new?"** → **"Updating"**
2. Select document type: **"Are You updating a Service Description or Pricing Document"**
   - Service Description
   - Pricing Document
3. Enter service name: **"Enter the name of the service you are updating"**
   - **Fuzzy Search**: Must be loose matching (case-insensitive)
   - **Handles variations**: "Test Title v2", "Agile Test Title", "test title", "TEST TITLE"
   - **Search Logic**: Use "contains" matching, not strict equality
   - **Live Suggestions**: As user types each letter, show potential matches below
   - **Display Format**: Show "Service Name | OWNER" for each match
4. **Search Location**: 
   - SharePoint folder: `GCloud 14 > PA Services > Cloud Support Services LOT 2`
   - SharePoint folder: `GCloud 14 > PA Services > Cloud Support Services LOT 3`
   - **Search both folders** (they aren't large)
5. User selects correct match
6. System opens appropriate Word document:
   - Service Description → `PA GC14 SERVICE DESC [Service Name].docx`
   - Pricing Document → `PA GC14 Pricing Doc [Service Name].docx`
7. After completing one document, ask: **"Do you want to update the other?"**

#### Option 2: Creating New Proposal
1. User selects: **"Are You updating or creating new?"** → **"Creating New"**
2. Collect metadata:
   - **SERVICE**: [Service Name] (maps to document Service Name title)
   - **OWNER**: [First name] [Last name]
   - **SPONSOR**: [First name] [Last name]
3. Create .txt metadata file: `OWNER [First name] [Last name].txt`
   - **File Format** (exact):
     ```
     1. SERVICE: [Service Name]
     2. OWNER: [First name] [Last name]
     3. SPONSOR: [First name] [Last name]
     ```
4. Select LOT: **"Is this a LOT 2 or LOT 3 proposal?"**
   - Cloud Support Services LOT 2
   - Cloud Support Services LOT 3
5. **Folder Creation**:
   - Folder name: `[Service Name]` (inherits from SERVICE field)
   - Location: `GCloud 15 > PA Services > [Selected LOT folder]`
   - **Auto-create LOT folder if it doesn't exist**
6. **Document Naming**:
   - Service Description: `PA GC15 SERVICE DESC [Service Name].docx/.pdf`
   - Pricing Document: `PA GC15 Pricing Doc [Service Name].docx/.pdf`
   - Metadata: `OWNER [First name] [Last name].txt`

---

## SharePoint Folder Structure

### Existing Proposals (GCloud 14)
```
GCloud 14/
└── PA Services/
    ├── Cloud Support Services LOT 2/
    │   └── [Service Name Folder]/
    │       ├── PA GC14 SERVICE DESC [Service Name].docx
    │       ├── PA GC14 SERVICE DESC [Service Name].pdf
    │       ├── PA GC14 Pricing Doc [Service Name].docx
    │       ├── PA GC14 Pricing Doc [Service Name].pdf
    │       └── OWNER [First name] [Last name].txt
    └── Cloud Support Services LOT 3/
        └── [Service Name Folder]/
            ├── PA GC14 SERVICE DESC [Service Name].docx
            ├── PA GC14 SERVICE DESC [Service Name].pdf
            ├── PA GC14 Pricing Doc [Service Name].docx
            ├── PA GC14 Pricing Doc [Service Name].pdf
            └── OWNER [First name] [Last name].txt
```

### New Proposals (GCloud 15)
```
GCloud 15/
└── PA Services/
    ├── Cloud Support Services LOT 2/
    │   └── [Service Name Folder]/
    │       ├── PA GC15 SERVICE DESC [Service Name].docx
    │       ├── PA GC15 SERVICE DESC [Service Name].pdf
    │       ├── PA GC15 Pricing Doc [Service Name].docx
    │       ├── PA GC15 Pricing Doc [Service Name].pdf
    │       └── OWNER [First name] [Last name].txt
    └── Cloud Support Services LOT 3/
        └── [Service Name Folder]/
            ├── PA GC15 SERVICE DESC [Service Name].docx
            ├── PA GC15 SERVICE DESC [Service Name].pdf
            ├── PA GC15 Pricing Doc [Service Name].docx
            ├── PA GC15 Pricing Doc [Service Name].pdf
            └── OWNER [First name] [Last name].txt
```

---

## Document Naming Conventions

### Update Existing (GCloud 14)
- Service Description: `PA GC14 SERVICE DESC [Service Name].docx/.pdf`
- Pricing Document: `PA GC14 Pricing Doc [Service Name].docx/.pdf`

### Create New (GCloud 15)
- Service Description: `PA GC15 SERVICE DESC [Service Name].docx/.pdf`
- Pricing Document: `PA GC15 Pricing Doc [Service Name].docx/.pdf`

### Metadata File
- Format: `OWNER [First name] [Last name].txt`
- Content (exact format):
  ```
  1. SERVICE: [Service Name]
  2. OWNER: [First name] [Last name]
  3. SPONSOR: [First name] [Last name]
  ```

---

## Folder Naming

- **Folder Name**: Inherits from SERVICE field (Service Name)
- **Example**: If SERVICE = "Test Title", folder = "Test Title"

---

## Search Requirements

### Fuzzy Matching Logic
- **Case-insensitive**: "test title" matches "TEST TITLE"
- **Contains matching**: "Test" matches "Test Title", "Agile Test Title", "Test Title v2"
- **Handles variations**: "Test Title v2", "Agile Test Title", "test title", "TEST TITLE" all match
- **Live suggestions**: Update results as user types each letter
- **Display format**: Show "Service Name | OWNER" for identification

### Search Scope
- **GCloud 14**: Search both LOT 2 and LOT 3 folders
- **Document types**: Service Description and Pricing Document
- **Metadata**: Read from .txt files to get OWNER information

---

## Technical Implementation Approach

### Phase 1: Mock Development
1. Create local folder structure mimicking SharePoint
2. Seed test documents with proper naming
3. Implement mock API service for search and document operations
4. Build frontend flow (login, questionnaire, search, document selection)

### Phase 2: SharePoint Integration
1. Set up Azure AD app registration for Microsoft Graph API
2. Implement authentication flow (OAuth/Microsoft 365 SSO)
3. Integrate Microsoft Graph API for SharePoint operations
4. Replace mock service with real SharePoint API calls

### Phase 3: Document Operations
1. Read existing documents from SharePoint
2. Update documents in SharePoint
3. Create new folders (with auto-create for LOT folders)
4. Create new documents (Word/PDF)
5. Create/update .txt metadata files

### Phase 4: Production Deployment
1. Deploy to AWS infrastructure
2. Configure Azure AD app registration
3. Set up credentials in AWS Secrets Manager
4. Test end-to-end workflow
5. Future: Migrate to Azure if company policy requires

---

## Key Technical Considerations

### Authentication
- **Current**: Email validation (`@paconsulting.com`)
- **Future**: Microsoft 365 SSO integration
- **Storage**: Azure AD app registration credentials in AWS Secrets Manager

### SharePoint Access
- **API**: Microsoft Graph API
- **Operations**: Read, write, create folders, search
- **Permissions**: User context (delegated) or app-only (service principal)

### Fuzzy Search
- **Algorithm**: Case-insensitive contains matching
- **Performance**: Search both LOT folders simultaneously
- **Results**: Display Service Name and OWNER for identification

### Document Operations
- **Read**: Download from SharePoint
- **Update**: Upload modified document
- **Create**: Generate new documents and folders
- **Metadata**: Read/write .txt files

---

## Future Considerations

1. **Azure Migration**: May need to shift to Azure to comply with company policy
2. **SSO Integration**: Full Microsoft 365 SSO for seamless authentication
3. **Version Control**: Track document versions and changes
4. **Audit Logging**: Log all document access and modifications
5. **Permissions**: Role-based access control for different user types

---

## Notes

- All folder and file naming must follow exact format specified
- Metadata .txt file format must be exact (numbered lines)
- Search must handle variations and case-insensitive matching
- Both LOT 2 and LOT 3 folders should be searchable
- Auto-create LOT folders if they don't exist during new proposal creation

