## G-Cloud Proposal Automation Application (Azure Production)

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

### Solution (Azure Production Implementation)
- **Backend**: FastAPI hosted on Azure Functions (Python runtime) within PA's App Service Environment, accessed via Private Endpoint. The service parses uploaded DOCX content, strips enumeration artefacts, validates word counts, and manages SharePoint storage through Microsoft Graph API.
- **Frontend**: React single-page application served via Azure Static Web Apps provides guided forms, real-time validation, and draft workflows. Authenticated via Entra ID SSO App registration for seamless access to both the application and SharePoint Online.
- **PDF Conversion**: Dedicated Azure Function running containerised LibreOffice converts generated Word documents into PDFs while preserving layout and imagery. Deployed to the same App Service Environment for network isolation.
- **Storage**: Azure Storage Account with blob containers (`templates`, `uploads`, `sharepoint`, `output`) separate lifecycle stages. Soft-delete and versioning protect artefacts. Storage account accessed via Private Endpoint from the App Service Environment.
- **Automation**: Session storage + backend parsing ensure numbered bullets never surface in the template boxes; document generation and PDF conversion run asynchronously without manual steps.
- **Authentication & Authorisation**: Entra ID App Registration configured for SSO enables users to authenticate once and access both the G-Cloud application and SharePoint Online seamlessly. Application permissions (`Sites.Selected`, `Files.ReadWrite.All`) granted with admin consent at PA tenant level.
- **Monitoring**: Integrated with PA's existing Log Analytics workspace and Application Insights instance. All function apps stream telemetry, exceptions, and custom metrics to the centralised monitoring infrastructure.
- **Network Security**: App Service Environment configured with Private Endpoint ensures all traffic remains within PA's virtual network. No public internet exposure for backend services. Static Web App uses Azure Front Door (optional) for global distribution with WAF protection.
- **Managed Identities & RBAC**:
  - API Function managed identity: `Storage Blob Data Contributor` on `sharepoint`, `uploads`, `templates` containers; `Key Vault Secrets User` for SharePoint OAuth credentials.
  - PDF Function managed identity: `Storage Blob Data Contributor` scoped to `output` container only; `AcrPull` on Azure Container Registry for image access.
  - Static Web App managed identity: Optional for API Management integration if required.
  - CI/CD service principal: `Website Contributor`, `Storage Blob Data Contributor`, `AcrPush` (time-bound via OIDC workload identity federation).
  - Key Vault access policies limited to `get`/`list` for runtime identities; secrets referenced via App Settings to avoid exposure.

### Unit Tests & Example Results
- `backend/tests/test_document_generation.py` – verifies numbering resets between sections and About PA block retention.
- `backend/tests/azure/test_number_prefix.py` – ensures `strip_number_prefix` removes enumerated bullets, including non-breaking spaces.
- `backend/tests/azure/test_blob_path_resolver.py` – validates blob key naming for generated documents.
- `backend/tests/azure/test_pdf_event.py` – confirms PDF Function contract validation.
- `backend/tests/azure/test_healthcheck.py` – confirms FastAPI `/health` endpoint returns success.
- `backend/tests/azure/test_managed_identity.py` – verifies managed identity authentication for storage and Key Vault access.
- **Recent Run**: `pytest backend/tests/azure -q` → `12 passed in 2.15s` (warnings limited to Pydantic deprecations).

### Azure Architecture Diagram

**Note**: A visual architecture diagram using Azure native icons is available separately. The textual representation below shows the complete architecture flow.
```
Users (Browser / PA Corporate Network)
   │
   ▼
Azure Front Door (Optional - Global CDN + WAF)
   │
   ├──> Azure Static Web Apps (React SPA)
   │        └──> Entra ID SSO App Registration
   │
   ▼
Azure API Management (Optional - Throttling & Inspection)
   │
   ▼
App Service Environment (Private Endpoint)
   │
   ├──> Azure Function (FastAPI service - Python)
   │        ├──> Azure Storage Account (Private Endpoint)
   │        │        ├──> sharepoint container
   │        │        ├──> templates container
   │        │        ├──> uploads container
   │        │        └──> output container
   │        ├──> Azure Key Vault (Private Endpoint)
   │        │        └──> SharePoint OAuth secrets
   │        └──> Microsoft Graph API
   │                 └──> SharePoint Online (via App Registration)
   │
   └──> Azure Function (PDF converter - Container)
             ├──> Azure Container Registry (Private Endpoint)
             └──> Azure Storage Account (output container)

Monitoring & Logging:
   ├──> PA Log Analytics Workspace (Existing)
   └──> PA Application Insights (Existing)
            └──> All Function Apps stream telemetry
```

### Production Deployment Details

