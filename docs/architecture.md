# G-Cloud Automation System - Architecture Document

**Version:** 1.0.0  
**Last Updated:** 28 October 2025  

---

## 1. System Overview

The G-Cloud Automation System is a modern web application designed to streamline the creation, validation, and management of G-Cloud framework proposals. The system follows a three-tier architecture pattern with clear separation of concerns.

```
┌────────────────────────────────────────────────────────────────┐
│                         User Layer                              │
│  (Web Browsers, Mobile Devices via Responsive UI)             │
└─────────────────────┬──────────────────────────────────────────┘
                      │
                      │ HTTPS / Azure AD Auth
                      ▼
┌────────────────────────────────────────────────────────────────┐
│                    Presentation Layer                           │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │  React 18 + TypeScript Frontend                          │ │
│  │  - Material-UI Components                                │ │
│  │  - State Management (Zustand)                            │ │
│  │  - Rich Text Editor (Draft.js)                           │ │
│  │  - Azure AD Integration (MSAL)                           │ │
│  └──────────────────────────────────────────────────────────┘ │
└─────────────────────┬──────────────────────────────────────────┘
                      │
                      │ REST API / JSON
                      ▼
┌────────────────────────────────────────────────────────────────┐
│                    Application Layer                            │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │  FastAPI Backend                                         │ │
│  │  - REST API Endpoints                                    │ │
│  │  - Validation Engine                                     │ │
│  │  - Business Logic Services                               │ │
│  │  - Authentication & Authorisation                        │ │
│  │  - Document Processing                                   │ │
│  └──────────────────────────────────────────────────────────┘ │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │  Background Workers (Celery)                             │ │
│  │  - Scheduled Notifications                               │ │
│  │  - Document Import/Export                                │ │
│  │  - Batch Validation                                      │ │
│  └──────────────────────────────────────────────────────────┘ │
└─────────────────────┬──────────────────────────────────────────┘
                      │
                      │ SQL / Redis / Blob Storage
                      ▼
┌────────────────────────────────────────────────────────────────┐
│                       Data Layer                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │
│  │  PostgreSQL  │  │  Redis Cache │  │ Azure Blob   │        │
│  │  Database    │  │  (Sessions,  │  │  Storage     │        │
│  │              │  │   Cache)     │  │  (Documents) │        │
│  └──────────────┘  └──────────────┘  └──────────────┘        │
└────────────────────────────────────────────────────────────────┘
```

---

## 2. Technology Stack

### 2.1 Frontend

| Technology | Version | Purpose |
|-----------|---------|---------|
| React | 18.2+ | UI framework |
| TypeScript | 5.3+ | Type safety |
| Vite | 5.0+ | Build tool |
| Material-UI | 5.14+ | UI component library |
| Zustand | 4.4+ | State management |
| React Query | 5.12+ | Server state management |
| Draft.js | 0.11+ | Rich text editing |
| MSAL | 3.5+ | Azure AD authentication |
| Axios | 1.6+ | HTTP client |

### 2.2 Backend

| Technology | Version | Purpose |
|-----------|---------|---------|
| Python | 3.11+ | Programming language |
| FastAPI | 0.104+ | API framework |
| SQLAlchemy | 2.0+ | ORM |
| Alembic | 1.12+ | Database migrations |
| Pydantic | 2.5+ | Data validation |
| Celery | 5.3+ | Task queue |
| python-docx | 1.1+ | Document processing |

### 2.3 Infrastructure

| Technology | Purpose |
|-----------|---------|
| Azure App Service | Application hosting |
| Azure PostgreSQL | Relational database |
| Azure Redis Cache | Caching & sessions |
| Azure Blob Storage | Document storage |
| Azure Key Vault | Secrets management |
| Azure AD | Authentication |
| Microsoft Graph API | SharePoint integration |
| Application Insights | Monitoring |
| Terraform | Infrastructure as Code |

---

## 3. Component Architecture

### 3.1 Frontend Components

```
src/
├── components/         # Reusable UI components
│   ├── common/        # Common components (buttons, inputs)
│   ├── layout/        # Layout components (nav, sidebar)
│   ├── proposal/      # Proposal-specific components
│   ├── section/       # Section editing components
│   └── validation/    # Validation display components
│
├── pages/             # Page-level components
│   ├── Dashboard/     # Dashboard page
│   ├── Proposals/     # Proposals list
│   ├── ProposalEdit/  # Proposal editor
│   └── Settings/      # Settings page
│
├── hooks/             # Custom React hooks
│   ├── useAuth.ts     # Authentication hook
│   ├── useValidation.ts # Validation hook
│   └── useProposal.ts # Proposal data hook
│
├── services/          # API services
│   ├── api.ts         # Base API client
│   ├── proposals.ts   # Proposal API
│   ├── sections.ts    # Sections API
│   └── auth.ts        # Auth API
│
└── store/             # State management
    ├── authStore.ts   # Auth state
    ├── proposalStore.ts # Proposal state
    └── uiStore.ts     # UI state
```

