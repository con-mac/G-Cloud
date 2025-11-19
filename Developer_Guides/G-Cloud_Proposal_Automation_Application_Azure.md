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
- **Frontend**: React single-page application served via Azure App Service (Linux Web App) deployed within PA's App Service Environment, accessible only via Private Endpoint. Provides guided forms, real-time validation, and draft workflows. Authenticated via Entra ID SSO App registration for seamless access to both the application and SharePoint Online.
- **PDF Conversion**: Dedicated Azure Function running containerised LibreOffice converts generated Word documents into PDFs while preserving layout and imagery. Deployed to the same App Service Environment for network isolation.
- **Storage**: Azure Storage Account with blob containers (`templates`, `uploads`, `sharepoint`, `output`) separate lifecycle stages. Soft-delete and versioning protect artefacts. Storage account accessed via Private Endpoint from the App Service Environment.
- **Automation**: Session storage + backend parsing ensure numbered bullets never surface in the template boxes; document generation and PDF conversion run asynchronously without manual steps.
- **Authentication & Authorisation**: Entra ID App Registration configured for SSO enables users to authenticate once and access both the G-Cloud application and SharePoint Online seamlessly. Application permissions (`Sites.Selected`, `Files.ReadWrite.All`) granted with admin consent at PA tenant level.
- **Monitoring**: Integrated with PA's existing Log Analytics workspace and Application Insights instance. All function apps stream telemetry, exceptions, and custom metrics to the centralised monitoring infrastructure.
- **Network Security**: App Service Environment configured with Private Endpoint ensures all traffic remains within PA's virtual network. **No public internet exposure** - all services (frontend, backend, storage, Key Vault) accessible only via Private Endpoint. Users access the application from PA corporate network via VPN or ExpressRoute/Private Link.
- **Managed Identities & RBAC**:
  - API Function managed identity: `Storage Blob Data Contributor` on `sharepoint`, `uploads`, `templates` containers; `Key Vault Secrets User` for SharePoint OAuth credentials.
  - PDF Function managed identity: `Storage Blob Data Contributor` scoped to `output` container only; `AcrPull` on Azure Container Registry for image access.
  - Frontend App Service managed identity: `Storage Blob Data Contributor` (if direct storage access required), otherwise uses API Function for all backend operations.
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
Users (PA Corporate Network)
   │
   ▼
VPN / ExpressRoute / Private Link
   │
   ▼
App Service Environment (Private Endpoint - No Public Access)
   │
   ├──> Azure App Service (Linux Web App - React SPA)
   │        ├──> Entra ID SSO App Registration
   │        └──> Azure Function (FastAPI service - Python)
   │                 ├──> Azure Storage Account (Private Endpoint)
   │                 │        ├──> sharepoint container
   │                 │        ├──> templates container
   │                 │        ├──> uploads container
   │                 │        └──> output container
   │                 ├──> Azure Key Vault (Private Endpoint)
   │                 │        └──> SharePoint OAuth secrets
   │                 └──> Microsoft Graph API
   │                          └──> SharePoint Online (via App Registration)
   │
   └──> Azure Function (PDF converter - Container)
             ├──> Azure Container Registry (Private Endpoint)
             └──> Azure Storage Account (output container)

Monitoring & Logging:
   ├──> PA Log Analytics Workspace (Existing)
   └──> PA Application Insights (Existing)
            └──> All services stream telemetry
```

### Production Deployment Details

#### App Service Environment Configuration
- **Deployment Model**: Isolated tier App Service Environment within PA's virtual network
- **Private Endpoint**: **All services (frontend, backend, storage, Key Vault) accessible only via Private Endpoint; zero public internet exposure**
- **Network Integration**: VNet integration enabled for all App Services and Function Apps to access storage and Key Vault via Private Endpoints
- **User Access**: Users connect from PA corporate network via VPN, ExpressRoute, or Private Link - no internet-facing endpoints
- **Scaling**: Auto-scaling configured based on CPU and memory metrics; minimum 1 instance for high availability
- **Frontend Deployment**: React SPA served via Azure App Service (Linux Web App) within ASE, not Static Web App (which requires public endpoint)

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
| **Frontend App Service Managed Identity** | React SPA runtime (if direct storage access needed) | Storage account (if required) | `Storage Blob Data Contributor` (optional - frontend typically calls API Function only) |
| **CI/CD Service Principal** | GitHub Actions / Azure DevOps deployment | Resource group | `Website Contributor`, `Storage Blob Data Contributor`, `AcrPush` (time-bound via OIDC) |
| **Operations Team** | Manual intervention and break-glass | Resource group | `Function App Contributor`, `Log Analytics Reader` (scoped to specific resources) |
| **Entra ID App Registration** | SharePoint and application access | SharePoint sites, Microsoft Graph | `Sites.Selected` (application permission), `Files.ReadWrite.All` (application permission) |

### Network Architecture (Fully Private - No Public Endpoints)
- **App Service Environment**: Deployed in PA's virtual network with Private Endpoint connectivity; **no public VIP**
- **Frontend App Service**: Linux Web App deployed in ASE, accessible only via Private Endpoint from PA corporate network
- **Storage Account**: Private Endpoint configured; accessible only from App Service Environment subnet; public network access disabled
- **Key Vault**: Private Endpoint configured; accessible only from App Service Environment subnet; public network access disabled
- **Container Registry**: Private Endpoint configured for secure image pulls; public network access disabled
- **User Access Path**: PA Corporate Network → VPN/ExpressRoute/Private Link → App Service Environment (Private Endpoint) → Application
- **No Public Services**: Azure Front Door, Static Web App, and public API Management endpoints removed to eliminate all public internet exposure

### Private Endpoint Architecture Benefits

**Why This Approach is Simpler and More Secure:**

1. **No Public Endpoints Required**: By deploying the frontend as an App Service (Linux Web App) within the App Service Environment instead of Static Web App, we eliminate the need for any public-facing services.

2. **Simplified Architecture**: Removing Azure Front Door and Static Web App actually simplifies the design:
   - Fewer services to manage and secure
   - No CDN/WAF configuration needed
   - No public DNS or SSL certificate management for frontend
   - All services use the same Private Endpoint pattern

3. **Consistent Security Model**: All services (frontend, backend, storage, Key Vault) follow the same Private Endpoint security model, making it easier to audit and maintain.

4. **No Heavy Lifting Required**: The change from Static Web App to App Service is straightforward:
   - React SPA builds the same way (npm build)
   - Deploy to App Service instead of Static Web App
   - Same authentication flow (Entra ID SSO)
   - Same API integration pattern

5. **User Access**: Users access via existing PA corporate network infrastructure (VPN/ExpressRoute), which they already use for other internal applications.

### Compliance & Security
- **Zero Trust Principles**: All access authenticated and authorised; least-privilege RBAC assignments
- **No Public Internet Exposure**: All services accessible only via Private Endpoint from PA corporate network; zero public endpoints
- **Network Isolation**: App Service Environment, Storage Account, Key Vault, and Container Registry all configured with Private Endpoints and public network access disabled
- **Data Residency**: All data stored within UK South region; complies with UK data protection regulations
- **Encryption**: Data encrypted at rest (Azure Storage encryption) and in transit (TLS 1.2+)
- **Audit Logging**: All Key Vault access, storage operations, and function invocations logged to Log Analytics
- **Penetration Testing**: Annual security assessments conducted per PA security policies
- **Backup & Recovery**: Storage account soft-delete and versioning; App Service deployment slots for zero-downtime updates