#### App Service Environment Configuration
- **Deployment Model**: Isolated tier App Service Environment within PA's virtual network
- **Private Endpoint**: All backend services accessible only via Private Endpoint; no public internet exposure
- **Network Integration**: VNet integration enabled for Function Apps to access storage and Key Vault via Private Endpoints
- **Scaling**: Auto-scaling configured based on CPU and memory metrics; minimum 1 instance for high availability

#### Entra ID SSO App Registration
- **Application ID**: Configured in PA tenant with dual-purpose permissions
- **Authentication**: OAuth 2.0 / OpenID Connect flow for user sign-in
- **API Permissions**:
  - `Sites.Selected` (Application) - SharePoint site access
  - `Files.ReadWrite.All` (Application) - Document read/write operations
  - `User.Read` (Delegated) - User profile access for personalisation
- **Admin Consent**: Granted at tenant level by PA administrators
- **SharePoint Site Scope**: Specific SharePoint sites granted access via `Sites.Selected` permissions
- **Token Lifetime**: Configured per PA security policies (typically 1 hour access tokens, 24 hour refresh tokens)

#### Integration with PA Monitoring Infrastructure
- **Log Analytics Workspace**: Existing PA workspace used for centralised log aggregation
- **Application Insights**: Existing PA Application Insights instance receives telemetry from all Function Apps
- **Custom Metrics**: Document generation counts, PDF conversion success rates, SharePoint API call latencies
- **Alerts**: Configured in Application Insights for:
  - Function errors > 5 in 5 minutes
  - PDF conversion failures
  - SharePoint API authentication failures
  - Storage account access denied errors

#### Storage Account Security
- **Private Endpoint**: Storage account accessible only from App Service Environment via Private Endpoint
- **Network Rules**: Firewall configured to allow traffic only from App Service Environment subnet
- **Blob Container Access**: RBAC assignments at container level using managed identities
- **Soft Delete**: Enabled with 7-day retention for accidental deletion recovery
- **Versioning**: Enabled on all containers to track document changes

#### Key Vault Integration
- **Private Endpoint**: Key Vault accessible only from App Service Environment via Private Endpoint
- **Access Policies**: Managed identity-based access with `get` and `list` permissions only
- **Secret References**: Function App settings use Key Vault references (e.g., `@Microsoft.KeyVault(SecretUri=...)`) to avoid storing secrets in configuration
- **Rotation**: SharePoint client secrets rotated every 6 months; Key Vault expiration alerts notify administrators

### RBAC Assignments (Production)

| Identity | Purpose | Scope | Role Assignments |
|----------|---------|-------|------------------|
| **API Function Managed Identity** | FastAPI runtime accessing storage & Key Vault | Storage account containers, Key Vault | `Storage Blob Data Contributor` (sharepoint, uploads, templates containers), `Key Vault Secrets User` |
| **PDF Function Managed Identity** | PDF conversion runtime with container image | Storage account (output container), ACR | `Storage Blob Data Contributor` (output container only), `AcrPull` on Container Registry |
| **Static Web App Managed Identity** | Optional for API Management integration | API Management (if used) | `API Management Service Contributor` (if required) |
| **CI/CD Service Principal** | GitHub Actions / Azure DevOps deployment | Resource group | `Website Contributor`, `Storage Blob Data Contributor`, `AcrPush` (time-bound via OIDC) |
| **Operations Team** | Manual intervention and break-glass | Resource group | `Function App Contributor`, `Log Analytics Reader` (scoped to specific resources) |
| **Entra ID App Registration** | SharePoint and application access | SharePoint sites, Microsoft Graph | `Sites.Selected` (application permission), `Files.ReadWrite.All` (application permission) |

### Network Architecture
- **App Service Environment**: Deployed in PA's virtual network with Private Endpoint connectivity
- **Storage Account**: Private Endpoint configured; accessible only from App Service Environment subnet
- **Key Vault**: Private Endpoint configured; accessible only from App Service Environment subnet
- **Container Registry**: Private Endpoint configured for secure image pulls
- **Static Web App**: Public endpoint with Azure Front Door (optional) for global distribution and DDoS protection
- **API Management**: Internal mode (optional) with Application Gateway for external exposure if required

### Compliance & Security
- **Zero Trust Principles**: All access authenticated and authorised; least-privilege RBAC assignments
- **Data Residency**: All data stored within UK South region; complies with UK data protection regulations
- **Encryption**: Data encrypted at rest (Azure Storage encryption) and in transit (TLS 1.2+)
- **Audit Logging**: All Key Vault access, storage operations, and function invocations logged to Log Analytics
- **Penetration Testing**: Annual security assessments conducted per PA security policies
- **Backup & Recovery**: Storage account soft-delete and versioning; Function App deployment slots for zero-downtime updates