### 3.2 Backend Components

```
app/
├── api/               # API endpoints
│   ├── routes/
│   │   ├── auth.py    # Authentication endpoints
│   │   ├── proposals.py # Proposal CRUD
│   │   ├── sections.py # Section CRUD
│   │   ├── validation.py # Validation endpoints
│   │   └── users.py   # User management
│   └── deps.py        # Dependencies injection
│
├── core/              # Core functionality
│   ├── config.py      # Configuration
│   ├── security.py    # Security utilities
│   ├── logging.py     # Logging setup
│   └── exceptions.py  # Custom exceptions
│
├── models/            # Database models
│   ├── user.py
│   ├── proposal.py
│   ├── section.py
│   ├── validation_rule.py
│   ├── change_history.py
│   └── notification.py
│
├── schemas/           # Pydantic schemas
│   ├── user.py
│   ├── proposal.py
│   └── section.py
│
├── services/          # Business logic
│   ├── proposal_service.py
│   ├── validation_service.py
│   ├── notification_service.py
│   ├── document_service.py
│   └── sharepoint_service.py
│
└── utils/             # Utilities
    ├── validation.py  # Validation helpers
    ├── word_counter.py # Word counting
    └── document_parser.py # Document parsing
```

---

## 4. Data Flow

### 4.1 Proposal Creation Flow

```
User → Frontend → API → Validation → Database → Response
  1. User creates new proposal via UI
  2. Frontend sends POST /api/v1/proposals
  3. Backend validates request data
  4. Creates proposal and default sections
  5. Returns proposal with sections
  6. Frontend updates state and redirects to editor
```

### 4.2 Section Validation Flow

```
User Types → Debounced Event → API Call → Validation Engine → UI Update
  1. User types in section editor
  2. After 500ms delay, trigger validation
  3. Send content to POST /api/v1/validation/section
  4. Validation engine runs all rules
  5. Returns validation results
  6. UI updates with errors/warnings/success
```

### 4.3 Notification Flow

```
Celery Beat → Check Deadlines → Create Notifications → Send Emails
  1. Scheduled task runs daily at 09:00
  2. Queries proposals with upcoming deadlines
  3. Creates notification records
  4. Sends emails via SendGrid
  5. Updates notification status
```

---

## 5. Authentication & Authorisation

### 5.1 Authentication Flow

```
1. User clicks "Sign In"
2. Frontend redirects to Azure AD
3. User authenticates with Microsoft account
4. Azure AD returns tokens to frontend
5. Frontend stores access token
6. Frontend includes token in API requests
7. Backend validates token with Azure AD
8. Backend checks user role and permissions
```

### 5.2 Role-Based Access Control

| Role | Permissions |
|------|-------------|
| **Viewer** | Read proposals and sections |
| **Editor** | Create and edit proposals, edit sections |
| **Reviewer** | All Editor permissions + approve proposals |
| **Admin** | All permissions + manage users and settings |

---

## 6. Database Schema

### 6.1 Core Tables

```sql
-- Users table
users (
  id UUID PRIMARY KEY,
  azure_ad_id VARCHAR(255) UNIQUE,
  email VARCHAR(255) UNIQUE,
  full_name VARCHAR(255),
  role ENUM('viewer', 'editor', 'reviewer', 'admin'),
  is_active BOOLEAN,
  last_login TIMESTAMP,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
)

-- Proposals table
proposals (
  id UUID PRIMARY KEY,
  title VARCHAR(500),
  framework_version VARCHAR(50),
  status ENUM(...),
  deadline TIMESTAMP,
  completion_percentage FLOAT,
  created_by UUID REFERENCES users(id),
  last_modified_by UUID REFERENCES users(id),
  original_document_url VARCHAR(1000),
  created_at TIMESTAMP,
  updated_at TIMESTAMP
)

-- Sections table
sections (
  id UUID PRIMARY KEY,
  proposal_id UUID REFERENCES proposals(id),
  section_type ENUM(...),
  title VARCHAR(500),
  order INTEGER,
  content TEXT,
  word_count INTEGER,
  validation_status ENUM(...),
  validation_errors TEXT,
  is_mandatory BOOLEAN,
  last_modified_by UUID REFERENCES users(id),
  locked_by UUID REFERENCES users(id),
  locked_at TIMESTAMP,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
)
```

### 6.2 Relationships

- One User → Many Proposals (created_by)
- One Proposal → Many Sections
- One Section → Many ChangeHistory records
- One User → Many Notifications

---

## 7. API Design

### 7.1 RESTful Endpoints

```
Authentication:
  POST   /api/v1/auth/login
  POST   /api/v1/auth/logout
  GET    /api/v1/auth/me

Proposals:
  GET    /api/v1/proposals
  POST   /api/v1/proposals
  GET    /api/v1/proposals/{id}
  PUT    /api/v1/proposals/{id}
  DELETE /api/v1/proposals/{id}
  GET    /api/v1/proposals/{id}/sections

Sections:
  GET    /api/v1/sections/{id}
  PUT    /api/v1/sections/{id}
  POST   /api/v1/sections/{id}/lock
  DELETE /api/v1/sections/{id}/lock

Validation:
  POST   /api/v1/validation/section
  POST   /api/v1/validation/proposal

Documents:
  POST   /api/v1/documents/import
  GET    /api/v1/documents/{id}/export
```

### 7.2 Response Format

```json
{
  "data": { ... },
  "meta": {
    "timestamp": "2025-10-28T10:00:00Z",
    "request_id": "uuid"
  }
}
```

---

## 8. Security Architecture

### 8.1 Security Layers

1. **Network Layer**
   - HTTPS only
   - Azure Front Door with WAF
   - DDoS protection

2. **Application Layer**
   - Azure AD authentication
   - JWT token validation
   - Role-based access control
   - Input validation
   - Output encoding

3. **Data Layer**
   - Encryption at rest
   - Encrypted database connections
   - Key Vault for secrets
   - Audit logging

### 8.2 Security Best Practices

- ✅ Principle of least privilege
- ✅ Defence in depth
- ✅ Secure by default
- ✅ Regular security updates
- ✅ Vulnerability scanning
- ✅ Penetration testing

---

## 9. Scalability Considerations

### 9.1 Horizontal Scaling

- App Services can scale out to multiple instances
- Stateless API design enables load balancing
- Redis for distributed caching and sessions
- Background workers can scale independently

### 9.2 Performance Optimisation

- Database query optimisation with indexes
- Redis caching for frequently accessed data
- CDN for static assets
- Lazy loading in frontend
- Database connection pooling
- Asynchronous I/O in backend

---

## 10. Monitoring & Observability

### 10.1 Metrics

- Application Insights for telemetry
- Custom metrics for business KPIs
- Performance counters
- Error rates
- User activity

### 10.2 Logging

- Structured logging (JSON format)
- Correlation IDs for request tracing
- Log Analytics for centralised logs
- Alert rules for critical errors

### 10.3 Health Checks

- Application health endpoint
- Database connectivity check
- Redis connectivity check
- External service checks

---

## 11. Deployment Architecture

### 11.1 CI/CD Pipeline

```
GitHub → GitHub Actions → Build → Test → Deploy to Azure
  1. Code pushed to GitHub
  2. GitHub Actions triggered
  3. Run linters and tests
  4. Build Docker images
  5. Push to Azure Container Registry
  6. Deploy to App Service
  7. Run smoke tests
```

### 11.2 Environments

| Environment | Purpose | URL Pattern |
|-------------|---------|-------------|
| Development | Active development | dev-*.azurewebsites.net |
| Staging | Pre-production testing | staging-*.azurewebsites.net |
| Production | Live system | *.azurewebsites.net |

---

## 12. Disaster Recovery

### 12.1 Backup Strategy

- **Database**: Daily automated backups, 7-day retention
- **Documents**: Blob storage with versioning enabled
- **Configuration**: Infrastructure as Code in Git

### 12.2 Recovery Procedures

- Database point-in-time restore
- Blob storage soft delete (7 days)
- Infrastructure recreation via Terraform

---

## 13. Future Enhancements

### 13.1 Phase 6+ Features

- Real-time collaborative editing
- AI-powered content suggestions
- Advanced analytics and reporting
- Mobile native applications
- Multi-language support
- Integration with additional frameworks beyond G-Cloud

---

**End of Architecture Document**

